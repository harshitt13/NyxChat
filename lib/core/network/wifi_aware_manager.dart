import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'discovery_beacon.dart';

/// An IP path to a neighbour over a Wi-Fi Aware (NAN) data link.
///
/// Aware links carry link-local IPv6 only, so the address has to be dialled
/// with the interface as its scope. Dart hands scoped literals to the
/// platform resolver: the numeric interface index is understood everywhere,
/// the interface name only where the resolver knows it (Linux/Android).
class WifiAwarePath {
  final int peer;
  final String nyxId;

  /// True when the id came from a private beacon match (may be a Bloom
  /// false positive; the handshake decides).
  final bool isCandidate;
  final String address;
  final int port;
  final String iface;
  final int ifaceIndex;

  const WifiAwarePath({
    required this.peer,
    required this.nyxId,
    required this.isCandidate,
    required this.address,
    required this.port,
    required this.iface,
    required this.ifaceIndex,
  });

  bool get isLinkLocal => isLinkLocalIpv6(address);

  /// What to give `Socket.connect`.
  String get dialAddress {
    if (!isLinkLocal) return address;
    if (ifaceIndex > 0) return '$address%$ifaceIndex';
    if (iface.isNotEmpty) return '$address%$iface';
    return address;
  }

  /// fe80::/10
  static bool isLinkLocalIpv6(String address) {
    final a = address.toLowerCase();
    return a.startsWith('fe8') || a.startsWith('fe9') || a.startsWith('fea') || a.startsWith('feb');
  }

  @override
  String toString() => 'WifiAwarePath($nyxId at $dialAddress:$port)';
}

/// A neighbour seen over Aware whose beacon matched (a contact, or a public
/// handle), in either role.
class WifiAwarePeer {
  final int id;

  /// 'subscriber' when our subscriber found their publisher, 'publisher'
  /// when they asked our publisher for a link.
  final String role;
  Uint8List beacon;
  String? nyxId;
  bool isCandidate;
  bool pathRequested = false;
  WifiAwarePath? path;
  DateTime lastSeen = DateTime.now();

  WifiAwarePeer({required this.id, required this.role, required this.beacon, this.nyxId, this.isCandidate = false});
}

/// Wi-Fi Aware transport: publishes and subscribes the discovery beacon and
/// turns matched neighbours into IP paths for the authenticated TCP
/// handshake. Mirrors [BleManager]'s shape; the radio work is native.
/// See android/app/src/main/kotlin/com/nyxchat/nyxchat/WifiAwareChannel.kt.
class WifiAwareManager extends ChangeNotifier {
  static const MethodChannel _method = MethodChannel('nyxchat/wifi_aware');
  static const EventChannel _events = EventChannel('nyxchat/wifi_aware/events');

  bool _supported = false;
  bool _running = false;
  bool _available = false;
  bool _attached = false;
  String? _myNyxId;
  Uint8List _beacon = Uint8List(0);
  int _listeningPort = 0;
  String? _lastError;
  StreamSubscription? _sub;
  final Map<int, WifiAwarePeer> _peers = {};
  final Set<String> _pathAddresses = {};
  final StreamController<WifiAwarePath> _paths = StreamController.broadcast();

  /// Resolve a private beacon to candidate contact ids (set by PeerService).
  /// Nothing is asked of the radio for a beacon that resolves to nobody.
  Future<List<String>> Function(Uint8List bloom, int slot)? resolveBeacon;

  bool get isSupported => _supported;
  bool get isRunning => _running;
  bool get isAvailable => _available;
  bool get isAttached => _attached;
  String? get lastError => _lastError;
  Uint8List get beacon => _beacon;
  int get listeningPort => _listeningPort;

  /// Matched neighbours (contacts or public handles), with or without a path.
  List<WifiAwarePeer> get discoveredPeers => _peers.values.where((p) => p.nyxId != null).toList();
  List<WifiAwarePath> get paths => [for (final p in _peers.values) if (p.path != null) p.path!];
  int get nearbyCount => discoveredPeers.length;
  int get pathCount => paths.length;

