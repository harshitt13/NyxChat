import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'message_protocol.dart';
import 'p2p_server.dart';

/// Registry of authenticated direct links, keyed by peer id.
class P2PClient {
  final Map<String, PeerConnection> _connections = {};
  final StreamController<String> _peerUp = StreamController.broadcast();
  final StreamController<String> _peerDown = StreamController.broadcast();

  Map<String, PeerConnection> get connections => Map.unmodifiable(_connections);
  Stream<String> get onPeerConnected => _peerUp.stream;
  Stream<String> get onPeerDisconnected => _peerDown.stream;

  /// Open a raw TCP link. The caller performs the handshake.
  Future<PeerConnection> open({
    required String address,
    required int port,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final socket = await Socket.connect(address, port, timeout: timeout);
    return PeerConnection(socket: socket, isIncoming: false);
  }

  /// Register an authenticated link. If another link to the same peer
  /// exists, the deterministic rule "the link initiated by the smaller id
  /// survives" decides which one is kept, so both sides agree.
  bool register(PeerConnection connection, {required String myId}) {
    final peerId = connection.peerId;
    if (peerId == null) return false;
    final existing = _connections[peerId];
    if (existing != null && existing.isConnected && existing != connection) {
      final keepNew = _shouldPrefer(connection, existing, myId, peerId);
      if (!keepNew) {
        debugPrint('[P2P] duplicate link to $peerId, dropping newer');
        unawaited(connection.disconnect());
        return false;
      }
      debugPrint('[P2P] duplicate link to $peerId, replacing older');
      unawaited(existing.disconnect());
    }
    _connections[peerId] = connection;
    _peerUp.add(peerId);
    unawaited(connection.onDisconnect.then((_) {
      if (_connections[peerId] == connection) {
        _connections.remove(peerId);
        _peerDown.add(peerId);
      }
    }));
    return true;
  }

  /// Prefer the link whose initiator has the smaller id.
  static bool _shouldPrefer(
      PeerConnection candidate, PeerConnection existing, String myId, String peerId) {
    final iAmSmaller = myId.compareTo(peerId) < 0;
    bool initiatedBySmaller(PeerConnection c) =>
        c.isIncoming ? !iAmSmaller : iAmSmaller;
    final candidateWins = initiatedBySmaller(candidate);
    final existingWins = initiatedBySmaller(existing);
    if (candidateWins && !existingWins) return true;
    if (!candidateWins && existingWins) return false;
    return false; // tie (should not happen): keep existing
  }

  Future<void> sendToPeer(String peerId, ProtocolMessage message) async {
    final c = _connections[peerId];
    if (c == null || !c.isConnected) return;
    await c.send(message);
  }

  bool isPeerConnected(String peerId) =>
      _connections[peerId]?.isConnected ?? false;

  PeerConnection? getConnection(String peerId) => _connections[peerId];

  List<String> get connectedPeerIds => _connections.entries
      .where((e) => e.value.isConnected)
      .map((e) => e.key)
      .toList();

  Future<void> disconnectPeer(String peerId) async {
    final c = _connections.remove(peerId);
    await c?.disconnect();
  }

  Future<void> disconnectAll() async {
    for (final c in _connections.values.toList()) {
      await c.disconnect();
    }
    _connections.clear();
  }
}