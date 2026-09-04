import 'dart:async';

import 'package:flutter/foundation.dart';

import '../crypto/key_manager.dart';
import '../crypto/prekey_bundle.dart';
import '../crypto/prekey_store.dart';
import '../storage/trust_store.dart';
import 'connection_manager.dart';
import 'message_protocol.dart';
import 'p2p_client.dart';
import 'p2p_server.dart';

/// Distributes one-time ML-KEM-768 prekeys over authenticated direct links.
///
/// After every handshake the link initiator sends its current pool for the
/// peer as a signed [PrekeyBundle] (frame type `prekeys`, inside the link
/// encryption). The responder verifies it against the pinned signing key,
/// replaces what it held from that peer and answers with its own bundle.
/// Sending the whole pool on every handshake keeps both sides at
/// [PrekeyStore.poolSize] without any "running low" signalling and heals a
/// peer that lost its store at the next meeting.
///
/// The frame listener is attached as soon as the link is registered, before
/// the pairwise session is derived, so a bundle cannot arrive with nobody
/// listening; the responder only speaks after it has heard the initiator.
class PrekeyExchange {
  final KeyManager keys;
  final TrustStore trust;
  final PrekeyStore prekeys;
  final ConnectionManager connections;
  final P2PClient client;

  String _myId = '';
  StreamSubscription<String>? _upSub;
  StreamSubscription<PeerConnection>? _readySub;
  final StreamController<String> _received = StreamController.broadcast();

  PrekeyExchange({
    required this.keys,
    required this.trust,
    required this.prekeys,
    required this.connections,
    required this.client,
  });

  /// Peer ids whose bundle was just accepted (diagnostics and tests).
  Stream<String> get onBundleReceived => _received.stream;

  void start({required String myId}) {
    _myId = myId;
    _upSub?.cancel();
    _readySub?.cancel();
    _upSub = client.onPeerConnected.listen((peerId) {
      final conn = client.getConnection(peerId);
      if (conn != null) _listen(conn);
    });
    _readySub = connections.onPeerReady.listen((conn) {
      if (!conn.isIncoming) unawaited(sendBundle(conn));
    });
  }

  void _listen(PeerConnection conn) {
    late final StreamSubscription<ProtocolMessage> sub;
    sub = conn.onMessage.listen((m) {
      if (m.type == ProtocolMessageType.prekeys) {
        unawaited(_onBundle(conn, m.payload));
      }
    }, onDone: () => sub.cancel());
  }

  /// Top the pool for the link peer up to [PrekeyStore.poolSize] and send
  /// the whole live pool, signed, over the link.
  Future<void> sendBundle(PeerConnection conn) async {
    final peerId = conn.peerId;
    if (peerId == null || !conn.isConnected) return;
    try {
      await prekeys.expire();
      await prekeys.replenish(peerId);
      final pool = prekeys
          .outstanding(peerId)
          .map((k) => PublicPrekey(id: k.id, publicKey: k.publicKey))
          .toList();
      final bundle = await PrekeyBundle.create(
          keys: keys, from: _myId, to: peerId, prekeys: pool);
      await conn.send(ProtocolMessage.prekeys(bundle.toJson()));
      debugPrint('[Prekeys] sent ${pool.length} one-time prekeys to $peerId');
    } catch (e) {
      debugPrint('[Prekeys] could not send bundle to $peerId: $e');
    }
  }

  Future<void> _onBundle(
      PeerConnection conn, Map<String, dynamic> payload) async {
    final peerId = conn.peerId;
    if (peerId == null) return;
    final pinned = trust.get(peerId);
    if (pinned == null) return;
    try {
      final bundle = PrekeyBundle.fromJson(payload);
      final problem = await bundle.validate(
        pinnedSigningKey: pinned.signingKey,
        myId: _myId,
        fromId: peerId,
        lastIssuedAtMs: prekeys.lastBundleIssuedAt(peerId),
      );
      if (problem != null) {
        debugPrint('[Prekeys] bundle from $peerId rejected: $problem');
        return;
      }
      final now = DateTime.now().toUtc();
      await prekeys.replacePeerBundle(
        peerId,
        keys: [
          for (final k in bundle.keys)
            PeerPrekey(id: k.id, publicKey: k.publicKey, receivedAt: now)
        ],
        issuedAtMs: bundle.issuedAtMs,
      );
      debugPrint('[Prekeys] holding ${prekeys.peerPrekeyCount(peerId)} '
          'one-time prekeys from $peerId');
      if (!_received.isClosed) _received.add(peerId);
      if (conn.isIncoming) await sendBundle(conn);
    } on FormatException catch (e) {
      debugPrint('[Prekeys] malformed bundle from $peerId: $e');
    }
  }

  void dispose() {
    _upSub?.cancel();
    _readySub?.cancel();
    _received.close();
  }
}