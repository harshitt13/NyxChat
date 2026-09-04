import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';
import '../core/crypto/key_manager.dart';
import '../core/crypto/pair_keys.dart';
import '../core/mesh/mesh_packet.dart';
import '../core/mesh/mesh_router.dart';
import '../core/mesh/mesh_store.dart';
import '../core/network/ble_manager.dart';
import '../core/network/connection_manager.dart';
import '../core/network/dht_node.dart';
import '../core/network/discovery_beacon.dart';
import '../core/network/message_protocol.dart';
import '../core/network/p2p_client.dart';
import '../core/network/p2p_server.dart';
import '../core/network/peer_discovery.dart';
import '../core/network/wifi_direct_manager.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/trust_store.dart';
import '../models/peer.dart';
import 'background_service.dart';

/// Discovery and transport orchestration: private mDNS/BLE beacons,
/// authenticated TCP links through [ConnectionManager], the BLE/Wi-Fi
/// Direct mesh, and the experimental DHT.
class PeerService extends ChangeNotifier {
  final LocalStorage _storage;
  final P2PClient _client;
  final P2PServer _server;
  final BleManager _bleManager;
  final ConnectionManager _connections;
  final TrustStore _trust;
  final KeyManager _keys;
  final MeshStore _meshStore;
  final MeshRouter _meshRouter;
  final PairKeyCache _pairKeys;
  final WifiDirectManager _wifiDirect = WifiDirectManager();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  static const String _kDhtActive = 'dht_was_active';

  /// Whether to include our handle and name in beacons (anyone can find
  /// us) instead of contact-only private beacons.
  bool Function() isDiscoverableToEveryone = () => true;

  PeerDiscovery? _discovery;
  DHTNode? _dhtNode;
  DiscoveryMatcher? _matcher;
  final Map<String, Peer> _peers = {};
  final Map<String, DateTime> _lastDial = {};
  final List<StreamSubscription> _subs = [];
  Timer? _beaconTimer;
  int _bleBeaconSlot = -1;
  bool _networkActive = false;
  bool _dhtActive = false;
  bool _bleActive = false;
  bool _stealth = false;
  String _myId = '';
  String _myName = '';

  PeerService({
    required LocalStorage storage,
    required P2PClient client,
    required P2PServer server,
    required BleManager bleManager,
    required ConnectionManager connections,
    required TrustStore trust,
    required KeyManager keys,
    required MeshStore meshStore,
    required MeshRouter meshRouter,
    required PairKeyCache pairKeys,
  })  : _storage = storage,
        _client = client,
        _server = server,
        _bleManager = bleManager,
        _connections = connections,
        _trust = trust,
        _keys = keys,
        _meshStore = meshStore,
        _meshRouter = meshRouter,
        _pairKeys = pairKeys;

  Map<String, Peer> get peers => Map.unmodifiable(_peers);
  List<Peer> get peerList => _peers.values.toList();
  bool get isNetworkActive => _networkActive;
  bool get isDHTActive => _dhtActive;
  bool get isBleActive => _bleActive;
  bool get isBleSupported => _bleManager.isSupported;
  bool get isStealth => _stealth;
  BleManager get bleManager => _bleManager;
  MeshRouter get meshRouter => _meshRouter;
  MeshStore get meshStore => _meshStore;
  ConnectionManager get connections => _connections;
  P2PClient get client => _client;
  DHTNode? get dhtNode => _dhtNode;
  int get nearbyBleCount => _bleManager.nearbyCount;
  int get bleLinkCount => _bleManager.linkCount;
  int get wifiDirectPeerCount => _wifiDirect.getConnectedPeersCount();
  List<Peer> get connectedPeers => _peers.values.where((p) => isPeerConnected(p.nyxChatId)).toList();
  List<PinnedPeer> get knownContacts => _trust.all;

  /// Number of mesh neighbours over any transport.
  int get meshNeighbourCount => _bleManager.linkCount + _wifiDirect.getConnectedPeersCount();

  // Start / stop

