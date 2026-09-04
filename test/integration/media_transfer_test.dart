// Voice notes and images with inline previews between two complete stacks,
// over a loopback TCP link and over a simulated mesh link. Checks that the
// media hints (thumbnail, dimensions, duration) arrive with the descriptor
// before the chunks, that the file bytes match once the transfer completes
// and that receipts flow back.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nyxchat/core/media/media_metadata.dart';
import 'package:nyxchat/core/media/thumbnailer.dart';
import 'package:nyxchat/models/message.dart';

import 'harness.dart';

/// A photo-like JPEG, large enough to need several 32 KiB chunks.
Uint8List photo(int w, int h) {
  final im = img.Image(width: w, height: h);
  final rnd = Random(42);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final n = rnd.nextInt(25) - 12;
      im.setPixelRgb(
        x, y,
        ((255 * x / w).round() + n).clamp(0, 255),
        ((255 * y / h).round() + n).clamp(0, 255),
        (((x ~/ 40 + y ~/ 40) % 2 == 0 ? 190 : 70) + n).clamp(0, 255),
      );
    }
  }
  img.fillCircle(im, x: w ~/ 2, y: h ~/ 2, radius: h ~/ 4, color: im.getColor(240, 200, 40));
  return img.encodeJpg(im, quality: 88);
}

/// Stand-in for an AAC recording: the transfer path does not care about
/// the codec, only the bytes and the metadata.
Uint8List fakeVoiceBytes(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + (i >> 7)) & 0xff));

/// Dart-side JPEG work plus two transfers per carrier; the default 30 s
/// is too tight when test isolates share the CPU.
const slow = Timeout(Duration(minutes: 3));

