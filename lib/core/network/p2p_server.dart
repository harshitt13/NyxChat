import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../crypto/handshake.dart';
import '../crypto/secure_channel.dart';
import 'message_protocol.dart';

/// TCP listener for incoming direct connections.
class P2PServer {
  ServerSocket? _serverSocket;
  final int port;

  final StreamController<PeerConnection> _connectionController =
      StreamController<PeerConnection>.broadcast();
  final List<PeerConnection> _active = [];

  Stream<PeerConnection> get onNewConnection => _connectionController.stream;
  List<PeerConnection> get activeConnections => List.unmodifiable(_active);
  bool get isRunning => _serverSocket != null;

  /// The port actually bound (differs from [port] when 0 was requested).
  int get boundPort => _serverSocket?.port ?? port;

  P2PServer({required this.port});

  Future<void> start() async {
    if (_serverSocket != null) return;
    // Dual-stack: LAN peers over IPv4, Wi-Fi Aware peers over link-local IPv6.
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv6, port,
        shared: true);
    debugPrint('[P2P] listening on $port');
    _serverSocket!.listen(_handle, onError: (e) {
      debugPrint('[P2P] server error: $e');
    });
  }

  void _handle(Socket socket) {
    final connection = PeerConnection(socket: socket, isIncoming: true);
    _active.add(connection);
    _connectionController.add(connection);
    unawaited(connection.onDisconnect.then((_) => _active.remove(connection)));
  }

  Future<void> stop() async {
    for (final c in _active.toList()) {
      await c.disconnect();
    }
    _active.clear();
    await _serverSocket?.close();
    _serverSocket = null;
  }
}

/// One TCP link to a peer. Handles line framing, size limits, keep-alive
/// and (after the handshake) link encryption. Handshake orchestration lives
/// in ConnectionManager.
class PeerConnection {
  static const Duration pingInterval = Duration(seconds: 30);
  static const Duration idleTimeout = Duration(seconds: 95);
  static const Duration handshakeTimeout = Duration(seconds: 15);

  final Socket socket;
  final bool isIncoming;
  final DateTime openedAt = DateTime.now();

  String? peerId;
  HandshakeResult? handshake;
  SecureChannel? _channel;

  final StreamController<ProtocolMessage> _messages =
      StreamController<ProtocolMessage>.broadcast();
  final Completer<void> _disconnected = Completer<void>();
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  Timer? _pingTimer;
  DateTime _lastActivity = DateTime.now();
  bool _closing = false;
  int _resetsSent = 0;

  Stream<ProtocolMessage> get onMessage => _messages.stream;
  Future<void> get onDisconnect => _disconnected.future;
  bool get isConnected => !_disconnected.isCompleted;
  bool get isSecure => _channel != null;
  bool get isAuthenticated => handshake != null && _channel != null;
  /// Peer address as dialled: IPv4 peers of the dual-stack server show up
  /// as IPv4-mapped IPv6 (`::ffff:a.b.c.d`) and are reported plain.
  String get remoteAddress {
    final a = socket.remoteAddress.address;
    return a.startsWith('::ffff:') && a.contains('.') ? a.substring(7) : a;
  }
  int get remotePort => socket.remotePort;
  int get resetsSent => _resetsSent;
  void noteResetSent() => _resetsSent++;

  PeerConnection({required this.socket, required this.isIncoming}) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    socket.listen(_onData, onError: (e) {
      debugPrint('[P2P] socket error ($peerId): $e');
      _cleanup();
    }, onDone: _cleanup);
    _pingTimer = Timer.periodic(pingInterval, (_) => _tick());
  }

  void installChannel(SecureChannel channel) {
    _channel = channel;
  }

  void _tick() {
    if (!isConnected) return;
    if (DateTime.now().difference(_lastActivity) > idleTimeout) {
      debugPrint('[P2P] idle timeout for $peerId');
      unawaited(disconnect());
      return;
    }
    if (isAuthenticated) unawaited(send(ProtocolMessage.ping()));
  }

  // Frames are processed strictly in order: socket events can arrive while
  // an earlier line is still being decrypted, so each line is chained onto
  // the previous one instead of being handled concurrently.
  Future<void> _chain = Future.value();

  void _onData(List<int> data) {
    _lastActivity = DateTime.now();
    _buffer.add(data);
    if (_buffer.length > ProtocolMessage.maxFrameBytes) {
      debugPrint('[P2P] frame limit exceeded, dropping $remoteAddress');
      _buffer.clear();
      unawaited(disconnect());
      return;
    }
    final bytes = _buffer.takeBytes();
    var start = 0;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0x0A) {
        if (i > start) {
          final line = bytes.sublist(start, i);
          _chain = _chain.then((_) => _handleLine(line));
        }
        start = i + 1;
      }
    }
    if (start < bytes.length) _buffer.add(bytes.sublist(start));
  }

  Future<void> _handleLine(List<int> lineBytes) async {
    if (!isConnected) return;
    try {
      var line = utf8.decode(lineBytes);
      final json = jsonDecode(line) as Map<String, dynamic>;
      Map<String, dynamic> frameJson = json;
      if (SecureChannel.isSealedFrame(json)) {
        final channel = _channel;
        if (channel == null) {
          debugPrint('[P2P] sealed frame before handshake, dropping link');
          await disconnect();
          return;
        }
        line = await channel.open(json);
        frameJson = jsonDecode(line) as Map<String, dynamic>;
      } else if (_channel != null) {
        // Once sealed, plaintext frames are not acceptable any more.
        debugPrint('[P2P] plaintext frame on sealed link, dropping link');
        await disconnect();
        return;
      }
      final message = ProtocolMessage.fromJson(frameJson);
      switch (message.type) {
        case ProtocolMessageType.ping:
          if (isAuthenticated) await send(ProtocolMessage.pong());
          return;
        case ProtocolMessageType.pong:
          return;
        case ProtocolMessageType.disconnect:
          await disconnect();
          return;
        case ProtocolMessageType.unknown:
          return;
        default:
          _messages.add(message);
      }
    } on StateError catch (e) {
      // Replay / tamper on the secure channel: the link is compromised.
      debugPrint('[P2P] secure channel failure ($peerId): $e');
      await disconnect();
    } catch (e) {
      debugPrint('[P2P] bad frame from $remoteAddress: $e');
    }
  }

  /// Send a frame, sealing it when the link is secured.
  Future<void> send(ProtocolMessage message) async {
    if (!isConnected) return;
    try {
      final line = message.encode();
      final channel = _channel;
      if (channel != null) {
        socket.write('${await channel.seal(line.trimRight())}\n');
      } else {
        socket.write(line);
      }
    } catch (e) {
      debugPrint('[P2P] send failed ($peerId): $e');
    }
  }

  /// Wait for the next frame of a given type (used during the handshake).
  Future<ProtocolMessage> nextOfType(ProtocolMessageType type,
      {Duration timeout = handshakeTimeout}) {
    return onMessage
        .firstWhere((m) => m.type == type)
        .timeout(timeout, onTimeout: () {
      throw TimeoutException('timed out waiting for ${type.name}');
    });
  }

  Future<void> disconnect() async {
    if (_closing) return;
    _closing = true;
    try {
      if (isAuthenticated) await send(ProtocolMessage.disconnect());
      await socket.flush().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await socket.close();
    } catch (_) {}
    _cleanup();
  }

  void _cleanup() {
    _pingTimer?.cancel();
    if (!_disconnected.isCompleted) _disconnected.complete();
    if (!_messages.isClosed) _messages.close();
    _channel?.dispose();
  }
}