  Future<void> startNetwork({required String nyxChatId, required String displayName}) async {
    if (_networkActive) return;
    _myId = nyxChatId;
    _myName = displayName;
    _matcher = DiscoveryMatcher(myId: nyxChatId, pairKeys: _pairKeys);
    for (final p in await _storage.getPeers()) {
      _peers[p.nyxChatId] = p;
    }

    _connections.configure(nyxChatId: nyxChatId, displayName: displayName, listeningPort: AppConstants.defaultPort);
    await _server.start();
    _connections.start();

    _subs.add(_connections.onPeerReady.listen((conn) {
      final hs = conn.handshake;
      if (hs == null) return;
      final existing = _peers[hs.peerId];
      _peers[hs.peerId] = Peer(
        nyxChatId: hs.peerId,
        displayName: hs.peerDisplayName,
        publicKeyHex: _hex(hs.peerIdentityKey),
        signingPublicKeyHex: _hex(hs.peerSigningKey),
        kyberPublicKeyHex: _hex(hs.peerKyberPublicKey),
        ipAddress: conn.remoteAddress,
        port: hs.peerListeningPort,
        status: PeerStatus.connected,
        lastSeen: DateTime.now(),
        firstSeen: existing?.firstSeen ?? DateTime.now(),
        transport: 'wifi',
      );
      _storage.savePeer(_peers[hs.peerId]!);
      notifyListeners();
    }));
    _subs.add(_client.onPeerDisconnected.listen((peerId) {
      final p = _peers[peerId];
      if (p != null) _peers[peerId] = p.copyWith(status: PeerStatus.disconnected, lastSeen: DateTime.now());
      notifyListeners();
    }));
    _subs.add(_trust.listenable());

    await _meshRouter.init(_myId);
    _wireMeshTransports();
    if (!_stealth) await _startDiscovery();
    _networkActive = true;
    notifyListeners();

    unawaited(_startBle());
    unawaited(_startWifiDirect());
    _beaconTimer?.cancel();
    _beaconTimer = Timer.periodic(const Duration(minutes: 1), (_) => _rotateBeacons());
  }

  // Beacons

  Future<DiscoveryBeacon> _beacon({int bits = DiscoveryBeacon.mdnsBloomBits}) async {
    if (isDiscoverableToEveryone()) return DiscoveryBeacon.public(_myId);
    final bloom = await _matcher!.buildPrivateBloom(bits: bits);
    return DiscoveryBeacon.private(bloom);
  }

  Future<void> _rotateBeacons() async {
    if (!_networkActive || _stealth) return;
    await _discovery?.refreshBeacon();
    final slot = PairKeys.discoverySlot();
    if (_bleActive && slot != _bleBeaconSlot) {
      _bleBeaconSlot = slot;
      final b = await _beacon(bits: DiscoveryBeacon.bleBloomBits);
      await _bleManager.updateBeacon(b.encodeBle());
    }
  }

  /// Visibility or contact list changed: re-publish immediately.
  Future<void> refreshBeacons() async {
    _bleBeaconSlot = -1;
    await _rotateBeacons();
  }

  Future<void> _startDiscovery() async {
    _discovery = PeerDiscovery(
      nyxChatId: _myId,
      listeningPort: AppConstants.defaultPort,
      beaconProvider: _beacon,
      displayNameProvider: () => _myName,
      resolvePrivate: (bloom, slot) => _matcher!.match(bloom, slot),
    );
    try {
      await _discovery!.startBroadcasting();
      await _discovery!.startDiscovery();
    } catch (e) {
      debugPrint('[Net] mDNS failed: $e');
    }
    _subs.add(_discovery!.onPeerFound.listen(_onDiscovered));
    _subs.add(_discovery!.onPeerLost.listen((peerId) {
      final p = _peers[peerId];
      if (p != null && !isPeerConnected(peerId)) {
        _peers[peerId] = p.copyWith(status: PeerStatus.disconnected);
        notifyListeners();
      }
    }));
  }

  Future<void> _onDiscovered(DiscoveredPeer d) async {
    if (d.nyxChatId == _myId) return;
    final name = _trust.get(d.nyxChatId)?.displayName ?? d.displayName;
    _peers.putIfAbsent(d.nyxChatId, () => Peer(
          nyxChatId: d.nyxChatId, displayName: name, publicKeyHex: '',
          ipAddress: d.ipAddress, port: d.port, status: PeerStatus.discovered, lastSeen: DateTime.now(),
        ));
    notifyListeners();
    await _dial(d.nyxChatId, d.ipAddress, d.port);
  }

