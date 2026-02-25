import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../core/network/message_protocol.dart';
import '../core/network/p2p_client.dart';
import '../core/network/p2p_server.dart';
import '../core/network/peer_discovery.dart';
import '../core/network/dht_node.dart';
import '../core/network/ble_manager.dart';
import '../core/mesh/mesh_router.dart';
import '../core/mesh/mesh_store.dart';
import '../core/mesh/mesh_packet.dart';
import '../core/storage/local_storage.dart';
import '../models/peer.dart';

/// Manages peer discovery, connections, and network state.
/// Now includes DHT for global P2P discovery beyond local network.
class PeerService extends ChangeNotifier {
  final LocalStorage _storage;
  final P2PClient _client;
  final P2PServer _server;
  final BleManager _bleManager;
  final MeshStore _meshStore = MeshStore();
  late final MeshRouter _meshRouter;

  PeerDiscovery? _discovery;
  DHTNode? _dhtNode;
  final Map<String, Peer> _peers = {};
  bool _isNetworkActive = false;
  bool _isDHTActive = false;
  bool _isBleActive = false;

  PeerService({
    required LocalStorage storage,
    required P2PClient client,
    required P2PServer server,
    required BleManager bleManager,
  })  : _storage = storage,
        _client = client,
        _server = server,
        _bleManager = bleManager {
    _meshRouter = MeshRouter(store: _meshStore);
  }

  Map<String, Peer> get peers => Map.unmodifiable(_peers);
  List<Peer> get peerList => _peers.values.toList();
  bool get isNetworkActive => _isNetworkActive;
  bool get isDHTActive => _isDHTActive;
  bool get isBleActive => _isBleActive;
  bool get isBleSupported => _bleManager.isSupported;
  BleManager get bleManager => _bleManager;
  MeshRouter get meshRouter => _meshRouter;
  MeshStore get meshStore => _meshStore;
  P2PClient get client => _client;
  P2PServer get server => _server;
  DHTNode? get dhtNode => _dhtNode;
  int get nearbyBleCount => _bleManager.nearbyCount;

  /// Get list of connected peers (for group chat member selection)
  List<Peer> get connectedPeers =>
      _peers.values.where((p) => isPeerConnected(p.bitChatId)).toList();

  // ─── Network Start/Stop ───────────────────────────────────────

  Future<void> startNetwork({
    required String bitChatId,
    required String displayName,
    required String publicKeyHex,
    required String signingPublicKeyHex,
  }) async {
    // Load saved peers
    final savedPeers = await _storage.getPeers();
    for (final peer in savedPeers) {
      _peers[peer.bitChatId] = peer;
    }

    // Start P2P server
    await _server.start();

    _server.onNewConnection.listen((connection) {
      _handleIncomingConnection(connection, bitChatId, displayName,
          publicKeyHex, signingPublicKeyHex);
    });

    // Start mDNS peer discovery (local)
    _discovery = PeerDiscovery(
      bitChatId: bitChatId,
      displayName: displayName,
      listeningPort: AppConstants.defaultPort,
    );

    await _discovery!.startBroadcasting();
    await _discovery!.startDiscovery();

    _discovery!.onPeerFound.listen((discovered) {
      _handlePeerDiscovered(discovered, bitChatId, displayName,
          publicKeyHex, signingPublicKeyHex);
    });

    _discovery!.onPeerLost.listen((peerId) {
      _handlePeerLost(peerId);
    });

    _isNetworkActive = true;
    notifyListeners();
    debugPrint('[Network] Local network started');

    // Start BLE mesh (non-blocking, best-effort)
    _startBle(bitChatId);
  }

  // ─── BLE Mesh ────────────────────────────────────────────────

