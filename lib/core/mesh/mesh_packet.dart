import 'dart:convert';
import 'package:flutter/foundation.dart';

/// A mesh packet that can be relayed through intermediate nodes.
///
/// Addressed by anonymous recipient hash (not plaintext IDs).
/// TTL decrements on each hop, packet is dropped when TTL reaches 0.
class MeshPacket {
  final String id;           // Unique packet ID for deduplication
  final String recipientHash; // SHA256 hash of recipient's ID
  final String senderHash;    // SHA256 hash of sender's ID (anonymous)
  final int ttl;              // Time-to-live (hops remaining)
  final int maxTtl;           // Original TTL
  final Uint8List payload;    // E2EE encrypted message bytes
  final DateTime timestamp;
  final String type;          // 'message', 'ack', 'mesh_hello'

  MeshPacket({
    required this.id,
    required this.recipientHash,
    required this.senderHash,
    required this.ttl,
    required this.maxTtl,
    required this.payload,
    required this.timestamp,
    this.type = 'message',
  });

  /// Create a new packet with decremented TTL for forwarding.
  MeshPacket forward() => MeshPacket(
    id: id,
    recipientHash: recipientHash,
    senderHash: senderHash,
    ttl: ttl - 1,
    maxTtl: maxTtl,
    payload: payload,
    timestamp: timestamp,
    type: type,
  );

  /// Check if this packet can still be forwarded.
  bool get canForward => ttl > 0;

  /// Check if this packet has expired (older than 24 hours).
  bool get isExpired =>
      DateTime.now().difference(timestamp).inHours > 24;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipientHash': recipientHash,
    'senderHash': senderHash,
    'ttl': ttl,
    'maxTtl': maxTtl,
    'payload': base64Encode(payload),
    'timestamp': timestamp.toIso8601String(),
    'type': type,
  };

  factory MeshPacket.fromJson(Map<String, dynamic> json) => MeshPacket(
    id: json['id'] as String,
    recipientHash: json['recipientHash'] as String,
    senderHash: json['senderHash'] as String,
    ttl: json['ttl'] as int,
    maxTtl: json['maxTtl'] as int,
    payload: base64Decode(json['payload'] as String),
    timestamp: DateTime.parse(json['timestamp'] as String),
    type: (json['type'] as String?) ?? 'message',
  );

  String encode() => jsonEncode(toJson());

  factory MeshPacket.decode(String data) =>
      MeshPacket.fromJson(jsonDecode(data) as Map<String, dynamic>);

  @override
  String toString() => 'MeshPacket($id, ttl:$ttl, to:${recipientHash.substring(0, 8)})';
}
