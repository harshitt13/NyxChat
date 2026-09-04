import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'mesh_packet.dart';

/// Bounded store for undelivered mesh packets plus a seen-id set for
/// de-duplication.
class MeshStore extends ChangeNotifier {
  final Map<String, MeshPacket> _packets = {};
  final Set<String> _delivered = {};
  final List<String> _seenOrder = [];
  final Set<String> _seen = {};
  final int maxPackets;
  final int maxSeen;

  MeshStore({this.maxPackets = 500, this.maxSeen = 5000});

  int get packetCount => _packets.length;
  int get deliveredCount => _delivered.length;
  int get seenCount => _seen.length;

  bool hasSeen(String id) => _seen.contains(id);

  void markSeen(String id) {
    if (_seen.add(id)) {
      _seenOrder.add(id);
      while (_seenOrder.length > maxSeen) {
        _seen.remove(_seenOrder.removeAt(0));
      }
    }
  }

  /// Store a packet for later forwarding. Returns false if already stored.
  bool store(MeshPacket packet) {
    if (_packets.containsKey(packet.id) || _delivered.contains(packet.id)) {
      return false;
    }
    if (packet.isExpired || !packet.canForward) return false;
    if (_packets.length >= maxPackets) _evictOldest();
    _packets[packet.id] = packet;
    markSeen(packet.id);
    notifyListeners();
    return true;
  }

  void markDelivered(String id) {
    _packets.remove(id);
    _delivered.add(id);
    if (_delivered.length > maxPackets * 2) {
      final drop = _delivered.take(_delivered.length ~/ 2).toList();
      _delivered.removeAll(drop);
    }
    notifyListeners();
  }

  List<MeshPacket> getForwardable(String myHash) {
    _cleanup();
    return _packets.values
        .where((p) => p.canForward && !p.isExpired)
        .map((p) => p.forward(myHash))
        .toList();
  }

  List<MeshPacket> getForRecipient(String recipientHash) =>
      _packets.values.where((p) => p.recipientHash == recipientHash).toList();

  void _cleanup() {
    final dead = _packets.entries
        .where((e) => e.value.isExpired || !e.value.canForward)
        .map((e) => e.key)
        .toList();
    for (final id in dead) {
      _packets.remove(id);
    }
    if (dead.isNotEmpty) notifyListeners();
  }

  void _evictOldest() {
    if (_packets.isEmpty) return;
    String? oldestId;
    DateTime? oldest;
    for (final e in _packets.entries) {
      if (oldest == null || e.value.timestamp.isBefore(oldest)) {
        oldestId = e.key;
        oldest = e.value.timestamp;
      }
    }
    if (oldestId != null) _packets.remove(oldestId);
  }

  String serialize() => jsonEncode(_packets.values.map((p) => p.toJson()).toList());

  void deserialize(String json) {
    try {
      for (final item in jsonDecode(json) as List<dynamic>) {
        final p = MeshPacket.fromJson(item as Map<String, dynamic>);
        if (!p.isExpired && p.canForward) {
          _packets[p.id] = p;
          markSeen(p.id);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[MeshStore] deserialize error: $e');
    }
  }

  void clear() {
    _packets.clear();
    _delivered.clear();
    _seen.clear();
    _seenOrder.clear();
    notifyListeners();
  }
}