  Future<void> _startBle(String bitChatId) async {
    try {
      await _bleManager.init();
      if (!_bleManager.isSupported) {
        debugPrint('[BLE] Not supported, skipping');
        return;
      }

      // Init mesh router
      await _meshRouter.init(bitChatId);

      // Forward mesh packets via BLE broadcast
      _meshRouter.onForwardPacket = (packet) {
        _bleManager.broadcast({
          'type': 'mesh_packet',
          'packet': packet.toJson(),
        });
      };

      // Handle incoming BLE messages for mesh routing
      _bleManager.onMessageReceived = (blePeer, message) {
        if (message['type'] == 'mesh_packet' && message['packet'] != null) {
          final packet = MeshPacket.fromJson(
              message['packet'] as Map<String, dynamic>);
          _meshRouter.handlePacket(packet);
        }
      };

      // Register BLE peer events
      _bleManager.onPeerConnected = (blePeer) {
        if (blePeer.nyxId != null) {
          final peer = Peer(
            bitChatId: blePeer.nyxId!,
            displayName: blePeer.deviceName,
            publicKeyHex: '',
            ipAddress: 'ble://${blePeer.deviceId}',
            port: 0,
            status: PeerStatus.connected,
            lastSeen: DateTime.now(),
            transport: 'ble',
          );
          _peers[peer.bitChatId] = peer;
          _storage.savePeer(peer);
          notifyListeners();

          // Exchange stored mesh packets with new peer
          final packets = _meshRouter.getPacketsForNewPeer();
          for (final packet in packets) {
            _bleManager.sendMessage(blePeer, {
              'type': 'mesh_packet',
              'packet': packet.toJson(),
            });
          }
        }
      };

      _bleManager.onPeerDisconnected = (blePeer) {
        if (blePeer.nyxId != null && _peers.containsKey(blePeer.nyxId)) {
          _peers[blePeer.nyxId!] = _peers[blePeer.nyxId!]!
              .copyWith(status: PeerStatus.disconnected);
          notifyListeners();
        }
      };

      await _bleManager.start(bitChatId);
      _isBleActive = true;
      notifyListeners();
      debugPrint('[BLE] Mesh started');
    } catch (e) {
      debugPrint('[BLE] Start error: $e');
    }
  }

  Future<void> stopBle() async {
    await _bleManager.stop();
    _isBleActive = false;
    notifyListeners();
  }

  // ─── DHT Global Network ──────────────────────────────────────

  /// Start the DHT node for global P2P discovery
  Future<void> startDHT({
    required String bitChatId,
    required String publicKeyHex,
    required String displayName,
    List<String>? bootstrapNodes,
  }) async {
    try {
      _dhtNode = DHTNode(
        nodeId: bitChatId,
        port: AppConstants.defaultPort,
        publicKeyHex: publicKeyHex,
        displayName: displayName,
        bootstrapNodes: bootstrapNodes,
      );

      await _dhtNode!.start();
      _isDHTActive = true;

      // Listen for DHT peer updates
      _dhtNode!.addListener(() {
        _updateDHTPeers();
      });

      // Announce ourselves
      await _dhtNode!.announce();

      notifyListeners();
      debugPrint('[DHT] Global network started');
    } catch (e) {
      debugPrint('[DHT] Failed to start: $e');
    }
  }

  /// Stop the DHT node
  Future<void> stopDHT() async {
    await _dhtNode?.stop();
    _dhtNode = null;
    _isDHTActive = false;
    notifyListeners();
  }

  /// Look up a peer globally via DHT
  Future<Peer?> lookupGlobalPeer(String targetId) async {
    if (_dhtNode == null) return null;

    final entry = await _dhtNode!.lookup(targetId);
    if (entry != null) {
      final peer = Peer(
        bitChatId: entry.nodeId,
        displayName: entry.displayName,
        publicKeyHex: entry.publicKeyHex,
        ipAddress: entry.address,
        port: entry.port,
        status: PeerStatus.discovered,
        lastSeen: entry.lastSeen,
        firstSeen: entry.lastSeen,
      );
      _peers[peer.bitChatId] = peer;
      notifyListeners();
      return peer;
    }
    return null;
  }

  /// Add a DHT bootstrap node
  void addBootstrapNode(String address) {
    _dhtNode?.addBootstrapNode(address);
  }

  void _updateDHTPeers() {
    if (_dhtNode == null) return;
    for (final entry in _dhtNode!.knownPeers) {
      if (!_peers.containsKey(entry.nodeId)) {
        _peers[entry.nodeId] = Peer(
          bitChatId: entry.nodeId,
          displayName: entry.displayName,
          publicKeyHex: entry.publicKeyHex,
          ipAddress: entry.address,
          port: entry.port,
          status: PeerStatus.discovered,
          lastSeen: entry.lastSeen,
          firstSeen: entry.lastSeen,
        );
      }
    }
    notifyListeners();
  }

  // ─── Connection Handling ──────────────────────────────────────

