import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'ble_peripheral.dart';
import 'ble_protocol.dart';
import 'discovery_beacon.dart';

/// One BLE link to a neighbour, in either GATT role.
class BleLink {
  final String address;
  final bool isCentralRole;
  final BluetoothDevice? device;
  BluetoothCharacteristic? txChar;
  String? nyxId;
  String? relayIdHex;
  int mtu = 23;
  int rssi = 0;
  DateTime lastSeen = DateTime.now();
  final BlePacketAssembler assembler = BlePacketAssembler();
  final List<StreamSubscription> subscriptions = [];
  bool _sending = false;
  final List<Uint8List> _queue = [];

  BleLink({required this.address, required this.isCentralRole, this.device});

  int get payloadMtu => math.max(20, mtu - 3);
}

/// Discovered-but-not-linked neighbour.
class BlePeer {
  final String deviceId;
  final String deviceName;
  final BluetoothDevice device;
  String? nyxId; // known (public beacon) or best candidate (private beacon)
  bool isCandidate = false;
  int rssi;
  DateTime lastSeen = DateTime.now();
  BlePeer({required this.deviceId, required this.deviceName, required this.device, this.nyxId, this.rssi = 0});
}

/// BLE transport for the mesh: scanning + central connections via
/// flutter_blue_plus, advertising + GATT server via the native
/// [BlePeripheral]. Both roles present the same [BleLink] API upwards.
///
/// Frames on a link are either JSON (first byte '{') for control
/// (`ble_hello`) or a raw binary mesh packet (first byte = packet version).
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
  String _myRelayIdHex = '';

  final Map<String, BlePeer> _discovered = {};
  final Map<String, BleLink> _links = {};
  final List<StreamSubscription> _subs = [];
  final List<double> _accel = [];
  Timer? _scanTimer;

  void Function(BleLink link)? onLinkUp;
  void Function(BleLink link)? onLinkDown;
  void Function(BleLink link, Map<String, dynamic> message)? onMessage;
  void Function(BleLink link, Uint8List packetBytes)? onMeshPacket;

  /// Resolve a private beacon to candidate contact ids (set by PeerService).
  Future<List<String>> Function(Uint8List bloom, int slot)? resolveBeacon;

  BleManager({BlePeripheral? peripheral}) : _peripheral = peripheral ?? BlePeripheral();

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
      _subs.add(userAccelerometerEventStream(samplingPeriod: const Duration(seconds: 1)).listen((e) {
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

  /// Start scanning and advertising [beacon].
  Future<void> start(String myNyxId, {required String relayIdHex, required Uint8List beacon}) async {
    if (!_isSupported) return;
    _myNyxId = myNyxId;
    _myRelayIdHex = relayIdHex;
    _peripheral.onWrite = _onPeripheralWrite;
    _peripheral.onSubscribed = _onCentralSubscribed;
    _peripheral.onDisconnected = (address) {
      final link = _links[address];
      if (link != null && !link.isCentralRole) _dropLink(link);
    };
    _peripheral.onMtu = (address, mtu) => _links[address]?.mtu = mtu;
    if (_peripheralSupported) {
      final ok = await _peripheral.start(beacon);
      debugPrint('[BLE] advertising ${ok ? 'started' : 'failed'}');
    }
    await startScanning();
    notifyListeners();
  }

  /// Rotate the advertised beacon.
  Future<void> updateBeacon(Uint8List beacon) async {
    if (_peripheralSupported && _peripheral.isAdvertising) {
      await _peripheral.updateBeacon(beacon);
    }
  }

  Future<void> startScanning() async {
    if (_isScanning || !_isSupported) return;
    _isScanning = true;
    _subs.add(FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        unawaited(_handleScanResult(r));
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
  Future<void> _handleScanResult(ScanResult result) async {
    final adv = result.advertisementData;
    if (!adv.serviceUuids.any((u) => u == BleProtocol.serviceUuid)) return;
    final mfg = adv.manufacturerData[BleProtocol.manufacturerId];
    final beacon = mfg == null ? null : DiscoveryBeacon.decodeBle(mfg);
    String? nyxId;
    var candidate = false;
    if (beacon != null && beacon.isPublic) {
      nyxId = beacon.nyxId;
    } else if (beacon != null && beacon.bloom != null) {
      final matches = await resolveBeacon?.call(beacon.bloom!, beacon.slot) ?? const [];
      if (matches.isNotEmpty) {
        nyxId = matches.first;
        candidate = true;
      }
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
    if (nyxId != null) {
      peer.nyxId = nyxId;
      peer.isCandidate = candidate;
    }
    notifyListeners();

    // Avoid two links between the same pair: only the smaller id dials,
    // unless we cannot advertise (then nobody would ever dial us).
    final mine = _myNyxId;
    final shouldDial = !_peripheralSupported ||
        (mine != null && nyxId != null && mine.compareTo(nyxId) < 0);
    if (nyxId != null && mine != null && shouldDial && !_hasLinkTo(nyxId) && !_links.containsKey(id)) {
      unawaited(connectToPeer(peer));
    }
  }

  bool _hasLinkTo(String nyxId) => _links.values.any((l) => l.nyxId == nyxId);

  /// Connect in the central role.
  Future<bool> connectToPeer(BlePeer peer) async {
    if (_links.containsKey(peer.deviceId)) return true;
    final link = BleLink(address: peer.deviceId, isCentralRole: true, device: peer.device);
    _links[peer.deviceId] = link;
    try {
      await peer.device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
      final services = await peer.device.discoverServices();
      final svc = services.firstWhere((s) => s.serviceUuid == BleProtocol.serviceUuid,
          orElse: () => throw Exception('NyxChat service not found'));
      final rx = svc.characteristics.firstWhere((c) => c.characteristicUuid == BleProtocol.rxCharUuid,
          orElse: () => throw Exception('RX characteristic not found'));
      final tx = svc.characteristics.firstWhere((c) => c.characteristicUuid == BleProtocol.txCharUuid,
          orElse: () => throw Exception('TX characteristic not found'));
      link.txChar = tx;
      try {
        link.mtu = await peer.device.requestMtu(512);
      } catch (_) {}
      if (_longRange) {
        try {
          await peer.device.setPreferredPhy(txPhy: Phy.leCoded.mask, rxPhy: Phy.leCoded.mask, option: PhyCoding.s8);
        } catch (_) {}
      }
      await rx.setNotifyValue(true);
      link.subscriptions.add(rx.onValueReceived.listen((value) => _onLinkData(link, Uint8List.fromList(value))));
      link.subscriptions.add(peer.device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) _dropLink(link);
      }));
      await _sendHello(link);
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
    final link = _links[address] ??= BleLink(address: address, isCentralRole: false);
    unawaited(_sendHello(link));
  }

  void _onPeripheralWrite(String address, Uint8List data) {
    final link = _links[address] ??= BleLink(address: address, isCentralRole: false);
    _onLinkData(link, data);
  }

  // Common

  Future<void> _sendHello(BleLink link) async {
    if (_myNyxId == null) return;
    await sendJson(link, {'type': 'ble_hello', 'nyxId': _myNyxId, 'relay': _myRelayIdHex});
  }

  void _onLinkData(BleLink link, Uint8List chunk) {
    link.lastSeen = DateTime.now();
    final assembled = link.assembler.addChunk(chunk);
    if (assembled == null || assembled.isEmpty) return;
    if (assembled[0] != 0x7B) {
      // Binary frame: a mesh packet.
      if (link.nyxId != null) onMeshPacket?.call(link, assembled);
      return;
    }
    final message = BleProtocol.decodeMessage(assembled);
    if (message == null) return;
    if (message['type'] == 'ble_hello') {
      final id = message['nyxId'];
      final relay = message['relay'];
      if (id is String && id.isNotEmpty && id.length <= 32) {
        final wasUp = link.nyxId != null;
        link.nyxId = id;
        if (relay is String && relay.length == 16) link.relayIdHex = relay;
        if (!wasUp) _linkUp(link);
        notifyListeners();
      }
      return;
    }
    onMessage?.call(link, message);
  }

  void _linkUp(BleLink link) {
    if (link.nyxId == null) return;
    debugPrint('[BLE] link up ${link.address} (${link.nyxId}) ${link.isCentralRole ? 'central' : 'peripheral'}');
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

  Future<bool> sendJson(BleLink link, Map<String, dynamic> message) =>
      sendBytes(link, BleProtocol.encodeMessage(message));

  /// Send raw bytes over one link (chunked to the negotiated MTU).
  Future<bool> sendBytes(BleLink link, Uint8List data) async {
    if (data.length > BleProtocol.maxPacketSize) return false;
    link._queue.add(data);
    if (link._sending) return true;
    link._sending = true;
    try {
      while (link._queue.isNotEmpty) {
        final next = link._queue.removeAt(0);
        for (final chunk in BleProtocol.chunkMessage(next, mtu: link.payloadMtu + 3)) {
          if (link.isCentralRole) {
            final tx = link.txChar;
            if (tx == null) return false;
            await tx.write(chunk, withoutResponse: false);
          } else {
            if (!await _peripheral.notify(link.address, chunk)) return false;
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

  Future<void> broadcastBytes(Uint8List data) async {
    for (final link in _links.values.toList()) {
      if (link.nyxId != null) await sendBytes(link, data);
    }
  }

  BleLink? linkForNyxId(String nyxId) {
    for (final l in _links.values) {
      if (l.nyxId == nyxId) return l;
    }
    return null;
  }

  BleLink? linkForRelayId(String relayIdHex) {
    for (final l in _links.values) {
      if (l.relayIdHex == relayIdHex) return l;
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
