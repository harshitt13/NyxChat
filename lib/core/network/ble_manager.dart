import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_protocol.dart';

/// Represents a peer discovered or connected via BLE.
class BlePeer {
  final String deviceId;
  final String deviceName;
  final BluetoothDevice device;
  String? nyxId;
  int rssi;
  DateTime lastSeen;
  bool isConnected;

  // Per-peer packet assembler
  final BlePacketAssembler assembler = BlePacketAssembler();

  BlePeer({
    required this.deviceId,
    required this.deviceName,
    required this.device,
    this.nyxId,
    this.rssi = 0,
    this.isConnected = false,
  }) : lastSeen = DateTime.now();
}

/// Manages BLE scanning, advertising, connections, and data transfer.
///
/// Acts as a transport layer for the NyxChat mesh — handles discovery
/// of nearby NyxChat nodes and bidirectional communication via GATT.
class BleManager extends ChangeNotifier {
  // State
  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isSupported = false;
  String? _myNyxId;

  // Connected and discovered peers
  final Map<String, BlePeer> _discoveredPeers = {};
  final Map<String, BlePeer> _connectedPeers = {};

  // Callbacks
  Function(BlePeer peer, Map<String, dynamic> message)? onMessageReceived;
  Function(BlePeer peer)? onPeerConnected;
  Function(BlePeer peer)? onPeerDisconnected;

  // Subscriptions
  final List<StreamSubscription> _subscriptions = [];
  Timer? _scanTimer;

  // Getters
  bool get isScanning => _isScanning;
  bool get isAdvertising => _isAdvertising;
  bool get isSupported => _isSupported;
  List<BlePeer> get discoveredPeers => _discoveredPeers.values.toList();
  List<BlePeer> get connectedPeers => _connectedPeers.values.toList();
  int get nearbyCount => _discoveredPeers.length;

  /// Initialize BLE manager — check hardware support.
  Future<void> init() async {
    try {
      _isSupported = await FlutterBluePlus.isSupported;
      if (!_isSupported) {
        debugPrint('[BLE] Bluetooth LE not supported on this device');
        return;
      }

      // Listen for adapter state changes
      final sub = FlutterBluePlus.adapterState.listen((state) {
        debugPrint('[BLE] Adapter state: $state');
        if (state != BluetoothAdapterState.on) {
          _stopAll();
        }
      });
      _subscriptions.add(sub);
    } catch (e) {
      debugPrint('[BLE] Init error: $e');
      _isSupported = false;
    }
  }

  /// Start BLE operations: scanning + advertising.
  Future<void> start(String myNyxId) async {
    if (!_isSupported) return;
    _myNyxId = myNyxId;

    await startScanning();
    notifyListeners();
  }