  void _handleIncomingConnection(
    PeerConnection connection,
    String myBitChatId,
    String myDisplayName,
    String myPublicKeyHex,
    String mySigningPublicKeyHex,
  ) {
    late StreamSubscription sub;
    sub = connection.onMessage.listen((msg) {
      if (msg.type == ProtocolMessageType.hello) {
        connection.send(ProtocolMessage.hello(
          senderId: myBitChatId,
          displayName: myDisplayName,
          publicKeyHex: myPublicKeyHex,
          signingPublicKeyHex: mySigningPublicKeyHex,
          listeningPort: AppConstants.defaultPort,
        ));

        _client.registerIncomingConnection(connection);

        final peer = Peer(
          bitChatId: msg.senderId,
          displayName:
              msg.payload['displayName'] as String? ?? 'Unknown',
          publicKeyHex:
              msg.payload['publicKeyHex'] as String? ?? '',
          ipAddress: connection.remoteAddress,
          port: msg.payload['listeningPort'] as int? ??
              AppConstants.defaultPort,
          status: PeerStatus.connected,
          lastSeen: DateTime.now(),
          firstSeen: DateTime.now(),
        );

        _peers[peer.bitChatId] = peer;
        _storage.savePeer(peer);
        notifyListeners();

        sub.cancel();
      }
    });
  }

  Future<void> _handlePeerDiscovered(
    DiscoveredPeer discovered,
    String myBitChatId,
    String myDisplayName,
    String myPublicKeyHex,
    String mySigningPublicKeyHex,
  ) async {
    if (_client.isPeerConnected(discovered.bitChatId)) return;

    try {
      final hello = ProtocolMessage.hello(
        senderId: myBitChatId,
        displayName: myDisplayName,
        publicKeyHex: myPublicKeyHex,
        signingPublicKeyHex: mySigningPublicKeyHex,
        listeningPort: AppConstants.defaultPort,
      );

      final connection = await _client.connectToPeer(
        address: discovered.ipAddress,
        port: discovered.port,
        helloMessage: hello,
      );

      final peer = Peer(
        bitChatId: discovered.bitChatId,
        displayName:
            connection.peerDisplayName ?? discovered.displayName,
        publicKeyHex: connection.peerPublicKeyHex ?? '',
        ipAddress: discovered.ipAddress,
        port: discovered.port,
        status: PeerStatus.connected,
        lastSeen: DateTime.now(),
        firstSeen: DateTime.now(),
      );

      _peers[peer.bitChatId] = peer;
      await _storage.savePeer(peer);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to connect to discovered peer: $e');

      final peer = Peer(
        bitChatId: discovered.bitChatId,
        displayName: discovered.displayName,
        publicKeyHex: '',
        ipAddress: discovered.ipAddress,
        port: discovered.port,
        status: PeerStatus.discovered,
        lastSeen: DateTime.now(),
      );
      _peers[peer.bitChatId] = peer;
      notifyListeners();
    }
  }

  void _handlePeerLost(String peerId) {
    final peer = _peers[peerId];
    if (peer != null) {
      _peers[peerId] = peer.copyWith(status: PeerStatus.disconnected);
      notifyListeners();
    }
  }

  /// Connect to a specific peer manually
  Future<bool> connectToPeer({
    required String address,
    required int port,
    required String myBitChatId,
    required String myDisplayName,
    required String myPublicKeyHex,
    required String mySigningPublicKeyHex,
  }) async {
    try {
      final hello = ProtocolMessage.hello(
        senderId: myBitChatId,
        displayName: myDisplayName,
        publicKeyHex: myPublicKeyHex,
        signingPublicKeyHex: mySigningPublicKeyHex,
        listeningPort: AppConstants.defaultPort,
      );

      await _client.connectToPeer(
        address: address,
        port: port,
        helloMessage: hello,
      );
      return true;
    } catch (e) {
      debugPrint('Manual connection failed: $e');
      return false;
    }
  }

  /// Connect to a DHT-discovered peer
  Future<bool> connectToDHTPeer({
    required String peerId,
    required String myBitChatId,
    required String myDisplayName,
    required String myPublicKeyHex,
    required String mySigningPublicKeyHex,
  }) async {
    final peer = _peers[peerId];
    if (peer == null) return false;

    return connectToPeer(
      address: peer.ipAddress,
      port: peer.port,
      myBitChatId: myBitChatId,
      myDisplayName: myDisplayName,
      myPublicKeyHex: myPublicKeyHex,
      mySigningPublicKeyHex: mySigningPublicKeyHex,
    );
  }

  bool isPeerConnected(String peerId) => _client.isPeerConnected(peerId);

  PeerConnection? getConnection(String peerId) =>
      _client.getConnection(peerId);

  Future<void> stopNetwork() async {
    await _discovery?.stop();
    await stopDHT();
    await stopBle();
    await _client.disconnectAll();
    await _server.stop();
    _isNetworkActive = false;

    for (final entry in _peers.entries) {
      _peers[entry.key] =
          entry.value.copyWith(status: PeerStatus.disconnected);
    }

    notifyListeners();
    debugPrint('[Network] All networks stopped');
  }
}
