import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'message_protocol.dart';

/// TCP server that listens for incoming P2P connections.
class P2PServer {
  ServerSocket? _serverSocket;
  final int port;
  final String nyxChatId;

  final StreamController<PeerConnection> _connectionController =
      StreamController<PeerConnection>.broadcast();
  final List<PeerConnection> _activeConnections = [];

  Stream<PeerConnection> get onNewConnection => _connectionController.stream;
  List<PeerConnection> get activeConnections =>
      List.unmodifiable(_activeConnections);

  P2PServer({required this.port, required this.nyxChatId});

  /// Start listening for incoming connections
  Future<void> start() async {
    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      debugPrint('NyxChat P2P Server listening on port $port');

      _serverSocket!.listen(
        _handleIncomingConnection,
        onError: (error) {
          debugPrint('Server error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to start P2P server: $e');
      rethrow;
    }
  }

  void _handleIncomingConnection(Socket socket) {
    debugPrint(
      'Incoming connection from ${socket.remoteAddress.address}:${socket.remotePort}',
    );
    final connection = PeerConnection(
      socket: socket,
      isIncoming: true,
    );
    _activeConnections.add(connection);
    _connectionController.add(connection);

    connection.onDisconnect.then((_) {
      _activeConnections.remove(connection);
    });
  }

  /// Stop the server and close all connections
  Future<void> stop() async {
    for (final conn in _activeConnections) {
      await conn.disconnect();
    }
    _activeConnections.clear();
    await _serverSocket?.close();
    _serverSocket = null;
    debugPrint('NyxChat P2P Server stopped');
  }

  bool get isRunning => _serverSocket != null;
}

/// Represents a connection to a peer (either incoming or outgoing)
class PeerConnection {
  final Socket socket;
  final bool isIncoming;
  String? peerId;
  String? peerDisplayName;
  String? peerPublicKeyHex;
  String? peerKyberPublicKeyHex;
  /// Kyber KEM ciphertext (set by the responder for the initiator to decapsulate)
  String? kyberCiphertextHex;
  /// Pre-computed Kyber shared secret (set by the responder who performed encapsulation)
  String? kyberSharedSecretHex;

  final StreamController<ProtocolMessage> _messageController =
      StreamController<ProtocolMessage>.broadcast();
  final Completer<void> _disconnectCompleter = Completer<void>();

  StringBuffer _buffer = StringBuffer();

  Stream<ProtocolMessage> get onMessage => _messageController.stream;
  Future<void> get onDisconnect => _disconnectCompleter.future;

  String get remoteAddress => socket.remoteAddress.address;
  int get remotePort => socket.remotePort;

  PeerConnection({
    required this.socket,
    this.isIncoming = false,
    this.peerId,
    this.peerDisplayName,
    this.peerPublicKeyHex,
  }) {
    _startListening();
  }

  void _startListening() {
    socket.listen(
      (data) {
        final incoming = utf8.decode(data);
        _buffer.write(incoming);

        // Process line-delimited JSON messages
        final bufferStr = _buffer.toString();
        final lines = bufferStr.split('\n');

        // If the last element isn't empty, it's incomplete
        if (lines.last.isNotEmpty) {
          _buffer = StringBuffer(lines.removeLast());
        } else {
          lines.removeLast();
          _buffer = StringBuffer();
        }

        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final message = ProtocolMessage.decode(line);
            _handleProtocolMessage(message);
          } catch (e) {
            debugPrint('Failed to parse message: $e');
          }
        }
      },
      onError: (error) {
        debugPrint('Connection error: $error');
        _cleanup();
      },
      onDone: () {
        debugPrint('Connection closed by peer: $peerId');
        _cleanup();
      },
    );
  }

  void _handleProtocolMessage(ProtocolMessage message) {
    // Extract peer info from HELLO messages
    if (message.type == ProtocolMessageType.hello) {
      peerId = message.senderId;
      peerDisplayName = message.payload['displayName'] as String?;
      peerPublicKeyHex = message.payload['publicKeyHex'] as String?;
    }
    _messageController.add(message);
  }

  /// Send a protocol message to the peer
  void send(ProtocolMessage message) {
    try {
      socket.write(message.encode());
    } catch (e) {
      debugPrint('Failed to send message: $e');
    }
  }

  /// Disconnect from the peer
  Future<void> disconnect() async {
    try {
      send(ProtocolMessage.disconnect(senderId: peerId ?? 'unknown'));
      await socket.flush();
      await socket.close();
    } catch (_) {}
    _cleanup();
  }

  void _cleanup() {
    if (!_disconnectCompleter.isCompleted) {
      _disconnectCompleter.complete();
    }
    _messageController.close();
  }

  bool get isConnected => !_disconnectCompleter.isCompleted;
}
