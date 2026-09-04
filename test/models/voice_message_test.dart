// Voice-note message model: JSON round trip through the Hive encoding,
// metadata handling, and the wire hints inside a file descriptor.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyxchat/core/media/media_metadata.dart';
import 'package:nyxchat/core/network/file_transfer_manager.dart';
import 'package:nyxchat/core/protocol/inner_message.dart';
import 'package:nyxchat/core/protocol/padding.dart';
import 'package:nyxchat/models/message.dart';

ChatMessage voiceNote({Map<String, dynamic>? metadata}) => ChatMessage(
      id: 'v1',
      senderId: 'NC-A',
      receiverId: 'NC-B',
      content: 'voice_1700000000.m4a',
      timestamp: DateTime.utc(2026, 9, 5, 12, 30),
      status: MessageStatus.sent,
      roomId: 'room-1',
      messageType: MessageType.voice,
      metadata: metadata ?? const {'durationMs': 12340, 'voice': true},
      attachment: FileAttachment(
        fileName: 'voice_1700000000.m4a',
        mimeType: 'audio/mp4',
        fileSize: 49_152,
        filePath: '/data/files/voice_1700000000.m4a',
        fileId: 'v1',
        sha256Hex: 'b' * 64,
        totalChunks: 2,
        receivedChunks: 2,
      ),
    );

void main() {
  group('ChatMessage voice', () {
    test('survives the JSON round trip used by storage', () {
      final m = voiceNote();
      final back = ChatMessage.decode(m.encode());
      expect(back.messageType, MessageType.voice);
      expect(back.isVoice, isTrue);
      expect(back.voiceDuration, const Duration(seconds: 12, milliseconds: 340));
      expect(back.metadata, {'durationMs': 12340, 'voice': true});
      expect(back.attachment!.mimeType, 'audio/mp4');
      expect(back.attachment!.isAudio, isTrue);
      expect(back.attachment!.isImage, isFalse);
      expect(back.attachment!.isComplete, isTrue);
      expect(back.content, m.content);
      expect(back.timestamp, m.timestamp);
      expect(back, m, reason: 'identity is the id');
    });

    test('metadata is omitted from JSON when empty and defaults to empty', () {
      final plain = ChatMessage(
          id: 't1', senderId: 'a', receiverId: 'b', content: 'hi', timestamp: DateTime.now());
      expect(plain.toJson().containsKey('metadata'), isFalse);
      expect(plain.metadata, isEmpty);
      expect(plain.isVoice, isFalse);
      expect(plain.voiceDuration, isNull);
      final json = plain.toJson()..remove('metadata');
      expect(ChatMessage.fromJson(json).metadata, isEmpty);
    });

    test('copyWith keeps and replaces metadata', () {
      final m = voiceNote();
      expect(m.copyWith(status: MessageStatus.delivered).voiceDuration,
          const Duration(milliseconds: 12340));
      final changed = m.copyWith(metadata: {...m.metadata, 'durationMs': 1000});
      expect(changed.voiceDuration, const Duration(seconds: 1));
      expect(m.voiceDuration, const Duration(milliseconds: 12340), reason: 'original untouched');
    });

    test('voiceDuration ignores junk values', () {
      expect(voiceNote(metadata: {'durationMs': 'twelve'}).voiceDuration, isNull);
      expect(voiceNote(metadata: {'durationMs': -5}).voiceDuration, isNull);
      expect(voiceNote(metadata: {'durationMs': 1.5}).voiceDuration, isNull);
      expect(voiceNote(metadata: const {}).voiceDuration, isNull);
    });

    test('an unknown message type from a newer build falls back to text', () {
      final json = voiceNote().toJson()..['messageType'] = 'hologram';
      expect(ChatMessage.fromJson(json).messageType, MessageType.text);
      final legacy = voiceNote().toJson()..remove('messageType');
      expect(ChatMessage.fromJson(legacy).messageType, MessageType.text);
    });

    test('image attachments keep the cached thumbnail across progress updates', () {
      final att = FileAttachment(
        fileName: 'p.jpg', mimeType: 'image/jpeg', fileSize: 1000,
        thumbnailB64: base64Encode([0xFF, 0xD8, 1, 2, 3]), totalChunks: 4, receivedChunks: 1,
      );
      final more = att.copyWith(receivedChunks: 3);
      expect(more.thumbnailB64, att.thumbnailB64);
      expect(more.receivedChunks, 3);
      expect(more.isComplete, isFalse);
      expect(more.progress, 0.75);
      final cached = att.copyWith(thumbnailB64: 'AAAA');
      expect(cached.thumbnailB64, 'AAAA');
      final back = FileAttachment.fromJson(jsonDecode(jsonEncode(cached.toJson())) as Map<String, dynamic>);
      expect(back.thumbnailB64, 'AAAA');
    });
  });

  group('voice hints on the wire', () {
    InnerMessage descriptor(Map<String, dynamic>? meta) => InnerMessage.file(
          id: 'v1', fileId: 'v1', fileName: 'voice_1700000000.m4a', mimeType: 'audio/mp4',
          fileSize: 49_152, fileKey: Uint8List(32), fileNonce: Uint8List(8),
          totalChunks: 2, chunkSize: 32 * 1024, sha256Hex: 'b' * 64, meta: meta,
        );

    test('duration and voice flag round trip inside the file descriptor', () {
      final meta = const MediaMetadata(voice: true, durationMs: 12340);
      final bytes = descriptor(meta.toWire()).toBytes();
      final back = InnerMessage.fromBytes(bytes);
      expect(back.type, InnerMessage.typeFile);
      final d = FileDescriptor.fromInnerBody(back.body);
      expect(d.mimeType, 'audio/mp4');
      expect(d.totalChunks, 2);
      final parsed = MediaMetadata.fromWire(back.body['meta'] as Map<String, dynamic>)!;
      expect(parsed.voice, isTrue);
      expect(parsed.durationMs, 12340);
      expect(parsed.duration, const Duration(milliseconds: 12340));
      expect(parsed.thumbnail, isNull);
      expect(parsed.toMessageMetadata(), {'durationMs': 12340, 'voice': true});
      expect(parsed.toWire(), {'dur': 12340, 'voice': true});
    });

    test('a descriptor without hints still parses (older senders)', () {
      final back = InnerMessage.fromBytes(descriptor(null).toBytes());
      expect(back.body.containsKey('meta'), isFalse);
      expect(MediaMetadata.fromWire(back.body['meta'] as Map<String, dynamic>?), isNull);
      expect(FileDescriptor.fromInnerBody(back.body).fileName, 'voice_1700000000.m4a');
    });

    test('voice descriptors stay in the smallest padding buckets', () {
      final bytes = descriptor(const MediaMetadata(voice: true, durationMs: 300000).toWire()).toBytes();
      expect(Padding.bucketFor(bytes.length), lessThanOrEqualTo(1024));
    });

    test('malformed hints fail as FormatException, never as a crash', () {
      expect(() => MediaMetadata.fromWire({'dur': 'long'}), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'voice': 1}), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'thumb': 12}), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'thumb': base64Encode(List.filled(64, 0))}), throwsFormatException);
    });
  });
}
