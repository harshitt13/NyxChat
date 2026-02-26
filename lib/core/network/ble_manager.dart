import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
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
  
  // Cache the TX characteristic to avoid re-discovery on every send
  BluetoothCharacteristic? cachedTxChar;

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

  // Long-range (Coded PHY) mode
  bool _longRangeEnabled = false;
  bool get isLongRangeEnabled => _longRangeEnabled;

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
  
  // Sensor logic
  bool _isStationary = false;
  final List<double> _accelerationHistory = [];
  final int _accelerationWindowSize = 10;
  final double _stationaryThreshold = 0.5;

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
      
      _initSensors();
    } catch (e) {
      debugPrint('[BLE] Init error: $e');
      _isSupported = false;
    }
  }

  /// Initialize accelerometer to control BLE scan frequencies
  void _initSensors() {
    try {
      final sub = userAccelerometerEventStream(samplingPeriod: const Duration(seconds: 1)).listen((UserAccelerometerEvent event) {
        // Calculate magnitude of acceleration ignoring gravity
        final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        
        _accelerationHistory.add(magnitude);
        if (_accelerationHistory.length > _accelerationWindowSize) {
          _accelerationHistory.removeAt(0);
        }

        // If we have enough history, check variance
        if (_accelerationHistory.length == _accelerationWindowSize) {
          final avg = _accelerationHistory.reduce((a, b) => a + b) / _accelerationWindowSize;
          final maxDiff = _accelerationHistory.map((v) => (v - avg).abs()).reduce(math.max);
          
          final wasStationary = _isStationary;
          _isStationary = maxDiff < _stationaryThreshold;

          // If we woke up from being stationary, instantly trigger a scan cycle
          if (wasStationary && !_isStationary && _isScanning) {
            debugPrint('[BLE] Movement detected. Resuming aggressive scan.');
            _scanTimer?.cancel();
            _scanCycle();
          }
        }
      });
      _subscriptions.add(sub);
    } catch (e) {
       debugPrint('[BLE] Sensors init error: $e');
    }
  }

  /// Enable or disable BLE 5.0 Long Range (Coded PHY) mode.
  ///
  /// Coded PHY uses heavy error correction to extend outdoor line-of-sight
  /// range from ~30 m to over 1 km, at the cost of lower throughput.
  /// Only effective on hardware that supports Bluetooth 5.0+.
  void setLongRange(bool enabled) {
    _longRangeEnabled = enabled;
    debugPrint('[BLE] Long Range (Coded PHY) mode: ${enabled ? "ON" : "OFF"}');
    notifyListeners();
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
      // Adaptive Scanning: Wait 6s if moving, 60s if stationary.
      final delaySeconds = _isStationary ? 60 : 6;
      if (_isStationary) {
        debugPrint('[BLE] Device stationary. Throttling scan to $delaySeconds seconds.');
      }
      
      _scanTimer = Timer(Duration(seconds: delaySeconds), () {
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

      // Cache TX characteristic for later sends (avoids re-discovery)
      try {
        final txChar = nyxService.characteristics.firstWhere(
          (c) => c.characteristicUuid == BleProtocol.txCharUuid,
        );
        peer.cachedTxChar = txChar;
      } catch (_) {
        debugPrint('[BLE] TX characteristic not found during connect, will discover later');
      }

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

      // Negotiate Coded PHY for long-range connections (BLE 5.0+)
      if (_longRangeEnabled) {
        try {
          await peer.device.setPreferredPhy(
            txPhy: Phy.leCoded.mask,
            rxPhy: Phy.leCoded.mask,
            option: PhyCoding.s8, // S=8 coding: maximum range
          );
          debugPrint('[BLE] Coded PHY (Long Range S=8) negotiated for ${peer.deviceId}');
        } catch (e) {
          // Hardware may not support Coded PHY — gracefully fall back to 1M
          debugPrint('[BLE] Coded PHY not supported on ${peer.deviceId}: $e');
        }
      }

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

      // Use cached TX characteristic if available, otherwise discover
      BluetoothCharacteristic? txChar = peer.cachedTxChar;
      if (txChar == null) {
        final services = await peer.device.discoverServices();
        final nyxService = services.firstWhere(
          (s) => s.serviceUuid == BleProtocol.serviceUuid,
        );
        txChar = nyxService.characteristics.firstWhere(
          (c) => c.characteristicUuid == BleProtocol.txCharUuid,
        );
        peer.cachedTxChar = txChar; // Cache for future sends
      }

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
    peer.cachedTxChar = null;
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
