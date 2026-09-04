import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';
import '../core/crypto/key_manager.dart';
import '../core/mesh/mesh_packet.dart';
import '../core/mesh/mesh_router.dart';
import '../core/mesh/mesh_store.dart';
import '../core/network/ble_manager.dart';
import '../core/network/connection_manager.dart';
import '../core/network/dht_node.dart';
import '../core/network/p2p_client.dart';
import '../core/network/p2p_server.dart';
import '../core/network/peer_discovery.dart';
import '../core/network/wifi_direct_manager.dart';
import '../core/storage/local_storage.dart';
import '../core/storage/trust_store.dart';
import '../models/peer.dart';
import 'background_service.dart';

/// Discovery and transport orchestration: mDNS on the LAN, BLE mesh
/// nearby, DHT for wide-area lookups. All direct links go through
/// [ConnectionManager], which authenticates them.
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
  final WifiDirectManager _wifiDirect = WifiDirectManager();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  static const String _kDhtActive = 'dht_was_active';

  PeerDiscovery? _discovery;
  DHTNode? _dhtNode;
  final Map<String, Peer> _peers = {};
  final Map<String, DateTime> _lastDial = {};
  final List<StreamSubscription> _subs = [];
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
  })  : _storage = storage,
        _client = client,
        _server = server,
        _bleManager = bleManager,
        _connections = connections,
        _trust = trust,
        _keys = keys,
        _meshStore = meshStore,
        _meshRouter = meshRouter;

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
  List<Peer> get connectedPeers =>
      _peers.values.where((p) => isPeerConnected(p.nyxChatId)).toList();
  List<PinnedPeer> get knownContacts => _trust.all;

  // Start / stop

  Future<void> startNetwork({
    required String nyxChatId,
    required String displayName,
  }) async {
    if (_networkActive) return;
    _myId = nyxChatId;
    _myName = displayName;
    for (final p in await _storage.getPeers()) {
      _peers[p.nyxChatId] = p;
    }

    _connections.configure(
      nyxChatId: nyxChatId,
      displayName: displayName,
      listeningPort: AppConstants.defaultPort,
    );
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
      if (p != null) {
        _peers[peerId] = p.copyWith(status: PeerStatus.disconnected, lastSeen: DateTime.now());
      }
      notifyListeners();
    }));

    if (!_stealth) await _startDiscovery();
    _networkActive = true;
    notifyListeners();

    unawaited(_startBle());
    unawaited(_startWifiDirect());
  }

  Future<void> _startDiscovery() async {
    _discovery = PeerDiscovery(
      nyxChatId: _myId,
      displayName: _myName,
      listeningPort: AppConstants.defaultPort,
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

  Future<void> _onDiscovered(DiscoveredPeer d) async {
    if (d.nyxChatId == _myId) return;
    _peers.putIfAbsent(d.nyxChatId, () => Peer(
          nyxChatId: d.nyxChatId,
          displayName: d.displayName,
          publicKeyHex: '',
          ipAddress: d.ipAddress,
          port: d.port,
          status: PeerStatus.discovered,
          lastSeen: DateTime.now(),
        ));
    notifyListeners();
    await _dial(d.nyxChatId, d.ipAddress, d.port);
  }

  Future<bool> _dial(String peerId, String address, int port) async {
    if (isPeerConnected(peerId)) return true;
    if (_connections.pendingKeyChanges.containsKey(peerId)) return false;
    // Both sides discover each other; only the smaller id dials first to
    // avoid two simultaneous links. The other side dials after a delay if
    // still not connected.
    if (_myId.compareTo(peerId) > 0) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (isPeerConnected(peerId)) return true;
    }
    final last = _lastDial[peerId];
    if (last != null && DateTime.now().difference(last) < const Duration(seconds: 5)) {
      return false;
    }
    _lastDial[peerId] = DateTime.now();
    final conn = await _connections.connect(address, port);
    return conn != null;
  }

  /// Manual connection by address.
  Future<bool> connectToPeer({required String address, required int port}) async {
    final conn = await _connections.connect(address, port);
    return conn != null;
  }

  Future<bool> connectToKnownPeer(String peerId) async {
    final p = _peers[peerId];
    if (p == null || p.ipAddress.isEmpty || p.ipAddress.startsWith('ble://')) return false;
    return _dial(peerId, p.ipAddress, p.port);
  }

  bool isPeerConnected(String peerId) => _client.isPeerConnected(peerId);
  bool isReachableByMesh(String peerId) => _bleManager.linkForNyxId(peerId) != null;

  // BLE mesh

  Future<void> _startBle() async {
    try {
      await _bleManager.init();
      if (!_bleManager.isSupported) return;
      await _meshRouter.init(_myId);

      _meshRouter.onForwardPacket = (packet, nextHopHash) {
        final frame = {'type': 'mesh', 'packet': packet.toJson()};
        if (nextHopHash != null) {
          final link = _linkForHash(nextHopHash);
          if (link != null) {
            unawaited(_bleManager.sendJson(link, frame));
            return;
          }
        }
        unawaited(_bleManager.broadcastJson(frame));
      };

      _bleManager.onMessage = (link, message) {
        if (message['type'] == 'mesh' && message['packet'] is Map) {
          try {
            final packet = MeshPacket.fromJson(
                (message['packet'] as Map).cast<String, dynamic>());
            unawaited(_meshRouter.handlePacket(packet));
          } catch (e) {
            debugPrint('[Mesh] bad packet from ${link.address}: $e');
          }
        }
      };

      _bleManager.onLinkUp = (link) async {
        final id = link.nyxId;
        if (id == null) return;
        _peers[id] = (_peers[id] ??
                Peer(nyxChatId: id, displayName: _trust.get(id)?.displayName ?? id,
                    publicKeyHex: '', ipAddress: 'ble://${link.address}', port: 0,
                    lastSeen: DateTime.now()))
            .copyWith(status: PeerStatus.connected, lastSeen: DateTime.now(), transport: 'ble');
        _hashCache[await MeshRouter.hashId(id)] = id;
        notifyListeners();
        for (final packet in _meshRouter.getPacketsForNewPeer()) {
          await _bleManager.sendJson(link, {'type': 'mesh', 'packet': packet.toJson()});
        }
      };
      _bleManager.onLinkDown = (link) {
        final id = link.nyxId;
        if (id != null && _peers[id]?.transport == 'ble') {
          _peers[id] = _peers[id]!.copyWith(status: PeerStatus.disconnected);
        }
        notifyListeners();
      };

      if (!_stealth) {
        await _bleManager.start(_myId);
        _bleActive = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[BLE] start error: $e');
    }
  }

  final Map<String, String> _hashCache = {};

  BleLink? _linkForHash(String hash) {
    final id = _hashCache[hash];
    return id == null ? null : _bleManager.linkForNyxId(id);
  }

  Future<void> stopBle() async {
    await _bleManager.stop();
    _bleActive = false;
    notifyListeners();
  }

  Future<void> startBle() async {
    if (_bleActive || !_bleManager.isSupported) return;
    await _bleManager.start(_myId);
    _bleActive = true;
    notifyListeners();
  }

  /// Stealth: no advertising or scanning of any kind; existing links stay.
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
      _dhtNode = DHTNode(
        nodeId: _myId,
        port: AppConstants.defaultPort,
        keys: _keys,
        displayName: _myName,
        bootstrapNodes: bootstrapNodes,
      );
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
      nyxChatId: entry.nodeId,
      displayName: entry.displayName,
      publicKeyHex: entry.identityKeyHex,
      signingPublicKeyHex: entry.signingKeyHex,
      kyberPublicKeyHex: entry.kyberKeyHex,
      ipAddress: entry.address,
      port: entry.port,
      status: PeerStatus.discovered,
      lastSeen: entry.lastSeen,
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
            nyxChatId: e.nodeId,
            displayName: e.displayName,
            publicKeyHex: e.identityKeyHex,
            ipAddress: e.address,
            port: e.port,
            status: PeerStatus.discovered,
            lastSeen: e.lastSeen,
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

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}