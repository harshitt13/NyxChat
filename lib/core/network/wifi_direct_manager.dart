import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages high-bandwidth Wi-Fi Direct and Bluetooth Classic connections
/// using Google's Nearby Connections API for cross-platform P2P.
/// This is used exclusively for large payload transfers (like images)
/// when the BLE Mesh is too slow.
class WifiDirectManager extends ChangeNotifier {
  final Strategy _strategy = Strategy.P2P_STAR;
  final String _serviceId = 'com.nyxchat.mesh_wifi_direct';

  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _myNyxId;

  // Track active high-bandwidth connections
  final Map<String, String> _connectedEndpoints = {}; // endpointId -> nyxId

  // Callbacks for file transfers
  Function(String nyxId, Uint8List payload)? onPayloadReceived;
  Function(String nyxId, double progress)? onTransferProgress;

  bool get isReady => _isAdvertising || _isDiscovering;
  
  int getConnectedPeersCount() => _connectedEndpoints.length;

  Future<void> init(String myNyxId) async {
    _myNyxId = myNyxId;
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Nearby Connections requires Location, Bluetooth, and Wi-Fi state permissions
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();
  }

  /// Start advertising our presence for high-bandwidth endpoints.
  Future<bool> startAdvertising() async {
    if (_isAdvertising || _myNyxId == null) return false;

    try {
      final success = await Nearby().startAdvertising(
        _myNyxId!, // Use our NyxId as the user name
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) {
          debugPrint('[WiFi-Direct] Adv connection result $id: $status');
        },
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      _isAdvertising = success;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('[WiFi-Direct] Advertising error: $e');
      return false;
    }
  }

  /// Start discovering other high-bandwidth endpoints.
  Future<bool> startDiscovery() async {
    if (_isDiscovering || _myNyxId == null) return false;

    try {
      final success = await Nearby().startDiscovery(
        _myNyxId!,
        _strategy,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          debugPrint('[WiFi-Direct] Found endpoint: $endpointName ($endpointId)');
          // For now, auto-request connection to any NyxChat node we find
          // In a production MANET, we'd only request if we have a file queued.
          _requestConnection(endpointId, endpointName);
        },
        onEndpointLost: (endpointId) {
           debugPrint('[WiFi-Direct] Lost endpoint: $endpointId');
        },
        serviceId: _serviceId,
      );
      _isDiscovering = success;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('[WiFi-Direct] Discovery error: $e');
      return false;
    }
  }

  Future<void> _requestConnection(String endpointId, String nyxId) async {
    try {
      await Nearby().requestConnection(
        _myNyxId!,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpoints[id] = nyxId;
             debugPrint('[WiFi-Direct] Successfully connected to $nyxId');
          }
        },
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('[WiFi-Direct] Connection request failed: $e');
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) async {
    // Automatically accept all incoming NyxChat high-bandwidth requests.
    // Trust is established via E2EE payloads, the pipe itself doesn't need auth.
    await Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES) {
          final nyxId = _connectedEndpoints[endpointId] ?? 'unknown';
          onPayloadReceived?.call(nyxId, payload.bytes!);
        }
      },
      onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {
         if (payloadTransferUpdate.status == PayloadStatus.IN_PROGRESS) {
            final progress = payloadTransferUpdate.bytesTransferred / payloadTransferUpdate.totalBytes;
            final nyxId = _connectedEndpoints[endpointId] ?? 'unknown';
            onTransferProgress?.call(nyxId, progress);
         }
      },
    );
  }

  void _onDisconnected(String endpointId) {
    debugPrint('[WiFi-Direct] Disconnected endpoint: $endpointId');
    _connectedEndpoints.remove(endpointId);
  }

  /// Transfer a large payload (like an encrypted image) via Wi-Fi Direct.
  /// Returns true if the recipient is connected and the transfer started.
  Future<bool> sendLargePayload(String targetNyxId, Uint8List encryptedData) async {
    // Find endpoint ID for this NyxId
    String? targetEndpointId;
    _connectedEndpoints.forEach((eid, nyxId) {
      if (nyxId == targetNyxId) targetEndpointId = eid;
    });

    if (targetEndpointId == null) {
      debugPrint('[WiFi-Direct] Cannot send: $targetNyxId not connected via high-bandwidth.');
      return false;
    }

    try {
      await Nearby().sendBytesPayload(targetEndpointId!, encryptedData);
      return true;
    } catch (e) {
      debugPrint('[WiFi-Direct] Send failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    _isAdvertising = false;
    _isDiscovering = false;
    _connectedEndpoints.clear();
    notifyListeners();
  }
}
