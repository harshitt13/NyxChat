import 'dart:convert';
import 'dart:typed_data';

import 'parse.dart';

/// The plaintext that travels inside an end-to-end encrypted [Envelope].
///
/// Every user-visible or control payload (text, file descriptors,
/// reactions, receipts, group sender-key distribution, group membership
/// updates) is an InnerMessage. Transports never see these fields.
class InnerMessage {
  static const int maxEncodedBytes = 256 * 1024;

  static const String typeText = 'text';
  static const String typeFile = 'file';
  static const String typeReaction = 'reaction';
  static const String typeReceipt = 'receipt';
  static const String typeSenderKey = 'skdist';
  static const String typeGroupUpdate = 'group';
  static const String typeSessionOpen = 'open';
  static const String typeTyping = 'typing';

  final String type;
  final String id;
  final DateTime timestamp;
  final Map<String, dynamic> body;

  InnerMessage({
    required this.type,
    required this.id,
    required this.body,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  // Constructors for each payload kind

  factory InnerMessage.text({
    required String id,
    required String text,
    String? replyToId,
    int? disappearAfterSeconds,
    String? groupId,
  }) =>
      InnerMessage(type: typeText, id: id, body: {
        'text': text,
        'replyTo': ?replyToId,
        'ttl': ?disappearAfterSeconds,
        'groupId': ?groupId,
      });

  /// Describes a file whose encrypted chunks are sent separately.
  factory InnerMessage.file({
    required String id,
    required String fileId,
    required String fileName,
    required String mimeType,
    required int fileSize,
    required Uint8List fileKey,
    required Uint8List fileNonce,
    required int totalChunks,
    required int chunkSize,
    required String sha256Hex,
    String? groupId,
    String? caption,
  }) =>
      InnerMessage(type: typeFile, id: id, body: {
        'fileId': fileId,
        'name': fileName,
        'mime': mimeType,
        'size': fileSize,
        'key': base64Encode(fileKey),
        'nonce': base64Encode(fileNonce),
        'chunks': totalChunks,
        'chunkSize': chunkSize,
        'sha256': sha256Hex,
        'groupId': ?groupId,
        'caption': ?caption,
      });

  factory InnerMessage.reaction({
    required String id,
    required String targetMessageId,
    required String emoji,
    required bool remove,
    String? groupId,
  }) =>
      InnerMessage(type: typeReaction, id: id, body: {
        'target': targetMessageId,
        'emoji': emoji,
        'remove': remove,
        'groupId': ?groupId,
      });

  /// Delivery or read receipt for one or more message ids.
  factory InnerMessage.receipt({
    required String id,
    required List<String> messageIds,
    required String kind, // 'delivered' | 'read'
    String? groupId,
  }) =>
      InnerMessage(type: typeReceipt, id: id, body: {
        'ids': messageIds,
        'kind': kind,
        'groupId': ?groupId,
      });

  factory InnerMessage.senderKeyDistribution({
    required String id,
    required String groupId,
    required Map<String, dynamic> distribution,
  }) =>
      InnerMessage(type: typeSenderKey, id: id, body: {
        'groupId': groupId,
        'dist': distribution,
      });

  /// Group membership / metadata change. [action] is one of
  /// create, add, remove, leave, rename.
  factory InnerMessage.groupUpdate({
    required String id,
    required String groupId,
    required String action,
    required String groupName,
    required List<Map<String, dynamic>> members,
    String? description,
  }) =>
      InnerMessage(type: typeGroupUpdate, id: id, body: {
        'groupId': groupId,
        'action': action,
        'name': groupName,
        'members': members,
        'description': ?description,
      });

  factory InnerMessage.sessionOpen({required String id}) =>
      InnerMessage(type: typeSessionOpen, id: id, body: const {});

  factory InnerMessage.typing({required String id, required bool typing}) =>
      InnerMessage(type: typeTyping, id: id, body: {'typing': typing});

  // Accessors

  String? get groupId => body['groupId'] as String?;
  String get text => body['text'] as String? ?? '';

  // Serialisation

  Map<String, dynamic> toJson() => {
        't': type,
        'id': id,
        'ts': timestamp.toIso8601String(),
        'b': body,
      };

  factory InnerMessage.fromJson(Map<String, dynamic> json) => parseOr(() {
        const ctx = 'inner message';
        return InnerMessage(
          type: requireString(json, 't',
              minLength: 1, maxLength: 16, context: ctx),
          id: requireString(json, 'id',
              minLength: 1, maxLength: 64, context: ctx),
          timestamp: requireDateTime(json, 'ts', context: ctx),
          body: requireMap(json, 'b', context: ctx),
        );
      }, context: 'inner message');

  Uint8List toBytes() {
    final bytes = utf8.encode(jsonEncode(toJson()));
    if (bytes.length > maxEncodedBytes) {
      throw const FormatException('inner message too large');
    }
    return Uint8List.fromList(bytes);
  }

  factory InnerMessage.fromBytes(List<int> bytes) {
    if (bytes.length > maxEncodedBytes) {
      throw const FormatException('inner message too large');
    }
    return InnerMessage.fromJson(parseOr(
        () => decodeJsonObject(utf8.decode(bytes), context: 'inner message'),
        context: 'inner message'));
  }

  @override
  String toString() => 'InnerMessage($type, $id)';
}