  /// A data path came up: dial `connections.connect(path.dialAddress, path.port)`.
  Stream<WifiAwarePath> get onPeerPath => _paths.stream;

  String get statusText {
    if (!_supported) return 'Unsupported';
    if (!_running) return _lastError ?? 'Off';
    if (!_available) return 'Wi-Fi off';
    if (!_attached) return 'Attaching';
    final n = pathCount;
    return 'Active · $nearbyCount nearby · $n ${n == 1 ? 'path' : 'paths'}';
  }

  Future<void> init() async {
    try {
      _supported = await _method.invokeMethod<bool>('isSupported') ?? false;
    } catch (e) {
      debugPrint('[Aware] unsupported: $e');
      _supported = false;
    }
    notifyListeners();
  }

  /// Publish [beacon] (the same bytes as the BLE scan response) and
  /// subscribe. [listeningPort] is where our TCP server takes the handshake.
  Future<bool> start(String myNyxId, {required Uint8List beacon, required int listeningPort}) async {
    if (!_supported) return false;
    _myNyxId = myNyxId;
    _beacon = beacon;
    _listeningPort = listeningPort;
    _sub ??= _events.receiveBroadcastStream().listen(_onEvent, onError: (Object e) {
      debugPrint('[Aware] event error: $e');
    });
    try {
      final ok = await _method.invokeMethod<bool>('start', {'beacon': beacon, 'port': listeningPort}) ?? false;
      _running = ok;
      if (ok) {
        _lastError = null;
        _available = true; // until the first state event says otherwise
        _attached = false;
      }
      notifyListeners();
      return ok;
    } on PlatformException catch (e) {
      _lastError = switch (e.code) {
        'permission' => 'Needs the nearby-devices permission',
        'unsupported' => 'Unsupported',
        _ => e.message ?? e.code,
      };
      if (e.code == 'unsupported') _supported = false;
      debugPrint('[Aware] start failed: ${e.code} ${e.message}');
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = '$e';
      debugPrint('[Aware] start failed: $e');
      notifyListeners();
      return false;
    }
  }

  /// Rotate the published beacon (private beacons change every slot).
  Future<bool> updateBeacon(Uint8List beacon) async {
    _beacon = beacon;
    if (!_running) return false;
    try {
      return await _method.invokeMethod<bool>('updateBeacon', {'beacon': beacon}) ?? false;
    } catch (e) {
      debugPrint('[Aware] beacon update failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (_running) {
      try {
        await _method.invokeMethod('stop');
      } catch (_) {}
    }
    _running = false;
    _attached = false;
    _peers.clear();
    _pathAddresses.clear();
    await _sub?.cancel();
    _sub = null;
    notifyListeners();
  }
  /// Tear down one path (the TCP link above it closes on its own).
  Future<void> closePath(int peer) async {
    _forget(peer);
    try {
      await _method.invokeMethod('closePath', {'peer': peer});
    } catch (_) {}
    notifyListeners();
  }

  WifiAwarePath? pathForNyxId(String nyxId) {
    for (final p in _peers.values) {
      if (p.nyxId == nyxId && p.path != null) return p.path;
    }
    return null;
  }

  /// Whether a connection's remote address belongs to one of our Aware
  /// paths (so PeerService can tag the link 'aware').
  bool isAwareAddress(String address) => _pathAddresses.contains(_plain(address));

  static String _plain(String address) {
    var a = address.split('%').first.toLowerCase();
    if (a.startsWith('::ffff:') && a.contains('.')) a = a.substring(7);
    return a;
  }

  bool _hasPathTo(String nyxId) => pathForNyxId(nyxId) != null;

  // Events from the native side

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    switch (event['type']) {
      case 'state':
        _available = event['available'] == true;
        _attached = event['attached'] == true;
        notifyListeners();
      case 'discovered':
        final id = event['peer'];
        final beacon = event['beacon'];
        final role = event['role'];
        if (id is int && beacon is Uint8List) {
          unawaited(_onDiscovered(id, beacon, role is String ? role : 'subscriber'));
        }
      case 'path':
        _onPath(event);
      case 'lost':
        final id = event['peer'];
        if (id is int) {
          _forget(id);
          notifyListeners();
        }
      case 'error':
        _lastError = event['message']?.toString();
        debugPrint('[Aware] ${_lastError ?? 'error'}');
        notifyListeners();
    }
  }

