// Thumbnail generator: size and byte caps, orientation, tiny inputs,
// non-images, and the padding-bucket budget the cap was chosen for.
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nyxchat/core/media/media_metadata.dart';
import 'package:nyxchat/core/media/thumbnailer.dart';
import 'package:nyxchat/core/protocol/inner_message.dart';
import 'package:nyxchat/core/protocol/padding.dart';

/// A photo-like scene: smooth gradient, a few shapes, light noise.
img.Image scene(int w, int h, {int seed = 1}) {
  final im = img.Image(width: w, height: h);
  final rnd = Random(seed);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final n = rnd.nextInt(9) - 4;
      final r = (255 * x / w).round() + n;
      final g = (255 * y / h).round() + n;
      final b = ((x + y) % 97 < 40 ? 200 : 60) + n;
      im.setPixelRgb(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
    }
  }
  img.fillCircle(im, x: w ~/ 3, y: h ~/ 2, radius: min(w, h) ~/ 5, color: im.getColor(250, 240, 30));
  return im;
}

img.Image noise(int w, int h, {int seed = 7}) {
  final im = img.Image(width: w, height: h);
  final rnd = Random(seed);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgb(x, y, rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
    }
  }
  return im;
}

Uint8List jpeg(img.Image im, {int quality = 90, int? orientation}) {
  if (orientation != null) im.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(im, quality: quality);
}

/// Minimal JPEG prefix whose SOF0 declares [w] x [h].
Uint8List fakeJpegHeader(int w, int h) => Uint8List.fromList([
      0xFF, 0xD8, // SOI
      0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0, 4 bytes
      0xFF, 0xC0, 0x00, 0x11, 0x08, // SOF0, len 17, precision 8
      (h >> 8) & 0xff, h & 0xff, (w >> 8) & 0xff, w & 0xff, 0x03,
      0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
    ]);

