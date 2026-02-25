import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'mesh_packet.dart';

/// Persistent store for undelivered mesh packets.
///
/// Holds packets awaiting delivery when no path to recipient exists.
/// Packets are forwarded when new peers connect. Implements LRU
/// eviction and TTL-based expiry to prevent unbounded growth.
class MeshStore extends ChangeNotifier {
  final Map<String, MeshPacket> _packets = {};
  final Set<String> _deliveredIds = {};
  final int maxPackets;
  final Duration maxAge;

  MeshStore({
    this.maxPackets = 500,
    this.maxAge = const Duration(hours: 24),
  });

  int get packetCount => _packets.length;
  int get deliveredCount => _deliveredIds.length;

  /// Store a packet for later forwarding.
  /// Returns false if packet was already seen (dedup).
  bool store(MeshPacket packet) {
    if (_packets.containsKey(packet.id) || _deliveredIds.contains(packet.id)) {
      return false; // Already seen
    }

    if (packet.isExpired || !packet.canForward) {
      return false; // Expired or no hops left
    }

    // LRU eviction if at capacity
    if (_packets.length >= maxPackets) {
      _evictOldest();
    }

    _packets[packet.id] = packet;
    notifyListeners();
    return true;
  }

  /// Mark a packet as delivered (remove from store, add to delivered set).
  void markDelivered(String packetId) {
    _packets.remove(packetId);
    _deliveredIds.add(packetId);

    // Keep delivered set bounded
    if (_deliveredIds.length > maxPackets * 2) {
      final toRemove = _deliveredIds.take(_deliveredIds.length ~/ 2).toList();
      for (final id in toRemove) {
        _deliveredIds.remove(id);
      }
    }

    notifyListeners();
  }

  /// Check if a packet ID has been seen before (for dedup).
  bool hasSeen(String packetId) =>
      _packets.containsKey(packetId) || _deliveredIds.contains(packetId);

  /// Get all packets that should be forwarded to a new peer.
  /// Returns copies with decremented TTL.
  List<MeshPacket> getForwardable() {
    _cleanup();
    return _packets.values
        .where((p) => p.canForward && !p.isExpired)
        .map((p) => p.forward())
        .toList();
  }

  /// Get packets addressed to a specific recipient hash.
  List<MeshPacket> getForRecipient(String recipientHash) {
    return _packets.values
        .where((p) => p.recipientHash == recipientHash)
        .toList();
  }

  /// Remove expired and dead packets.
  void _cleanup() {
    final toRemove = <String>[];
    for (final entry in _packets.entries) {
      if (entry.value.isExpired || !entry.value.canForward) {
        toRemove.add(entry.key);
      }
    }
    for (final id in toRemove) {
      _packets.remove(id);
    }
    if (toRemove.isNotEmpty) notifyListeners();
  }

  /// Remove the oldest packet.
  void _evictOldest() {
    if (_packets.isEmpty) return;
    String? oldestId;
    DateTime? oldestTime;
    for (final entry in _packets.entries) {
      if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
        oldestId = entry.key;
        oldestTime = entry.value.timestamp;
      }
    }
    if (oldestId != null) _packets.remove(oldestId);
  }

  /// Serialize store to JSON for persistence.
  String serialize() {
    final data = _packets.values.map((p) => p.toJson()).toList();
    return jsonEncode(data);
  }

  /// Load store from serialized JSON.
  void deserialize(String json) {
    try {
      final list = jsonDecode(json) as List<dynamic>;
      for (final item in list) {
        final packet = MeshPacket.fromJson(item as Map<String, dynamic>);
        if (!packet.isExpired && packet.canForward) {
          _packets[packet.id] = packet;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[MeshStore] Deserialize error: $e');
    }
  }

  /// Clear all stored packets.
  void clear() {
    _packets.clear();
    _deliveredIds.clear();
    notifyListeners();
  }
}
