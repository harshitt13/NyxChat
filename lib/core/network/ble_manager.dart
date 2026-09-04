import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'ble_peripheral.dart';
import 'ble_protocol.dart';

/// One BLE link to a neighbour, in either GATT role.
///
/// * central role: we scanned and connected; we write to their TX and
///   receive notifications on their RX.
/// * peripheral role: they connected to our GATT server; we receive their
///   writes on our TX and push data with notifications on our RX.
class BleLink {
  final String address;
  final bool isCentralRole;
  final BluetoothDevice? device;
  BluetoothCharacteristic? txChar;
  String? nyxId;
  int mtu = 23;
  int rssi = 0;
  DateTime lastSeen = DateTime.now();
  final BlePacketAssembler assembler = BlePacketAssembler();
  final List<StreamSubscription> subscriptions = [];
  bool _sending = false;
  final List<Uint8List> _queue = [];

  BleLink({required this.address, required this.isCentralRole, this.device});

  int get payloadMtu => math.max(20, mtu - 3);
  bool get hasQueue => _queue.isNotEmpty;
}

/// Discovered-but-not-linked neighbour.
class BlePeer {
  final String deviceId;
  final String deviceName;
  final BluetoothDevice device;
  String? nyxId;
  int rssi;
  DateTime lastSeen = DateTime.now();
  BlePeer({
    required this.deviceId,
    required this.deviceName,
    required this.device,
    this.nyxId,
    this.rssi = 0,
  });
}

/// BLE transport for the mesh: scanning + central connections via
/// flutter_blue_plus, advertising + GATT server via the native
/// [BlePeripheral]. Both roles present the same [BleLink] API upwards.
class BleManager extends ChangeNotifier {
  static const Duration scanWindow = Duration(seconds: 4);
  static const Duration scanPauseMoving = Duration(seconds: 6);
  static const Duration scanPauseStationary = Duration(seconds: 60);

  final BlePeripheral _peripheral;

  bool _isScanning = false;
  bool _isSupported = false;
  bool _peripheralSupported = false;
  bool _longRange = false;
  bool _isStationary = false;
  String? _myNyxId;

  final Map<String, BlePeer> _discovered = {};
  final Map<String, BleLink> _links = {};
  final List<StreamSubscription> _subs = [];
  final List<double> _accel = [];
  Timer? _scanTimer;

  void Function(BleLink link)? onLinkUp;
  void Function(BleLink link)? onLinkDown;
  void Function(BleLink link, Map<String, dynamic> message)? onMessage;

  BleManager({BlePeripheral? peripheral})
      : _peripheral = peripheral ?? BlePeripheral();

  bool get isScanning => _isScanning;
  bool get isAdvertising => _peripheral.isAdvertising;
  bool get isSupported => _isSupported;
  bool get isPeripheralSupported => _peripheralSupported;
  bool get isLongRangeEnabled => _longRange;
  List<BlePeer> get discoveredPeers => _discovered.values.toList();
  List<BleLink> get links => _links.values.toList();
  int get nearbyCount => _discovered.length;
  int get linkCount => _links.length;

