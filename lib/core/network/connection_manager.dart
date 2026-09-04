import 'dart:async';

import 'package:flutter/foundation.dart';

import '../crypto/handshake.dart';
import '../crypto/key_manager.dart';
import '../crypto/secure_channel.dart';
import '../crypto/session_manager.dart';
import '../storage/trust_store.dart';
import 'message_protocol.dart';
import 'p2p_client.dart';
import 'p2p_server.dart';

/// Emitted when a pairwise session is (re)established over a direct link.
class SessionEvent {
  final String peerId;
  final bool isNew;
  final bool isInitiator;
  final PeerConnection connection;
  SessionEvent(this.peerId, this.isNew, this.isInitiator, this.connection);
}

/// Runs the v3 handshake on every direct link, enforces key pinning,
/// installs link encryption and registers authenticated connections.
///
/// Nothing above this layer ever sees an unauthenticated peer.
class ConnectionManager extends ChangeNotifier {
  final KeyManager keys;
  final P2PClient client;
  final P2PServer server;
  final TrustStore trust;
  final SessionManager sessions;

  String _myId = '';
  String _displayName = '';
  int _listeningPort = 0;
  List<String> _capabilities = const [];
  StreamSubscription<PeerConnection>? _serverSub;

  final StreamController<PeerConnection> _peerReady =
      StreamController.broadcast();
  final StreamController<TrustCheck> _keyChange = StreamController.broadcast();
  final StreamController<SessionEvent> _sessionEvents =
      StreamController.broadcast();

  /// Peers whose presented keys differ from the pinned ones. The user must
  /// accept the change before a link is allowed.
  final Map<String, PinnedPeer> _pendingKeyChanges = {};

  /// Initiator nonces seen recently: a replayed hello is refused instead
  /// of being answered with fresh keys.
  final List<String> _recentInitiatorNonces = [];
  static const int _nonceCacheSize = 2048;

  ConnectionManager({
    required this.keys,
    required this.client,
    required this.server,
    required this.trust,
    required this.sessions,
  });

  Stream<PeerConnection> get onPeerReady => _peerReady.stream;
  Stream<TrustCheck> get onKeyChange => _keyChange.stream;
  Stream<SessionEvent> get onSessionEstablished => _sessionEvents.stream;
  Map<String, PinnedPeer> get pendingKeyChanges =>
      Map.unmodifiable(_pendingKeyChanges);
  String get myId => _myId;

  void configure({
    required String nyxChatId,
    required String displayName,
    required int listeningPort,
    List<String> capabilities = const ['mesh', 'files'],
  }) {
    _myId = nyxChatId;
    _displayName = displayName;
    _listeningPort = listeningPort;
    _capabilities = capabilities;
  }

  void start() {
    _serverSub?.cancel();
    _serverSub = server.onNewConnection.listen(_handleIncoming);
  }

  Future<void> stop() async {
    await _serverSub?.cancel();
    _serverSub = null;
  }

  /// Dial a peer and complete the handshake. Returns null on any failure
  /// (including a refused key change).
  Future<PeerConnection?> connect(String address, int port) async {
    PeerConnection? conn;
    try {
      conn = await client.open(address: address, port: port);
      final state = await Handshake.createInitiatorHello(
        keys: keys,
        nyxChatId: _myId,
        displayName: _displayName,
        listeningPort: _listeningPort,
        capabilities: _capabilities,
      );
      final responseFuture = conn.nextOfType(ProtocolMessageType.hello);
      await conn.send(ProtocolMessage.hello(state.hello));
      final response = (await responseFuture).asHello();
      final result = await Handshake.completeInitiator(
          keys: keys, state: state, response: response);
      return await _finish(conn, result);
    } catch (e) {
      debugPrint('[Conn] outbound handshake with $address:$port failed: $e');
      await conn?.disconnect();
      return null;
    }
  }

