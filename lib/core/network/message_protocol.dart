import 'dart:convert';

import '../crypto/handshake.dart';
import '../mesh/mesh_packet.dart';
import '../protocol/envelope.dart';

/// Frame types on a direct (TCP / Wi-Fi Direct) link.
///
/// After the handshake every frame is sealed by the link [SecureChannel];
/// the only frames sent in the clear are the two hellos.
enum ProtocolMessageType {
  hello,
  envelope,
  fileChunk,
  ping,
  pong,
  disconnect,
  sessionReset,
  meshPacket,
  dhtAnnounce,
  dhtLookup,
  dhtResponse,
  unknown,
}

class ProtocolMessage {
  /// Hard cap on a single line on the wire (before link decryption).
  static const int maxFrameBytes = 1024 * 1024;

  final ProtocolMessageType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  ProtocolMessage({
    required this.type,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  factory ProtocolMessage.hello(HelloMessage hello) =>
      ProtocolMessage(type: ProtocolMessageType.hello, payload: hello.toJson());

  factory ProtocolMessage.envelope(Envelope envelope) => ProtocolMessage(
      type: ProtocolMessageType.envelope, payload: envelope.toJson());

  factory ProtocolMessage.fileChunk(Map<String, dynamic> chunkJson) =>
      ProtocolMessage(type: ProtocolMessageType.fileChunk, payload: chunkJson);

  factory ProtocolMessage.ping() =>
      ProtocolMessage(type: ProtocolMessageType.ping, payload: const {});

  factory ProtocolMessage.pong() =>
      ProtocolMessage(type: ProtocolMessageType.pong, payload: const {});

  factory ProtocolMessage.disconnect() =>
      ProtocolMessage(type: ProtocolMessageType.disconnect, payload: const {});

  /// Ask the peer to re-establish the pairwise ratchet from the current
  /// link handshake (sent after an undecryptable envelope).
  factory ProtocolMessage.sessionReset({required String reason}) =>
      ProtocolMessage(
          type: ProtocolMessageType.sessionReset, payload: {'reason': reason});

  factory ProtocolMessage.meshPacket(MeshPacket packet) => ProtocolMessage(
      type: ProtocolMessageType.meshPacket, payload: packet.toJson());

  // DHT frames carry their own sender id and signature because DHT
  // connections are short-lived and not handshaked.

  factory ProtocolMessage.dhtAnnounce({
    required String senderId,
    required String identityKeyHex,
    required String signingKeyHex,
    required String kyberKeyHex,
    required String displayName,
    required int port,
    required int issuedAtMs,
    required String signatureHex,
  }) =>
      ProtocolMessage(type: ProtocolMessageType.dhtAnnounce, payload: {
        'senderId': senderId,
        'ik': identityKeyHex,
        'sk': signingKeyHex,
        'kpk': kyberKeyHex,
        'displayName': displayName,
        'port': port,
        'iat': issuedAtMs,
        'sig': signatureHex,
      });

  factory ProtocolMessage.dhtLookup({
    required String senderId,
    required String targetId,
  }) =>
      ProtocolMessage(type: ProtocolMessageType.dhtLookup, payload: {
        'senderId': senderId,
        'targetId': targetId,
      });

  factory ProtocolMessage.dhtResponse({
    required String senderId,
    required String targetId,
    required List<Map<String, dynamic>> peers,
  }) =>
      ProtocolMessage(type: ProtocolMessageType.dhtResponse, payload: {
        'senderId': senderId,
        'targetId': targetId,
        'peers': peers,
      });

  // Typed accessors

  HelloMessage asHello() => HelloMessage.fromJson(payload);
  Envelope asEnvelope() => Envelope.fromJson(payload);
  MeshPacket asMeshPacket() => MeshPacket.fromJson(payload);

  // Serialisation

  Map<String, dynamic> toJson() => {
        't': type.name,
        'p': payload,
        'ts': timestamp.toIso8601String(),
      };

  factory ProtocolMessage.fromJson(Map<String, dynamic> json) {
    final t = json['t'];
    final p = json['p'];
    if (t is! String) throw const FormatException('frame: missing type');
    if (p is! Map<String, dynamic>) {
      throw const FormatException('frame: missing payload');
    }
    final type = ProtocolMessageType.values.firstWhere(
      (e) => e.name == t,
      orElse: () => ProtocolMessageType.unknown,
    );
    DateTime ts;
    try {
      ts = DateTime.parse(json['ts'] as String);
    } catch (_) {
      ts = DateTime.now().toUtc();
    }
    return ProtocolMessage(type: type, payload: p, timestamp: ts);
  }

  /// One frame = one line. The trailing newline is the delimiter.
  String encode() => '${jsonEncode(toJson())}\n';

  factory ProtocolMessage.decode(String line) {
    if (line.length > maxFrameBytes) {
      throw const FormatException('frame too large');
    }
    return ProtocolMessage.fromJson(
        jsonDecode(line.trim()) as Map<String, dynamic>);
  }

  @override
  String toString() => 'ProtocolMessage(${type.name})';
}