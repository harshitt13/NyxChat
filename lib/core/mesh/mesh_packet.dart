import 'dart:convert';
import 'dart:typed_data';

import '../crypto/crypto_utils.dart';

/// Store-and-forward mesh packet, protocol v4 (binary, sealed sender).
///
/// Relays see: a random packet id, a rotating recipient token, a rotating
/// reply token, hop counters, a timestamp, the per-launch random ids of the
/// relays it passed through, and an opaque payload sealed for the pair.
/// Nothing identifies the endpoints across epochs, and nothing can be
/// read, altered or re-addressed.
///
/// Layout (big-endian):
///   0      version (0x02)
///   1      type
///   2      ttl
///   3      maxTtl
///   4..11  timestamp, ms since epoch
///   12..27 packet id (16 random bytes)
///   28..43 recipient token (16 bytes; zeros for broadcast)
///   44..59 reply token (16 bytes; zeros if none)
///   60     route count n (<= 8)
///   61..   n x 8-byte relay ids
///   ...    payload
class MeshPacket {
  static const int version = 2;
  static const int headerBytes = 61;
  static const int tokenBytes = 16;
  static const int relayIdBytes = 8;
  static const int maxRoutePath = 8;
  static const int maxPayloadBytes = 64 * 1024;
  static const Duration maxAge = Duration(hours: 24);

  static const int typeMessage = 1;
  static const int typeAck = 2;
  static const int typeBeacon = 3;
  static const int typeChunk = 4;
  static const int typeChannel = 5;

  static final Uint8List zeroToken = Uint8List(tokenBytes);

  final Uint8List idBytes;
  final int type;
  final int ttl;
  final int maxTtl;
  final DateTime timestamp;
  final Uint8List to;
  final Uint8List replyTo;
  final List<Uint8List> routePath;
  final Uint8List payload;

  MeshPacket({
    required this.idBytes,
    required this.type,
    required this.ttl,
    required this.maxTtl,
    required this.timestamp,
    required this.to,
    required this.replyTo,
    required this.payload,
    this.routePath = const [],
  }) {
    if (idBytes.length != 16 || to.length != tokenBytes || replyTo.length != tokenBytes) {
      throw ArgumentError('bad mesh packet field sizes');
    }
  }

  factory MeshPacket.create({
    required int type,
    required Uint8List to,
    required Uint8List replyTo,
    required Uint8List payload,
    int ttl = 7,
  }) =>
      MeshPacket(
        idBytes: CryptoUtils.randomBytes(16),
        type: type,
        ttl: ttl,
        maxTtl: ttl,
        timestamp: DateTime.now().toUtc(),
        to: to,
        replyTo: replyTo,
        payload: payload,
      );

  String get id => CryptoUtils.toHex(idBytes);
  String get toHex => CryptoUtils.toHex(to);
  String get replyToHex => CryptoUtils.toHex(replyTo);
  bool get canForward => ttl > 0;
  bool get isExpired => DateTime.now().toUtc().difference(timestamp) > maxAge;
  int get hops => maxTtl - ttl;
  bool get isBroadcast => CryptoUtils.isAllZero(to);
  bool get hasReplyTo => !CryptoUtils.isAllZero(replyTo);
  Uint8List? get previousHop => routePath.isEmpty ? null : routePath.last;

  /// Copy with decremented TTL and our relay id appended.
  MeshPacket forward(Uint8List myRelayId) => MeshPacket(
        idBytes: idBytes,
        type: type,
        ttl: ttl - 1,
        maxTtl: maxTtl,
        timestamp: timestamp,
        to: to,
        replyTo: replyTo,
        payload: payload,
        routePath: routePath.length >= maxRoutePath
            ? routePath
            : [...routePath, myRelayId],
      );

  Uint8List encode() {
    final b = BytesBuilder(copy: false);
    b.add([version, type, ttl & 0xff, maxTtl & 0xff]);
    b.add(CryptoUtils.int64be(timestamp.millisecondsSinceEpoch));
    b.add(idBytes);
    b.add(to);
    b.add(replyTo);
    b.addByte(routePath.length);
    for (final r in routePath) {
      b.add(r.length == relayIdBytes ? r : Uint8List(relayIdBytes));
    }
    b.add(payload);
    return b.toBytes();
  }

  factory MeshPacket.decode(List<int> bytes) {
    if (bytes.length < headerBytes) throw const FormatException('mesh packet too short');
    if (bytes[0] != version) throw FormatException('unsupported mesh packet version ${bytes[0]}');
    final type = bytes[1];
    final ttl = bytes[2];
    final maxTtl = bytes[3];
    if (maxTtl < ttl || maxTtl > 32) throw const FormatException('bad ttl');
    var ts = 0;
    for (var i = 4; i < 12; i++) {
      ts = (ts << 8) | bytes[i];
    }
    if (ts <= 0) throw const FormatException('bad timestamp');
    final n = bytes[60];
    if (n > maxRoutePath) throw const FormatException('route too long');
    final routeEnd = headerBytes + n * relayIdBytes;
    if (bytes.length < routeEnd) throw const FormatException('truncated route');
    final route = <Uint8List>[
      for (var i = 0; i < n; i++)
        Uint8List.fromList(bytes.sublist(headerBytes + i * relayIdBytes, headerBytes + (i + 1) * relayIdBytes))
    ];
    final payload = Uint8List.fromList(bytes.sublist(routeEnd));
    if (payload.length > maxPayloadBytes) throw const FormatException('payload too large');
    return MeshPacket(
      idBytes: Uint8List.fromList(bytes.sublist(12, 28)),
      type: type,
      ttl: ttl,
      maxTtl: maxTtl,
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
      to: Uint8List.fromList(bytes.sublist(28, 44)),
      replyTo: Uint8List.fromList(bytes.sublist(44, 60)),
      routePath: route,
      payload: payload,
    );
  }

  /// JSON carrier used inside TCP frames: {"b": base64(binary)}.
  Map<String, dynamic> toJson() => {'b': base64Encode(encode())};

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    final b = json['b'];
    if (b is! String) throw const FormatException('mesh packet: missing bytes');
    return MeshPacket.decode(base64Decode(b));
  }

  @override
  String toString() => 'MeshPacket(${id.substring(0, 8)}, type:$type, ttl:$ttl)';
}