void main() {
  group('Thumbnailer', () {
    test('landscape photo fits 256 px on the long side and the byte cap', () {
      final t = Thumbnailer.generateSync(jpeg(scene(1280, 800)));
      expect(t, isNotNull);
      expect(t!.width, 256);
      expect(t.height, 160);
      expect(t.bytes, lessThanOrEqualTo(Thumbnailer.maxBytes));
      expect(t.bytes, greaterThan(500), reason: 'should still be a picture');
      expect(MediaMetadata.jpegSize(t.jpeg), (256, 160));
      final back = img.decodeJpg(t.jpeg)!;
      expect(back.width, 256);
      expect(back.height, 160);
    });

    test('portrait photo keeps its aspect ratio', () {
      final t = Thumbnailer.generateSync(jpeg(scene(1000, 1600)))!;
      expect(t.width, 160);
      expect(t.height, 256);
      expect(t.bytes, lessThanOrEqualTo(Thumbnailer.maxBytes));
    });

    test('tiny images are not upscaled', () {
      final t = Thumbnailer.generateSync(jpeg(scene(20, 12)))!;
      expect(t.width, 20);
      expect(t.height, 12);
      expect(t.bytes, lessThan(2048));
      expect(MediaMetadata.jpegSize(t.jpeg), (20, 12));
    });

    test('1x1 image works', () {
      final t = Thumbnailer.generateSync(jpeg(scene(1, 1)))!;
      expect((t.width, t.height), (1, 1));
    });

    test('incompressible noise still lands under the cap (quality, then size)', () {
      final t = Thumbnailer.generateSync(jpeg(noise(700, 700), quality: 100))!;
      expect(t.bytes, lessThanOrEqualTo(Thumbnailer.maxBytes));
      expect(max(t.width, t.height), lessThanOrEqualTo(Thumbnailer.maxSide));
      expect(max(t.width, t.height), greaterThanOrEqualTo(Thumbnailer.minSide));
    });

    test('EXIF orientation is applied and all EXIF is stripped', () {
      // 800x400 source with a red block in its top-left corner, tagged
      // orientation 6 (rotate 90 degrees clockwise to display).
      final src = scene(800, 400);
      img.fillRect(src, x1: 0, y1: 0, x2: 120, y2: 120, color: src.getColor(255, 0, 0));
      final t = Thumbnailer.generateSync(jpeg(src, orientation: 6))!;
      expect(t.width, 128, reason: 'rotated to portrait');
      expect(t.height, 256);
      final back = img.decodeJpg(t.jpeg)!;
      expect(back.exif.imageIfd.orientation, isNull);
      expect(back.exif.isEmpty, isTrue, reason: 'no EXIF leaks into the preview');
      // The source's top-left corner ends up top-right after a 90 degree
      // clockwise rotation.
      final p = back.getPixel(back.width - 4, 4);
      expect(p.r, greaterThan(150));
      expect(p.g, lessThan(90));
      expect(p.b, lessThan(90));
      final q = back.getPixel(4, 4);
      expect(q.r < 150 || q.g > 90, isTrue, reason: 'top-left is no longer the red block');
    });

    test('PNG input (with alpha) becomes a JPEG preview', () {
      final src = img.Image(width: 300, height: 200, numChannels: 4);
      img.fill(src, color: src.getColor(10, 200, 90, 128));
      final t = Thumbnailer.generateSync(img.encodePng(src))!;
      expect(t.width, 256);
      expect(t.height, 171);
      expect(t.jpeg.sublist(0, 2), [0xFF, 0xD8]);
    });

    test('garbage and empty input give null', () {
      expect(Thumbnailer.generateSync(Uint8List(0)), isNull);
      expect(Thumbnailer.generateSync(Uint8List.fromList(List.generate(4096, (i) => i * 7 & 0xff))), isNull);
      expect(Thumbnailer.generateSync(fakeJpegHeader(100, 100)), isNull, reason: 'truncated JPEG');
    });

    test('custom side and byte caps are honoured', () {
      final small = Thumbnailer.generateSync(jpeg(scene(1000, 500)), maxSide: 64)!;
      expect(max(small.width, small.height), 64);
      final tight = Thumbnailer.generateSync(jpeg(scene(1000, 500)), maxBytes: 1500)!;
      expect(tight.bytes, lessThanOrEqualTo(1500));
    });

    test('the isolate wrapper returns the same result', () async {
      final bytes = jpeg(scene(640, 480));
      final sync = Thumbnailer.generateSync(bytes)!;
      final async = (await Thumbnailer.generate(bytes))!;
      expect(async.width, sync.width);
      expect(async.height, sync.height);
      expect(async.jpeg, sync.jpeg);
    });
  });

  group('padding budget', () {
    InnerMessage descriptor({int thumbBytes = 0}) => InnerMessage.file(
          id: '5f1c4c6e-4b1d-4f6a-9b4e-1234567890ab',
          fileId: '5f1c4c6e-4b1d-4f6a-9b4e-1234567890ab',
          fileName: 'IMG_${'x' * 120}.jpg',
          mimeType: 'image/jpeg',
          fileSize: 4 * 1024 * 1024,
          fileKey: Uint8List(32),
          fileNonce: Uint8List(8),
          totalChunks: 128,
          chunkSize: 32 * 1024,
          sha256Hex: 'a' * 64,
          groupId: '9c2f0e1a-1b2c-4d3e-8f90-abcdefabcdef',
          meta: thumbBytes == 0
              ? null
              : MediaMetadata(thumbnail: Uint8List(thumbBytes), width: 256, height: 192).toWire(),
        );

    test('a descriptor with a maximum-size thumbnail stays in the 16 KiB bucket', () {
      final withThumb = descriptor(thumbBytes: Thumbnailer.maxBytes).toBytes();
      expect(Padding.bucketFor(withThumb.length), 16 * 1024);
      final bare = descriptor().toBytes();
      expect(Padding.bucketFor(bare.length), lessThanOrEqualTo(1024));
    });

    test('a 12 KiB thumbnail would double the bucket, which is why the cap is 10 KiB', () {
      final big = descriptor(thumbBytes: 12 * 1024).toBytes();
      expect(Padding.bucketFor(big.length), 32 * 1024);
    });

    test('a real photo thumbnail is under the cap with room to spare', () {
      final t = Thumbnailer.generateSync(jpeg(scene(2400, 1800)))!;
      final bytes = descriptor(thumbBytes: 0).body;
      bytes['meta'] = MediaMetadata(thumbnail: t.jpeg, width: t.width, height: t.height).toWire();
      final encoded = InnerMessage(type: InnerMessage.typeFile, id: 'x', body: bytes).toBytes();
      expect(Padding.bucketFor(encoded.length), lessThanOrEqualTo(16 * 1024));
    });
  });

  group('MediaMetadata wire parsing', () {
    test('round trip of image hints', () {
      final t = Thumbnailer.generateSync(jpeg(scene(640, 480)))!;
      final wire = MediaMetadata(thumbnail: t.jpeg, width: t.width, height: t.height).toWire();
      final parsed = MediaMetadata.fromWire(wire)!;
      expect(parsed.thumbnail, t.jpeg);
      expect(parsed.width, 256);
      expect(parsed.height, 192);
      expect(parsed.voice, isFalse);
      expect(parsed.durationMs, isNull);
      expect(parsed.toMessageMetadata(), {'w': 256, 'h': 192});
    });

    test('absent and empty hints', () {
      expect(MediaMetadata.fromWire(null), isNull);
      final empty = MediaMetadata.fromWire(<String, dynamic>{})!;
      expect(empty.isEmpty, isTrue);
      expect(const MediaMetadata().toWire(), isEmpty);
    });

    test('rejects previews that are not JPEG', () {
      final wire = MediaMetadata(thumbnail: img.encodePng(scene(8, 8))).toWire();
      expect(() => MediaMetadata.fromWire(wire), throwsFormatException);
    });

    test('rejects a JPEG header declaring a huge frame', () {
      final wire = MediaMetadata(thumbnail: fakeJpegHeader(2000, 2000)).toWire();
      expect(() => MediaMetadata.fromWire(wire), throwsFormatException);
      final ok = MediaMetadata(thumbnail: fakeJpegHeader(256, 192)).toWire();
      expect(MediaMetadata.fromWire(ok)!.thumbnail, isNotNull);
    });

    test('rejects oversized previews, bad dimensions and durations', () {
      final tooBig = <String, dynamic>{'thumb': MediaMetadata(thumbnail: Uint8List(MediaMetadata.maxThumbnailBytes + 1)).thumbnailB64};
      expect(() => MediaMetadata.fromWire(tooBig), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'thumb': MediaMetadata(thumbnail: fakeJpegHeader(10, 10)).thumbnailB64, 'w': 0}), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'thumb': MediaMetadata(thumbnail: fakeJpegHeader(10, 10)).thumbnailB64, 'h': 'tall'}), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'dur': MediaMetadata.maxDurationMs + 1}), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'dur': -1}), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'dur': 1.5}), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'voice': 'yes'}), throwsFormatException);
      expect(() => MediaMetadata.fromWire({'thumb': 'not base64!!'}), throwsFormatException);
    });

    test('jpegSize reads the frame header of real encoder output', () {
      expect(MediaMetadata.jpegSize(jpeg(scene(37, 19))), (37, 19));
      expect(MediaMetadata.jpegSize(jpeg(scene(37, 19), orientation: 6)), (37, 19), reason: 'raw frame size, EXIF ignored');
      expect(MediaMetadata.jpegSize(Uint8List.fromList([0xFF, 0xD8, 0xFF])), isNull);
      expect(MediaMetadata.jpegSize(Uint8List(0)), isNull);
    });
  });
}
