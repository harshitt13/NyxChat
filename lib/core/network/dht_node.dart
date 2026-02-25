import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'message_protocol.dart';

/// A simplified DHT (Distributed Hash Table) node for
/// global P2P peer discovery beyond the local network.
///
/// Each node maintains a routing table of known peers and
/// can look up peers by their BitChat ID. Peers are found
/// by forwarding lookup requests through the network.
class DHTNode extends ChangeNotifier {
  final String nodeId;
  final int port;
  final String publicKeyHex;
  final String displayName;

  ServerSocket? _server;
  final Map<String, DHTEntry> _routingTable = {};
  final List<String> _bootstrapNodes;
  final Map<String, Completer<DHTEntry?>> _pendingLookups = {};
  bool _isRunning = false;

  // K-bucket size (standard Kademlia)
  static const int kBucketSize = 20;
  static const int maxHops = 5;

  DHTNode({
    required this.nodeId,
    required this.port,
    required this.publicKeyHex,
    required this.displayName,
    List<String>? bootstrapNodes,
  }) : _bootstrapNodes = bootstrapNodes ?? [];

  bool get isRunning => _isRunning;
  int get knownPeersCount => _routingTable.length;
  List<DHTEntry> get knownPeers => _routingTable.values.toList();

  /// Start the DHT node
  Future<void> start() async {
    if (_isRunning) return;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port + 1);
      _isRunning = true;
      notifyListeners();

      _server!.listen(_handleConnection);
      debugPrint('[DHT] Node started on port ${port + 1}');

      // Announce self to bootstrap nodes
      await _announceToBootstrap();