  Future<void> _handleIncoming(PeerConnection conn) async {
    try {
      final hello = (await conn.nextOfType(ProtocolMessageType.hello)).asHello();
      final nonceHex = hello.nonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (_recentInitiatorNonces.contains(nonceHex)) {
        debugPrint('[Conn] replayed hello from ${conn.remoteAddress}, refused');
        await conn.disconnect();
        return;
      }
      _recentInitiatorNonces.add(nonceHex);
      if (_recentInitiatorNonces.length > _nonceCacheSize) {
        _recentInitiatorNonces.removeAt(0);
      }
      final (response, result) = await Handshake.respond(
        keys: keys,
        nyxChatId: _myId,
        displayName: _displayName,
        listeningPort: _listeningPort,
        initiatorHello: hello,
        capabilities: _capabilities,
      );
      // Key pinning is checked before we reveal anything more.
      final check = await _checkTrust(result);
      if (check.isKeyChange) {
        await conn.disconnect();
        return;
      }
      await conn.send(ProtocolMessage.hello(response));
      await _finish(conn, result, trustCheck: check);
    } catch (e) {
      debugPrint('[Conn] inbound handshake from ${conn.remoteAddress} failed: $e');
      await conn.disconnect();
    }
  }

  Future<TrustCheck> _checkTrust(HandshakeResult result) async {
    final check = await trust.check(
      nyxChatId: result.peerId,
      displayName: result.peerDisplayName,
      identityKey: result.peerIdentityKey,
      signingKey: result.peerSigningKey,
      kyberPublicKey: result.peerKyberPublicKey,
    );
    if (check.isKeyChange) {
      debugPrint('[Conn] KEY CHANGE for ${result.peerId}: refusing link');
      _pendingKeyChanges[result.peerId] = check.peer;
      _keyChange.add(check);
      notifyListeners();
    }
    return check;
  }

  Future<PeerConnection?> _finish(PeerConnection conn, HandshakeResult result,
      {TrustCheck? trustCheck}) async {
    final check = trustCheck ?? await _checkTrust(result);
    if (check.isKeyChange) {
      await conn.disconnect();
      return null;
    }
    conn.peerId = result.peerId;
    conn.handshake = result;
    conn.installChannel(await SecureChannel.fromMasterSecret(
      masterSecret: result.masterSecret,
      isInitiator: result.isInitiator,
    ));
    if (!client.register(conn, myId: _myId)) return null;
    final isNew = await sessions.establishFromHandshake(result);
    _peerReady.add(conn);
    _sessionEvents.add(SessionEvent(result.peerId, isNew, result.isInitiator, conn));
    notifyListeners();
    debugPrint('[Conn] ${result.isInitiator ? 'outbound' : 'inbound'} link with '
        '${result.peerId} secured (session ${isNew ? 'new' : 'existing'})');
    return conn;
  }

  /// Re-derive the pairwise session from this link's handshake (session
  /// reset flow). The link initiator becomes the ratchet initiator.
  Future<bool> resetSession(PeerConnection conn) async {
    final result = conn.handshake;
    final peerId = conn.peerId;
    if (result == null || peerId == null) return false;
    await sessions.establishFromHandshake(result, force: true);
    _sessionEvents.add(SessionEvent(peerId, true, result.isInitiator, conn));
    return true;
  }

  /// The user compared safety numbers and accepted the new keys.
  Future<void> acceptKeyChange(String peerId) async {
    final pending = _pendingKeyChanges.remove(peerId);
    if (pending == null) return;
    await trust.acceptNewKeys(pending);
    await sessions.reset(peerId);
    notifyListeners();
  }

  void rejectKeyChange(String peerId) {
    _pendingKeyChanges.remove(peerId);
    notifyListeners();
  }

  @override
  void dispose() {
    _serverSub?.cancel();
    _peerReady.close();
    _keyChange.close();
    _sessionEvents.close();
    super.dispose();
  }
}