void main() {
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('nyx_media_it_');
  });

  tearDownAll(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> exchange(Node a, Node b, String roomId, {required String label}) async {
    // Image with an inline preview
    final photoBytes = photo(960, 640);
    expect(photoBytes.length, greaterThan(64 * 1024), reason: 'needs several chunks');
    final photoFile = File('${root.path}/${a.name}_$label.jpg')..writeAsBytesSync(photoBytes);
    final sent = await a.chat.sendFile(roomId: roomId, filePath: photoFile.path);
    expect(sent, isNotNull, reason: 'image accepted for sending over $label');
    expect(sent!.messageType, MessageType.image);
    expect(sent.status, MessageStatus.sent);
    final thumbB64 = sent.attachment!.thumbnailB64;
    expect(thumbB64, isNotNull, reason: 'sender keeps the preview too');
    final thumb = base64Decode(thumbB64!);
    expect(thumb.length, lessThanOrEqualTo(Thumbnailer.maxBytes));
    expect(MediaMetadata.jpegSize(thumb), (256, 171));
    expect(sent.metadata, {'w': 256, 'h': 171});

    await waitFor(() => b.received.any((m) => m.id == sent.id), what: 'B receives image descriptor over $label');
    final announced = b.received.firstWhere((m) => m.id == sent.id);
    expect(announced.messageType, MessageType.image);
    expect(announced.attachment!.thumbnailB64, thumbB64, reason: 'preview arrives with the descriptor');
    expect(announced.metadata, {'w': 256, 'h': 171});
    expect(announced.attachment!.receivedChunks, 0, reason: 'announced before any chunk');
    expect(announced.attachment!.totalChunks, sent.attachment!.totalChunks);

    final bRoom = b.chat.chatRooms.firstWhere((r) => r.peerId == a.id);
    await waitFor(() => b.messageById(bRoom.id, sent.id)?.attachment?.isComplete == true,
        timeout: const Duration(seconds: 60), what: 'image completes over $label');
    final gotImage = b.messageById(bRoom.id, sent.id)!;
    expect(gotImage.attachment!.thumbnailB64, thumbB64);
    expect(File(gotImage.attachment!.filePath!).readAsBytesSync(), photoBytes);
    await waitFor(() => a.messageById(roomId, sent.id)?.status == MessageStatus.delivered,
        timeout: const Duration(seconds: 30), what: 'image delivery receipt over $label');

    // Voice note
    final voiceBytes = fakeVoiceBytes(70 * 1024);
    final recording = File('${root.path}/${a.name}_${label}_rec.m4a')..writeAsBytesSync(voiceBytes);
    const length = Duration(seconds: 12, milliseconds: 340);
    final vsent = await a.chat.sendVoiceNote(roomId: roomId, filePath: recording.path, duration: length);
    expect(vsent, isNotNull, reason: 'voice note accepted over $label');
    expect(vsent!.messageType, MessageType.voice);
    expect(vsent.isVoice, isTrue);
    expect(vsent.voiceDuration, length);
    expect(vsent.metadata, {'durationMs': 12340, 'voice': true});
    expect(vsent.attachment!.mimeType, 'audio/mp4');
    expect(vsent.attachment!.thumbnailB64, isNull);
    expect(recording.existsSync(), isFalse, reason: 'moved out of the temp location');
    expect(File(vsent.attachment!.filePath!).existsSync(), isTrue);
    expect(vsent.attachment!.filePath, contains('nyxchat_files'));

    await waitFor(() => b.received.any((m) => m.id == vsent.id), what: 'B receives voice descriptor over $label');
    final vAnnounced = b.received.firstWhere((m) => m.id == vsent.id);
    expect(vAnnounced.messageType, MessageType.voice);
    expect(vAnnounced.voiceDuration, length);
    expect(vAnnounced.metadata, {'durationMs': 12340, 'voice': true});
    expect(vAnnounced.attachment!.mimeType, 'audio/mp4');
    await waitFor(() => b.messageById(bRoom.id, vsent.id)?.attachment?.isComplete == true,
        timeout: const Duration(seconds: 60), what: 'voice note completes over $label');
    final gotVoice = b.messageById(bRoom.id, vsent.id)!;
    expect(File(gotVoice.attachment!.filePath!).readAsBytesSync(), voiceBytes);
    expect(gotVoice.voiceDuration, length);
    await waitFor(() => a.messageById(roomId, vsent.id)?.status == MessageStatus.delivered,
        timeout: const Duration(seconds: 30), what: 'voice delivery receipt over $label');

    // Read receipts cover voice notes like text.
    await b.chat.markRoomAsRead(bRoom.id);
    await waitFor(() => a.messageById(roomId, vsent.id)?.status == MessageStatus.read,
        timeout: const Duration(seconds: 30), what: 'voice read receipt over $label');

    // A plain file (no image, no voice flag) carries no hints.
    final doc = File('${root.path}/${a.name}_$label.bin')..writeAsBytesSync(fakeVoiceBytes(3000));
    final fsent = await a.chat.sendFile(roomId: roomId, filePath: doc.path);
    expect(fsent!.messageType, MessageType.file);
    expect(fsent.metadata, isEmpty);
    expect(fsent.attachment!.thumbnailB64, isNull);
    await waitFor(() => b.messageById(bRoom.id, fsent.id)?.attachment?.isComplete == true, what: 'file completes over $label');
    expect(b.messageById(bRoom.id, fsent.id)!.messageType, MessageType.file);
  }

  test('image preview and voice note over a direct TCP link', () async {
    final a = await Node.create('ma1', root, hiveInit: true);
    final b = await Node.create('mb1', root);
    await a.connectTo(b);
    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');
    await exchange(a, b, room.id, label: 'tcp');
    await a.dispose();
    await b.dispose();
  }, timeout: slow);

  test('image preview and voice note over the simulated mesh', () async {
    final a = await Node.create('ma2', root);
    final b = await Node.create('mb2', root);
    await a.trust.acceptNewKeys(b.pinned());
    await b.trust.acceptNewKeys(a.pinned());
    await a.chat.refreshTokens(force: true);
    await b.chat.refreshTokens(force: true);
    a.mesh.onForwardPacket = (p, _) => unawaited(b.mesh.handlePacket(p));
    b.mesh.onForwardPacket = (p, _) => unawaited(a.mesh.handlePacket(p));
    a.chat.meshLinkCountProvider = () => 1;
    b.chat.meshLinkCountProvider = () => 1;
    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');
    await exchange(a, b, room.id, label: 'mesh');
    // Forward timers fire up to two seconds later; cut the link first.
    a.mesh.onForwardPacket = null;
    b.mesh.onForwardPacket = null;
    await a.dispose();
    await b.dispose();
  }, timeout: slow);

  test('a received image without an inline preview gets one cached locally', () async {
    final a = await Node.create('ma3', root);
    final b = await Node.create('mb3', root);
    await a.connectTo(b);
    final room = await a.chat.getOrCreateDirectRoom(peerId: b.id, displayName: 'B');
    final photoFile = File('${root.path}/ma3_plain.jpg')..writeAsBytesSync(photo(400, 300));
    final sent = await a.chat.sendFile(roomId: room.id, filePath: photoFile.path, inlinePreview: false);
    expect(sent, isNotNull);
    expect(sent!.messageType, MessageType.image);
    expect(sent.attachment!.thumbnailB64, isNull);
    expect(sent.metadata, isEmpty);

    await waitFor(() => b.received.any((m) => m.id == sent.id), what: 'B receives the descriptor');
    expect(b.received.firstWhere((m) => m.id == sent.id).attachment!.thumbnailB64, isNull,
        reason: 'nothing inline from an older-style sender');
    final bRoom = b.chat.chatRooms.firstWhere((r) => r.peerId == a.id);
    await waitFor(() => b.messageById(bRoom.id, sent.id)?.attachment?.thumbnailB64 != null,
        timeout: const Duration(seconds: 60), what: 'preview cached once the file is complete');
    final got = b.messageById(bRoom.id, sent.id)!;
    expect(got.attachment!.isComplete, isTrue);
    expect(MediaMetadata.jpegSize(base64Decode(got.attachment!.thumbnailB64!)), (256, 192));
    expect(got.metadata, {'w': 256, 'h': 192});
    final stored = await b.storage.getMessage(sent.id);
    expect(stored!.attachment!.thumbnailB64, got.attachment!.thumbnailB64, reason: 'persisted for scroll-back');
    await a.dispose();
    await b.dispose();
  }, timeout: slow);
}