      // Periodically refresh the routing table
      _startRefreshTimer();
    } catch (e) {
      debugPrint('[DHT] Failed to start: $e');
    }
  }

  /// Stop the DHT node
  Future<void> stop() async {
    _isRunning = false;
    await _server?.close();
    _server = null;
    notifyListeners();
    debugPrint('[DHT] Node stopped');
  }

  /// Add a bootstrap node address
  void addBootstrapNode(String address) {
    if (!_bootstrapNodes.contains(address)) {
      _bootstrapNodes.add(address);
    }
  }

  /// Announce self to the network
  Future<void> announce() async {
    final announcement = ProtocolMessage.dhtAnnounce(
      senderId: nodeId,
      publicKeyHex: publicKeyHex,
      displayName: displayName,
      address: '', // Will be filled by receiver
      port: port,
    );

    // Send to all known peers
    for (final entry in _routingTable.values) {
      try {
        await _sendToPeer(entry.address, entry.dhtPort, announcement);
      } catch (e) {
        debugPrint('[DHT] Failed to announce to ${entry.nodeId}: $e');
      }
    }

    // Send to bootstrap nodes
    await _announceToBootstrap();
  }

  /// Look up a peer by their BitChat ID
  Future<DHTEntry?> lookup(String targetId) async {
    // Check local routing table first
    if (_routingTable.containsKey(targetId)) {
      return _routingTable[targetId];
    }

    // Create a pending lookup
    final completer = Completer<DHTEntry?>();
    _pendingLookups[targetId] = completer;

    // Send lookup to closest known peers
    final lookupMsg = ProtocolMessage.dhtLookup(
      senderId: nodeId,
      targetId: targetId,
    );

    final closestPeers = _getClosestPeers(targetId, kBucketSize);
    for (final peer in closestPeers) {
      try {
        await _sendToPeer(peer.address, peer.dhtPort, lookupMsg);
      } catch (e) {
        debugPrint('[DHT] Lookup send failed to ${peer.nodeId}: $e');
      }
    }

    // Wait up to 10 seconds for response
    try {
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _pendingLookups.remove(targetId);
          return null;
        },
      );
    } catch (e) {
      return null;
    }
  }

  /// Store a peer entry in the routing table
  void storePeer(DHTEntry entry) {
    if (entry.nodeId == nodeId) return; // Don't store self
    _routingTable[entry.nodeId] = entry;
    notifyListeners();
    debugPrint('[DHT] Stored peer: ${entry.nodeId} at ${entry.address}:${entry.port}');
  }

  /// Handle incoming DHT connections
  void _handleConnection(Socket socket) {
    final remoteAddress = socket.remoteAddress.address;
    final buffer = StringBuffer();

    socket.listen(
      (data) {
        buffer.write(utf8.decode(data));
        final lines = buffer.toString().split('\n');
        buffer.clear();

        // Last element might be partial
        if (lines.last.isNotEmpty) {
          buffer.write(lines.last);
        }

        for (int i = 0; i < lines.length - 1; i++) {
          if (lines[i].trim().isNotEmpty) {
            _handleMessage(lines[i].trim(), remoteAddress, socket);
          }
        }
      },
      onDone: () => socket.destroy(),
      onError: (_) => socket.destroy(),
    );
  }

  /// Process incoming DHT messages
  void _handleMessage(String data, String remoteAddress, Socket socket) {
    try {
      final msg = ProtocolMessage.decode(data);

      switch (msg.type) {
        case ProtocolMessageType.dhtAnnounce:
          _handleAnnounce(msg, remoteAddress);
          break;
        case ProtocolMessageType.dhtLookup:
          _handleLookup(msg, remoteAddress, socket);
          break;
        case ProtocolMessageType.dhtResponse:
          _handleLookupResponse(msg);
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('[DHT] Error handling message: $e');
    }
  }

  /// Handle peer announcement
  void _handleAnnounce(ProtocolMessage msg, String remoteAddress) {
    final entry = DHTEntry(
      nodeId: msg.senderId,
      address: remoteAddress,
      port: msg.payload['port'] as int,
      dhtPort: (msg.payload['port'] as int) + 1,
      publicKeyHex: msg.payload['publicKeyHex'] as String,
      displayName: msg.payload['displayName'] as String,
      lastSeen: DateTime.now(),
    );
    storePeer(entry);
  }

  /// Handle peer lookup request
  void _handleLookup(
      ProtocolMessage msg, String remoteAddress, Socket socket) {
    final targetId = msg.payload['targetId'] as String;

    // Check if we know the target
    if (_routingTable.containsKey(targetId)) {
      final target = _routingTable[targetId]!;
      final response = ProtocolMessage.dhtResponse(
        senderId: nodeId,
        targetId: targetId,
        peers: [target.toJson()],
      );
      socket.write(response.encode());
    } else {
      // Send closest known peers
      final closest = _getClosestPeers(targetId, 3);
      final response = ProtocolMessage.dhtResponse(
        senderId: nodeId,
        targetId: targetId,
        peers: closest.map((p) => p.toJson()).toList(),
      );
      socket.write(response.encode());
    }
  }

  /// Handle lookup response
  void _handleLookupResponse(ProtocolMessage msg) {
    final targetId = msg.payload['targetId'] as String;
    final peers = (msg.payload['peers'] as List<dynamic>)
        .map((p) => DHTEntry.fromJson(p as Map<String, dynamic>))
        .toList();

    // Store all returned peers
    for (final peer in peers) {
      storePeer(peer);
    }

    // If we found the target, complete the lookup
    if (_pendingLookups.containsKey(targetId)) {
      final target = peers.where((p) => p.nodeId == targetId).firstOrNull;
      if (target != null) {
        _pendingLookups[targetId]?.complete(target);
        _pendingLookups.remove(targetId);
      }
    }
  }

  /// Send a message to a specific peer
  Future<void> _sendToPeer(
      String address, int port, ProtocolMessage msg) async {
    try {
      final socket = await Socket.connect(address, port,
          timeout: const Duration(seconds: 5));
      socket.write(msg.encode());
      await socket.flush();
      socket.destroy();
    } catch (e) {
      debugPrint('[DHT] Failed to send to $address:$port: $e');
    }
  }

  /// Announce to bootstrap nodes
  Future<void> _announceToBootstrap() async {
    final announcement = ProtocolMessage.dhtAnnounce(
      senderId: nodeId,
      publicKeyHex: publicKeyHex,
      displayName: displayName,
      address: '',
      port: port,
    );

    for (final node in _bootstrapNodes) {
      try {
        final parts = node.split(':');
        if (parts.length == 2) {
          await _sendToPeer(parts[0], int.parse(parts[1]), announcement);
        }
      } catch (e) {
        debugPrint('[DHT] Bootstrap announce failed for $node: $e');
      }
    }
  }

  /// Get closest peers to a target using XOR distance
  List<DHTEntry> _getClosestPeers(String targetId, int count) {
    final entries = _routingTable.values.toList();
    entries.sort((a, b) {
      final distA = _xorDistance(a.nodeId, targetId);
      final distB = _xorDistance(b.nodeId, targetId);
      return distA.compareTo(distB);
    });
    return entries.take(count).toList();
  }

  /// XOR distance between two node IDs (simplified)
  int _xorDistance(String id1, String id2) {
    int distance = 0;
    final len = min(id1.length, id2.length);
    for (int i = 0; i < len; i++) {
      distance += id1.codeUnitAt(i) ^ id2.codeUnitAt(i);
    }
    return distance;
  }

  /// Periodically refresh the routing table
  void _startRefreshTimer() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      announce();
    });
  }
}

/// Represents a peer entry in the DHT routing table
class DHTEntry {
  final String nodeId;
  final String address;
  final int port;
  final int dhtPort;
  final String publicKeyHex;
  final String displayName;
  final DateTime lastSeen;

  DHTEntry({
    required this.nodeId,
    required this.address,
    required this.port,
    required this.dhtPort,
    required this.publicKeyHex,
    required this.displayName,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'address': address,
    'port': port,
    'dhtPort': dhtPort,
    'publicKeyHex': publicKeyHex,
    'displayName': displayName,
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory DHTEntry.fromJson(Map<String, dynamic> json) => DHTEntry(
    nodeId: json['nodeId'] as String,
    address: json['address'] as String,
    port: json['port'] as int,
    dhtPort: json['dhtPort'] as int? ?? (json['port'] as int) + 1,
    publicKeyHex: json['publicKeyHex'] as String,
    displayName: json['displayName'] as String,
    lastSeen: json['lastSeen'] != null
        ? DateTime.parse(json['lastSeen'] as String)
        : DateTime.now(),
  );
}