  Future<void> init() async {
    try {
      _isSupported = await FlutterBluePlus.isSupported;
      if (!_isSupported) return;
      _peripheralSupported = await _peripheral.isSupported();
      _subs.add(FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on) _stopAll();
      }));
      _initSensors();
    } catch (e) {
      debugPrint('[BLE] init error: $e');
      _isSupported = false;
    }
  }

  void _initSensors() {
    try {
      _subs.add(userAccelerometerEventStream(
              samplingPeriod: const Duration(seconds: 1))
          .listen((e) {
        final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        _accel.add(mag);
        if (_accel.length > 10) _accel.removeAt(0);
        if (_accel.length == 10) {
          final avg = _accel.reduce((a, b) => a + b) / 10;
          final maxDiff = _accel.map((v) => (v - avg).abs()).reduce(math.max);
          final was = _isStationary;
          _isStationary = maxDiff < 0.5;
          if (was && !_isStationary && _isScanning) {
            _scanTimer?.cancel();
            _scanCycle();
          }
        }
      }));
    } catch (e) {
      debugPrint('[BLE] sensors unavailable: $e');
    }
  }

  void setLongRange(bool enabled) {
    _longRange = enabled;
    notifyListeners();
  }

  Future<void> start(String myNyxId) async {
    if (!_isSupported) return;
    _myNyxId = myNyxId;
    _peripheral.onWrite = _onPeripheralWrite;
    _peripheral.onSubscribed = _onCentralSubscribed;
    _peripheral.onDisconnected = (address) {
      final link = _links[address];
      if (link != null && !link.isCentralRole) _dropLink(link);
    };
    _peripheral.onMtu = (address, mtu) {
      _links[address]?.mtu = mtu;
    };
    if (_peripheralSupported) {
      final ok = await _peripheral.start(myNyxId);
      debugPrint('[BLE] advertising ${ok ? 'started' : 'failed'}');
    }
    await startScanning();
    notifyListeners();
  }

  Future<void> startScanning() async {
    if (_isScanning || !_isSupported) return;
    _isScanning = true;
    _subs.add(FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        _handleScanResult(r);
      }
    }));
    _scanCycle();
    notifyListeners();
  }

  void _scanCycle() {
    if (!_isScanning) return;
    FlutterBluePlus.startScan(
      withServices: [BleProtocol.serviceUuid],
      timeout: scanWindow,
      androidScanMode: AndroidScanMode.lowLatency,
    ).then((_) {
      final pause = _isStationary ? scanPauseStationary : scanPauseMoving;
      _scanTimer = Timer(pause, () {
        if (_isScanning) _scanCycle();
      });
    }).catchError((e) {
      debugPrint('[BLE] scan error: $e');
    });
  }

  Future<void> stopScanning() async {
    _isScanning = false;
    _scanTimer?.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    notifyListeners();
  }

  void _handleScanResult(ScanResult result) {
    final adv = result.advertisementData;
    if (!adv.serviceUuids.any((u) => u == BleProtocol.serviceUuid)) return;
    String? nyxId;
    final mfg = adv.manufacturerData[BleProtocol.manufacturerId];
    if (mfg != null) {
      try {
        nyxId = utf8.decode(mfg);
      } catch (_) {}
    }
    if (nyxId != null && nyxId == _myNyxId) return;
    final id = result.device.remoteId.str;
    final peer = _discovered[id] ??= BlePeer(
      deviceId: id,
      deviceName: adv.advName.isNotEmpty ? adv.advName : 'NyxChat node',
      device: result.device,
    );
    peer.lastSeen = DateTime.now();
    peer.rssi = result.rssi;
    if (nyxId != null) peer.nyxId = nyxId;
    notifyListeners();

    // Avoid two links between the same pair: only the smaller id dials.
    final mine = _myNyxId;
    final shouldDial = !_peripheralSupported ||
        (mine != null && nyxId != null && mine.compareTo(nyxId) < 0);
    if (nyxId != null && mine != null && shouldDial &&
        !_hasLinkTo(nyxId) && !_links.containsKey(id)) {
      unawaited(connectToPeer(peer));
    }
  }

  bool _hasLinkTo(String nyxId) => _links.values.any((l) => l.nyxId == nyxId);

  /// Connect in the central role.
  Future<bool> connectToPeer(BlePeer peer) async {
    if (_links.containsKey(peer.deviceId)) return true;
    final link = BleLink(
        address: peer.deviceId, isCentralRole: true, device: peer.device);
    _links[peer.deviceId] = link;
    try {
      await peer.device.connect(
          timeout: const Duration(seconds: 10), autoConnect: false);
      final services = await peer.device.discoverServices();
      final svc = services.firstWhere(
          (s) => s.serviceUuid == BleProtocol.serviceUuid,
          orElse: () => throw Exception('NyxChat service not found'));
      final rx = svc.characteristics.firstWhere(
          (c) => c.characteristicUuid == BleProtocol.rxCharUuid,
          orElse: () => throw Exception('RX characteristic not found'));
      final tx = svc.characteristics.firstWhere(
          (c) => c.characteristicUuid == BleProtocol.txCharUuid,
          orElse: () => throw Exception('TX characteristic not found'));
      link.txChar = tx;
      try {
        link.mtu = await peer.device.requestMtu(512);
      } catch (_) {}
      if (_longRange) {
        try {
          await peer.device.setPreferredPhy(
              txPhy: Phy.leCoded.mask,
              rxPhy: Phy.leCoded.mask,
              option: PhyCoding.s8);
        } catch (_) {}
      }
      await rx.setNotifyValue(true);
      link.subscriptions.add(rx.onValueReceived.listen((value) {
        _onLinkData(link, Uint8List.fromList(value));
      }));
      link.subscriptions.add(peer.device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) _dropLink(link);
      }));
      link.nyxId = peer.nyxId;
      await _sendHello(link);
      _linkUp(link);
      return true;
    } catch (e) {
      debugPrint('[BLE] connect ${peer.deviceId} failed: $e');
      _links.remove(peer.deviceId);
      try {
        await peer.device.disconnect();
      } catch (_) {}
      return false;
    }
  }

  // Peripheral role events

  void _onCentralSubscribed(String address) {
    final link = _links[address] ??=
        BleLink(address: address, isCentralRole: false);
    unawaited(_sendHello(link));
  }

  void _onPeripheralWrite(String address, Uint8List data) {
    final link = _links[address] ??=
        BleLink(address: address, isCentralRole: false);
    _onLinkData(link, data);
  }

  // Common

  Future<void> _sendHello(BleLink link) async {
    if (_myNyxId == null) return;
    await sendJson(link, {'type': 'ble_hello', 'nyxId': _myNyxId});
  }

  void _onLinkData(BleLink link, Uint8List chunk) {
    link.lastSeen = DateTime.now();
    final assembled = link.assembler.addChunk(chunk);
    if (assembled == null) return;
    final message = BleProtocol.decodeMessage(assembled);
    if (message == null) return;
    if (message['type'] == 'ble_hello') {
      final id = message['nyxId'];
      if (id is String && id.isNotEmpty && id.length <= 32) {
        final wasUp = link.nyxId != null;
        link.nyxId = id;
        if (!wasUp) _linkUp(link);
        notifyListeners();
      }
      return;
    }
    onMessage?.call(link, message);
  }

  void _linkUp(BleLink link) {
    if (link.nyxId == null) return;
    debugPrint('[BLE] link up ${link.address} (${link.nyxId}) '
        '${link.isCentralRole ? 'central' : 'peripheral'}');
    onLinkUp?.call(link);
    notifyListeners();
  }

  void _dropLink(BleLink link) {
    if (_links.remove(link.address) == null) return;
    for (final s in link.subscriptions) {
      s.cancel();
    }
    link.assembler.reset();
    debugPrint('[BLE] link down ${link.address}');
    onLinkDown?.call(link);
    notifyListeners();
  }

  /// Send a JSON message over one link (chunked to the negotiated MTU).
  Future<bool> sendJson(BleLink link, Map<String, dynamic> message) async {
    final data = BleProtocol.encodeMessage(message);
    if (data.length > BleProtocol.maxPacketSize) return false;
    link._queue.add(data);
    if (link._sending) return true;
    link._sending = true;
    try {
      while (link._queue.isNotEmpty) {
        final next = link._queue.removeAt(0);
        final chunks = BleProtocol.chunkMessage(next, mtu: link.payloadMtu + 3);
        for (final chunk in chunks) {
          if (link.isCentralRole) {
            final tx = link.txChar;
            if (tx == null) return false;
            await tx.write(chunk, withoutResponse: false);
          } else {
            final ok = await _peripheral.notify(link.address, chunk);
            if (!ok) return false;
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('[BLE] send failed on ${link.address}: $e');
      return false;
    } finally {
      link._sending = false;
    }
  }

  Future<void> broadcastJson(Map<String, dynamic> message) async {
    for (final link in _links.values.toList()) {
      if (link.nyxId != null) await sendJson(link, message);
    }
  }

  BleLink? linkForNyxId(String nyxId) {
    for (final l in _links.values) {
      if (l.nyxId == nyxId) return l;
    }
    return null;
  }

  Future<void> disconnectLink(BleLink link) async {
    try {
      await link.device?.disconnect();
    } catch (_) {}
    _dropLink(link);
  }

  void _stopAll() {
    _isScanning = false;
    _scanTimer?.cancel();
    notifyListeners();
  }

  Future<void> stop() async {
    await stopScanning();
    await _peripheral.stop();
    for (final link in _links.values.toList()) {
      await disconnectLink(link);
    }
    _discovered.clear();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _stopAll();
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}