  Future<void> _onDiscovered(int id, Uint8List bytes, String role) async {
    final mine = _myNyxId;
    if (mine == null || !_running) return;
    final beacon = DiscoveryBeacon.decodeBle(bytes);
    String? nyxId;
    var candidate = false;
    if (beacon != null && beacon.isPublic) {
      nyxId = beacon.nyxId;
    } else if (beacon != null && beacon.bloom != null) {
      final matches = await resolveBeacon?.call(beacon.bloom!, beacon.slot) ?? const <String>[];
      if (matches.isNotEmpty) {
        nyxId = matches.first;
        candidate = true;
      }
    }
    if (!_running) return;
    if (nyxId == null || nyxId == mine) {
      // A stranger (or our own beacon): no path, ever. A request that reached
      // our publisher is refused so the other side stops waiting.
      _peers.remove(id);
      if (role == 'publisher') {
        try {
          await _method.invokeMethod('closePath', {'peer': id});
        } catch (_) {}
      }
      return;
    }
    final peer = _peers[id] ??= WifiAwarePeer(id: id, role: role, beacon: bytes);
    peer
      ..beacon = bytes
      ..nyxId = nyxId
      ..isCandidate = candidate
      ..lastSeen = DateTime.now();
    notifyListeners();
    if (peer.pathRequested) return;
    // Both sides publish and subscribe, so both would find each other: only
    // the smaller handle asks for a link (the TCP dial rule, one layer down).
    // A request that reached our publisher is answered whoever is smaller.
    if (role != 'publisher' && (mine.compareTo(nyxId) > 0 || _hasPathTo(nyxId))) return;
    peer.pathRequested = true;
    try {
      final ok = await _method.invokeMethod<bool>('openPath', {'peer': id}) ?? false;
      if (!ok) peer.pathRequested = false;
    } catch (e) {
      debugPrint('[Aware] openPath failed: $e');
      peer.pathRequested = false;
    }
  }

  void _onPath(Map event) {
    final id = event['peer'];
    if (id is! int) return;
    final peer = _peers[id];
    if (peer == null || peer.nyxId == null) {
      // A path we never asked for.
      unawaited(closePath(id));
      return;
    }
    final path = WifiAwarePath(
      peer: id,
      nyxId: peer.nyxId!,
      isCandidate: peer.isCandidate,
      address: (event['address'] as String? ?? '').split('%').first,
      port: (event['port'] as num?)?.toInt() ?? 0,
      iface: event['iface'] as String? ?? '',
      ifaceIndex: (event['ifaceIndex'] as num?)?.toInt() ?? 0,
    );
    if (path.address.isEmpty || path.port <= 0) return;
    peer.path = path;
    _pathAddresses.add(_plain(path.address));
    debugPrint('[Aware] path to ${path.nyxId} via ${path.dialAddress}:${path.port}');
    notifyListeners();
    _paths.add(path);
  }

  void _forget(int id) {
    final peer = _peers.remove(id);
    final addr = peer?.path?.address;
    if (addr != null && !_peers.values.any((p) => p.path?.address == addr)) {
      _pathAddresses.remove(_plain(addr));
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    unawaited(_paths.close());
    super.dispose();
  }
}