  /// Start scanning for nearby NyxChat BLE nodes.
  Future<void> startScanning() async {
    if (_isScanning || !_isSupported) return;

    try {
      _isScanning = true;
      notifyListeners();

      // Listen for scan results
      final sub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          _handleScanResult(r);
        }
      });
      _subscriptions.add(sub);

      // Start periodic scanning (scan 4s, pause 6s to save battery)
      _scanCycle();
    } catch (e) {
      debugPrint('[BLE] Scan start error: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  void _scanCycle() {
    if (!_isScanning) return;

    FlutterBluePlus.startScan(
      withServices: [BleProtocol.serviceUuid],
      timeout: const Duration(seconds: 4),
      androidScanMode: AndroidScanMode.lowLatency,
    ).then((_) {
      // After scan completes, wait then scan again
      _scanTimer = Timer(const Duration(seconds: 6), () {
        if (_isScanning) _scanCycle();
      });
    }).catchError((e) {
      debugPrint('[BLE] Scan cycle error: $e');
    });
  }

  /// Stop scanning.
  Future<void> stopScanning() async {
    _isScanning = false;
    _scanTimer?.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    notifyListeners();
  }

  /// Handle a BLE scan result — identify NyxChat nodes.
  void _handleScanResult(ScanResult result) {
    final device = result.device;
    final deviceId = device.remoteId.str;

    // Check if this is a NyxChat node by service UUID
    final hasService = result.advertisementData.serviceUuids
        .any((uuid) => uuid == BleProtocol.serviceUuid);

    if (!hasService) return;

    // Extract NyxChat ID from manufacturer data if available
    String? nyxId;
    final mfgData = result.advertisementData.manufacturerData;
    if (mfgData.containsKey(BleProtocol.manufacturerId)) {
      try {
        final data = mfgData[BleProtocol.manufacturerId]!;
        nyxId = utf8.decode(data);
      } catch (_) {}
    }

    // Skip self
    if (nyxId != null && nyxId == _myNyxId) return;

    final peer = _discoveredPeers[deviceId] ??= BlePeer(
      deviceId: deviceId,
      deviceName: result.advertisementData.advName.isNotEmpty
          ? result.advertisementData.advName
          : 'NyxChat Node',
      device: device,
      nyxId: nyxId,
      rssi: result.rssi,
    );

    peer.lastSeen = DateTime.now();
    peer.rssi = result.rssi;
    if (nyxId != null) peer.nyxId = nyxId;

    notifyListeners();
  }

  /// Connect to a discovered BLE peer.
  Future<bool> connectToPeer(BlePeer peer) async {
    try {
      debugPrint('[BLE] Connecting to ${peer.deviceId}...');

      await peer.device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      // Discover services
      final services = await peer.device.discoverServices();
      final nyxService = services.firstWhere(
        (s) => s.serviceUuid == BleProtocol.serviceUuid,
        orElse: () => throw Exception('NyxChat service not found'),
      );

      // Find RX characteristic and subscribe for notifications
      final rxChar = nyxService.characteristics.firstWhere(
        (c) => c.characteristicUuid == BleProtocol.rxCharUuid,
        orElse: () => throw Exception('RX characteristic not found'),
      );

      await rxChar.setNotifyValue(true);

      // Listen for incoming data
      final sub = rxChar.onValueReceived.listen((value) {
        _handleIncomingData(peer, Uint8List.fromList(value));
      });
      _subscriptions.add(sub);

      // Listen for disconnection
      final disconnSub = peer.device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect(peer);
        }
      });
      _subscriptions.add(disconnSub);

      peer.isConnected = true;
      _connectedPeers[peer.deviceId] = peer;
      notifyListeners();

      onPeerConnected?.call(peer);
      debugPrint('[BLE] Connected to ${peer.deviceId}');

      // Send handshake
      if (_myNyxId != null) {
        await sendMessage(peer, {
          'type': 'ble_hello',
          'nyxId': _myNyxId,
        });
      }

      return true;
    } catch (e) {
      debugPrint('[BLE] Connect error: $e');
      return false;
    }
  }

  /// Send a JSON message to a connected BLE peer.
  Future<bool> sendMessage(BlePeer peer, Map<String, dynamic> message) async {
    if (!peer.isConnected) return false;

    try {
      final data = BleProtocol.encodeMessage(message);

      // Find TX characteristic
      final services = await peer.device.discoverServices();
      final nyxService = services.firstWhere(
        (s) => s.serviceUuid == BleProtocol.serviceUuid,
      );
      final txChar = nyxService.characteristics.firstWhere(
        (c) => c.characteristicUuid == BleProtocol.txCharUuid,
      );

      // Get negotiated MTU
      final mtu = await peer.device.requestMtu(512);

      // Chunk and send
      final chunks = BleProtocol.chunkMessage(data, mtu: mtu - 3);
      for (final chunk in chunks) {
        await txChar.write(chunk, withoutResponse: false);
      }

      return true;
    } catch (e) {
      debugPrint('[BLE] Send error: $e');
      return false;
    }
  }

  /// Handle incoming BLE data — reassemble chunks and parse.
  void _handleIncomingData(BlePeer peer, Uint8List chunk) {
    final assembled = peer.assembler.addChunk(chunk);
    if (assembled != null) {
      final message = BleProtocol.decodeMessage(assembled);
      if (message != null) {
        // Handle handshake
        if (message['type'] == 'ble_hello' && message['nyxId'] != null) {
          peer.nyxId = message['nyxId'] as String;
          notifyListeners();
          return;
        }

        onMessageReceived?.call(peer, message);
      }
    }
  }

  /// Handle peer disconnection.
  void _handleDisconnect(BlePeer peer) {
    debugPrint('[BLE] Disconnected: ${peer.deviceId}');
    peer.isConnected = false;
    peer.assembler.reset();
    _connectedPeers.remove(peer.deviceId);
    notifyListeners();
    onPeerDisconnected?.call(peer);
  }

  /// Disconnect from a specific peer.
  Future<void> disconnectPeer(BlePeer peer) async {
    try {
      await peer.device.disconnect();
    } catch (_) {}
    _handleDisconnect(peer);
  }

  /// Broadcast a message to all connected BLE peers.
  Future<void> broadcast(Map<String, dynamic> message) async {
    for (final peer in _connectedPeers.values.toList()) {
      await sendMessage(peer, message);
    }
  }

  /// Stop all BLE operations.
  void _stopAll() {
    _isScanning = false;
    _isAdvertising = false;
    _scanTimer?.cancel();
    notifyListeners();
  }

  /// Clean shutdown.
  Future<void> stop() async {
    await stopScanning();

    // Disconnect all peers
    for (final peer in _connectedPeers.values.toList()) {
      await disconnectPeer(peer);
    }

    _discoveredPeers.clear();
    _connectedPeers.clear();

    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    _stopAll();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
