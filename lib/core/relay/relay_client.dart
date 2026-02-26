import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../network/tor_manager.dart';

/// Optional internet relay client for cross-network mesh bridging.
///
/// Connects to public relay servers via WebSocket. The relay only sees
/// encrypted blobs — it cannot read content or identify sender/recipient.
///
/// Opt-in only (disabled by default). E2EE is maintained end-to-end;
/// the relay is just a dumb pipe for encrypted packets.
class RelayClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isEnabled = false;
  String? _relayUrl;
  String? _mySubscriptionHash;
  
  // Pluggable Transports / Domain Fronting
  bool _useDomainFronting = false;
  final String _frontingDomain = 'ajax.googleapis.com'; // Innocent looking host

  // Stats
  int _messagesSent = 0;
  int _messagesReceived = 0;

  bool get isConnected => _isConnected;
  bool get isEnabled => _isEnabled;
  String? get relayUrl => _relayUrl;
  int get messagesSent => _messagesSent;
  int get messagesReceived => _messagesReceived;

  // Callbacks
  Function(Map<String, dynamic> data)? onRelayMessage;

  /// Enable relay and connect.
  Future<void> enable({
    required String url,
    required String subscriptionHash,
    bool useDomainFronting = false,
  }) async {
    _relayUrl = url;
    _mySubscriptionHash = subscriptionHash;
    _useDomainFronting = useDomainFronting;
    _isEnabled = true;
    notifyListeners();
    await connect();
  }

  /// Disable relay and disconnect.
  Future<void> disable() async {
    _isEnabled = false;
    await disconnect();
    notifyListeners();
  }

  /// Connect to relay server.
  Future<void> connect() async {
    if (!_isEnabled || _relayUrl == null) return;

    try {
      final proxyClient = TorManager.createTorHttpClient();
      
      // Pluggable Transports: Domain Fronting
      Map<String, dynamic>? customHeaders;
      String targetUrl = _relayUrl!;
      
      if (_useDomainFronting) {
        final originalUri = Uri.parse(_relayUrl!);
        customHeaders = {
          'Host': originalUri.host,
        };
        // Connect to the innocent fronting domain instead of the actual restricted relay IP
        targetUrl = '${originalUri.scheme}://$_frontingDomain${originalUri.path}';
        debugPrint('[Relay] Domain Fronting enabled. Tunneling through $_frontingDomain');
      }

      final ws = await WebSocket.connect(
        targetUrl, 
        customClient: proxyClient,
        headers: customHeaders,
      );
      
      _channel = IOWebSocketChannel(ws);
      await _channel!.ready;

      _isConnected = true;
      notifyListeners();
      debugPrint('[Relay] Connected to $_relayUrl');

      // Subscribe to our anonymous hash
      _send({
        'action': 'subscribe',
        'hash': _mySubscriptionHash,
      });

      // Listen for messages
      _channel!.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (e) {
          debugPrint('[Relay] Error: $e');
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[Relay] Connection closed');
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[Relay] Connect error: $e');
      _isConnected = false;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  /// Send an encrypted blob through the relay.
  void publish(String recipientHash, String encryptedBlob) {
    _send({
      'action': 'publish',
      'to': recipientHash,
      'data': encryptedBlob,
    });
    _messagesSent++;
    notifyListeners();
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      _messagesReceived++;
      onRelayMessage?.call(data);
      notifyListeners();
    } catch (e) {
      debugPrint('[Relay] Parse error: $e');
    }
  }

  void _scheduleReconnect() {
    if (!_isEnabled) return;
    Timer(const Duration(seconds: 10), () {
      if (_isEnabled && !_isConnected) connect();
    });
  }

  /// Disconnect from relay.
  Future<void> disconnect() async {
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    notifyListeners();
  }

  /// Clear all relay state.
  void clear() {
    disconnect();
    _isEnabled = false;
    _relayUrl = null;
    _messagesSent = 0;
    _messagesReceived = 0;
    notifyListeners();
  }
}