  Future<bool> _dial(String peerId, String address, int port) async {
    if (isPeerConnected(peerId)) return true;
    if (_connections.pendingKeyChanges.containsKey(peerId)) return false;
    if (_myId.compareTo(peerId) > 0) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (isPeerConnected(peerId)) return true;
    }
    final last = _lastDial[peerId];
    if (last != null && DateTime.now().difference(last) < const Duration(seconds: 5)) return false;
    _lastDial[peerId] = DateTime.now();
    return await _connections.connect(address, port) != null;
  }

  Future<bool> connectToPeer({required String address, required int port}) async =>
      await _connections.connect(address, port) != null;

  Future<bool> connectToKnownPeer(String peerId) async {
    final p = _peers[peerId];
    if (p == null || p.ipAddress.isEmpty || p.ipAddress.startsWith('ble://')) return false;
    return _dial(peerId, p.ipAddress, p.port);
  }

  bool isPeerConnected(String peerId) => _client.isPeerConnected(peerId);
  bool isReachableByMesh(String peerId) => _bleManager.linkForNyxId(peerId) != null;
  // Mesh transports (BLE, Wi-Fi Direct, and TCP links that relay)

  void _wireMeshTransports() {
    _meshRouter.onForwardPacket = (packet, nextHopRelayId) {
      final bytes = packet.encode();
      if (nextHopRelayId != null) {
        final link = _bleManager.linkForRelayId(_hex(nextHopRelayId));
        if (link != null) {
          unawaited(_bleManager.sendBytes(link, bytes));
          return;
        }
      }
      unawaited(_bleManager.broadcastBytes(bytes));
      unawaited(_wifiDirect.broadcast(bytes));
      // Direct links relay too (bridges a LAN into a BLE neighbourhood).
      final frame = ProtocolMessage.meshPacket(packet);
      for (final id in _client.connectedPeerIds) {
        unawaited(_client.sendToPeer(id, frame));
      }
    };
    _bleManager.onMeshPacket = (link, bytes) => _ingest(bytes, 'ble ${link.address}');
    _wifiDirect.onPayloadReceived = (nyxId, bytes) => _ingest(bytes, 'wifi-direct $nyxId');
  }

  void _ingest(Uint8List bytes, String source) {
    try {
      unawaited(_meshRouter.handlePacket(MeshPacket.decode(bytes)));
    } catch (e) {
      debugPrint('[Mesh] bad packet from $source: $e');
    }
  }

  Future<void> _startBle() async {
    try {
      await _bleManager.init();
      if (!_bleManager.isSupported) return;
      _bleManager.resolveBeacon = (bloom, slot) => _matcher!.match(bloom, slot);
      _bleManager.onLinkUp = (link) async {
        final id = link.nyxId;
        if (id == null) return;
        _peers[id] = (_peers[id] ??
                Peer(nyxChatId: id, displayName: _trust.get(id)?.displayName ?? id, publicKeyHex: '',
                    ipAddress: 'ble://${link.address}', port: 0, lastSeen: DateTime.now()))
            .copyWith(status: PeerStatus.connected, lastSeen: DateTime.now(), transport: 'ble');
        notifyListeners();
        for (final packet in _meshRouter.getPacketsForNewPeer()) {
          await _bleManager.sendBytes(link, packet.encode());
        }
      };
      _bleManager.onLinkDown = (link) {
        final id = link.nyxId;
        if (id != null && _peers[id]?.transport == 'ble') {
          _peers[id] = _peers[id]!.copyWith(status: PeerStatus.disconnected);
        }
        notifyListeners();
      };
      if (!_stealth) await startBle();
    } catch (e) {
      debugPrint('[BLE] start error: $e');
    }
  }

  Future<void> startBle() async {
    if (_bleActive || !_bleManager.isSupported) return;
    final b = await _beacon(bits: DiscoveryBeacon.bleBloomBits);
    _bleBeaconSlot = b.slot;
    await _bleManager.start(_myId, relayIdHex: _meshRouter.relayIdHex, beacon: b.encodeBle());
    _bleActive = true;
    notifyListeners();
  }

  Future<void> stopBle() async {
    await _bleManager.stop();
    _bleActive = false;
    notifyListeners();
  }

  Future<void> _startWifiDirect() async {
    try {
      await _wifiDirect.init(_myId);
      if (!_stealth) {
        await _wifiDirect.startAdvertising();
        await _wifiDirect.startDiscovery();
      }
    } catch (e) {
      debugPrint('[Net] Wi-Fi Direct unavailable: $e');
    }
  }

  /// Stealth: no advertising, scanning or multicast of any kind.
  Future<void> setStealth(bool enabled) async {
    _stealth = enabled;
    if (enabled) {
      await _discovery?.stop();
      _discovery = null;
      await stopBle();
      try {
        await _wifiDirect.stop();
      } catch (_) {}
    } else if (_networkActive) {
      await _startDiscovery();
      await startBle();
      await _startWifiDirect();
    }
    notifyListeners();
  }

  // DHT

  Future<bool> wasDHTActive() async => (await _secure.read(key: _kDhtActive)) == 'true';

  Future<void> startDHT({List<String>? bootstrapNodes}) async {
    if (_dhtActive) return;
    try {
      _dhtNode = DHTNode(nodeId: _myId, port: AppConstants.defaultPort, keys: _keys, displayName: _myName, bootstrapNodes: bootstrapNodes);
      _dhtNode!.addListener(_updateDhtPeers);
      await _dhtNode!.start();
      _dhtActive = true;
      await _secure.write(key: _kDhtActive, value: 'true');
      await BackgroundManager.startService();
      notifyListeners();
    } catch (e) {
      debugPrint('[DHT] start failed: $e');
    }
  }

  Future<void> stopDHT() async {
    await _dhtNode?.stop();
    _dhtNode = null;
    _dhtActive = false;
    await _secure.write(key: _kDhtActive, value: 'false');
    await BackgroundManager.stopService();
    notifyListeners();
  }

  void addBootstrapNode(String address) => _dhtNode?.addBootstrapNode(address);

  Future<Peer?> lookupGlobalPeer(String targetId) async {
    final entry = await _dhtNode?.lookup(targetId);
    if (entry == null) return null;
    final peer = Peer(
      nyxChatId: entry.nodeId, displayName: entry.displayName, publicKeyHex: entry.identityKeyHex,
      signingPublicKeyHex: entry.signingKeyHex, kyberPublicKeyHex: entry.kyberKeyHex,
      ipAddress: entry.address, port: entry.port, status: PeerStatus.discovered, lastSeen: entry.lastSeen,
    );
    _peers[peer.nyxChatId] = peer;
    notifyListeners();
    return peer;
  }

  void _updateDhtPeers() {
    final node = _dhtNode;
    if (node == null) return;
    for (final e in node.knownPeers) {
      _peers.putIfAbsent(e.nodeId, () => Peer(
            nyxChatId: e.nodeId, displayName: e.displayName, publicKeyHex: e.identityKeyHex,
            ipAddress: e.address, port: e.port, status: PeerStatus.discovered, lastSeen: e.lastSeen,
          ));
    }
    notifyListeners();
  }

  Future<void> removePeer(String peerId) async {
    _peers.remove(peerId);
    await _storage.deletePeer(peerId);
    notifyListeners();
  }

  Future<void> stopNetwork() async {
    _beaconTimer?.cancel();
    await _discovery?.stop();
    _discovery = null;
    await stopDHT();
    await stopBle();
    try {
      await _wifiDirect.stop();
    } catch (_) {}
    await _connections.stop();
    await _client.disconnectAll();
    await _server.stop();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _networkActive = false;
    for (final e in _peers.entries.toList()) {
      _peers[e.key] = e.value.copyWith(status: PeerStatus.disconnected);
    }
    notifyListeners();
  }

  static String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

extension on TrustStore {
  /// Adapter so trust-store changes refresh beacons through the same
  /// subscription list as streams.
  StreamSubscription<void> listenable() {
    final controller = StreamController<void>();
    void onChange() => controller.add(null);
    addListener(onChange);
    controller.onCancel = () => removeListener(onChange);
    return controller.stream.listen((_) {});
  }
}