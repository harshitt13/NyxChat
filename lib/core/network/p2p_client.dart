import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'message_protocol.dart';
import 'p2p_server.dart';

/// TCP client that connects to discovered peers.
class P2PClient {
  final Map<String, PeerConnection> _connections = {};

  /// Get all active connections
  Map<String, PeerConnection> get connections =>
      Map.unmodifiable(_connections);

  /// Connect to a peer at the given address and port
  Future<PeerConnection> connectToPeer({
    required String address,
    required int port,
    required ProtocolMessage helloMessage,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final socket = await Socket.connect(
        address,
        port,
        timeout: timeout,
      );

      debugPrint('Connected to peer at $address:$port');

      final connection = PeerConnection(
        socket: socket,
        isIncoming: false,
      );

      // Send hello message
      connection.send(helloMessage);

      // Wait for their hello response
      final completer = Completer<PeerConnection>();
      late StreamSubscription sub;

      sub = connection.onMessage.listen((msg) {
        if (msg.type == ProtocolMessageType.hello) {
          connection.peerId = msg.senderId;
          connection.peerDisplayName =
              msg.payload['displayName'] as String?;
          connection.peerPublicKeyHex =
              msg.payload['publicKeyHex'] as String?;

          _connections[msg.senderId] = connection;

          if (!completer.isCompleted) {
            completer.complete(connection);
          }
          sub.cancel();
        }
      });

      // Also handle disconnect before hello
      connection.onDisconnect.then((_) {
        if (!completer.isCompleted) {
          completer.completeError('Peer disconnected before handshake');
        }
        _connections.remove(connection.peerId);
      });

      return await completer.future.timeout(timeout, onTimeout: () {
        connection.disconnect();
        throw TimeoutException('Handshake timeout');
      });
    } catch (e) {
      debugPrint('Failed to connect to $address:$port: $e');
      rethrow;
    }
  }

  /// Register an incoming connection (from P2PServer)
  void registerIncomingConnection(PeerConnection connection) {
    if (connection.peerId != null) {
      _connections[connection.peerId!] = connection;
    }

    connection.onDisconnect.then((_) {
      _connections.remove(connection.peerId);
    });
  }

  /// Send a message to a specific peer
  void sendToPeer(String peerId, ProtocolMessage message) {
    final connection = _connections[peerId];
    if (connection != null && connection.isConnected) {
      connection.send(message);
    } else {
      debugPrint('Peer $peerId not connected');
    }
  }

  /// Check if a peer is connected
  bool isPeerConnected(String peerId) {
    final connection = _connections[peerId];
    return connection != null && connection.isConnected;
  }

  /// Get a specific peer connection
  PeerConnection? getConnection(String peerId) => _connections[peerId];

  /// Disconnect from a specific peer
  Future<void> disconnectPeer(String peerId) async {
    final connection = _connections.remove(peerId);
    await connection?.disconnect();
  }

  /// Disconnect from all peers
  Future<void> disconnectAll() async {
    for (final connection in _connections.values) {
      await connection.disconnect();
    }
    _connections.clear();
  }
}
