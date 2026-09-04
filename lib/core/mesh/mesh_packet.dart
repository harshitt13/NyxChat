import 'dart:convert';
import 'dart:typed_data';

/// A store-and-forward packet relayed hop by hop through the mesh.
///
/// Addressing uses SHA-256 hashes of NyxChat ids, so relays learn only
/// opaque identifiers. The payload is an end-to-end encrypted [Envelope];
/// relays cannot read, forge or re-address it (the envelope's associated
/// data binds sender and recipient).
class MeshPacket {
  static const int maxPayloadBytes = 64 * 1024;
  static const int maxRoutePath = 16;
  static const Duration maxAge = Duration(hours: 24);

  static const String typeMessage = 'message';
  static const String typeRouteDiscovery = 'route_discovery';

  final String id;
  final String recipientHash;
  final String senderHash;
  final int ttl;
  final int maxTtl;
  final Uint8List payload;
  final DateTime timestamp;
  final String type;
  final List<String> routePath;

  MeshPacket({
    required this.id,
    required this.recipientHash,
    required this.senderHash,
    required this.ttl,
    required this.maxTtl,
    required this.payload,
    required this.timestamp,
    this.type = typeMessage,
    this.routePath = const [],
  });

  /// Copy with decremented TTL and our hash appended to the route.
  MeshPacket forward(String myHash) => MeshPacket(
        id: id,
        recipientHash: recipientHash,
        senderHash: senderHash,
        ttl: ttl - 1,
        maxTtl: maxTtl,
        payload: payload,
        timestamp: timestamp,
        type: type,
        routePath: routePath.length >= maxRoutePath
            ? routePath
            : [...routePath, myHash],
      );

  bool get canForward => ttl > 0;
  bool get isExpired => DateTime.now().difference(timestamp) > maxAge;
  int get hops => maxTtl - ttl;
  bool get isBroadcast => type == typeRouteDiscovery;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipientHash': recipientHash,
        'senderHash': senderHash,
        'ttl': ttl,
        'maxTtl': maxTtl,
        'payload': base64Encode(payload),
        'timestamp': timestamp.toUtc().toIso8601String(),
        'type': type,
        'routePath': routePath,
      };

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final ttl = json['ttl'];
    final maxTtl = json['maxTtl'];
    if (id is! String || id.isEmpty || id.length > 64) {
      throw const FormatException('mesh packet: bad id');
    }
    if (ttl is! int || maxTtl is! int || ttl < 0 || maxTtl < ttl || maxTtl > 32) {
      throw const FormatException('mesh packet: bad ttl');
    }
    final payload = base64Decode(json['payload'] as String);
    if (payload.length > maxPayloadBytes) {
      throw const FormatException('mesh packet: payload too large');
    }
    final route = (json['routePath'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .take(maxRoutePath)
        .toList();
    return MeshPacket(
      id: id,
      recipientHash: json['recipientHash'] as String,
      senderHash: json['senderHash'] as String,
      ttl: ttl,
      maxTtl: maxTtl,
      payload: payload,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: (json['type'] as String?) ?? typeMessage,
      routePath: route,
    );
  }

  String encode() => jsonEncode(toJson());

  factory MeshPacket.decode(String data) =>
      MeshPacket.fromJson(jsonDecode(data) as Map<String, dynamic>);

  @override
  String toString() =>
      'MeshPacket(${id.substring(0, id.length < 8 ? id.length : 8)}, ttl:$ttl, type:$type)';
}