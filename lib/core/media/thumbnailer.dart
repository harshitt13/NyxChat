import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A small JPEG preview of an image. It travels inside the (end-to-end
/// encrypted) file descriptor so the recipient can show something before
/// the chunks arrive, and is cached locally so scroll-back never has to
/// decode the full picture just to paint a bubble.
class Thumbnail {
  final Uint8List jpeg;
  final int width;
  final int height;

  const Thumbnail({required this.jpeg, required this.width, required this.height});

  String get base64 => base64Encode(jpeg);
  int get bytes => jpeg.length;
}

/// Downscales images to previews with a hard byte budget.
class Thumbnailer {
  Thumbnailer._();

  /// Longest side of a generated preview.
  static const int maxSide = 256;

  /// Encoded size cap. A file descriptor is roughly 500 bytes of JSON plus
  /// the base64 thumbnail (4/3 overhead). 10 KiB keeps every image
  /// descriptor inside the 16 KiB length-hiding bucket (Padding.bucketFor)
  /// even with a long file name and a group id; 12 KiB would push it into
  /// the 32 KiB bucket, doubling what the mesh has to carry per photo.
  static const int maxBytes = 10 * 1024;

  /// Starting JPEG quality; lowered in steps when the cap is exceeded.
  static const int quality = 60;

  /// Never shrink below this before giving up.
  static const int minSide = 48;

  /// Largest source we are willing to decode in Dart for a preview.
  static const int maxSourceBytes = 64 * 1024 * 1024;

  /// Decodes [source], applies its EXIF orientation, drops every other EXIF
  /// field (GPS position, camera, ...), fits it in a [maxSide] box without
  /// upscaling and encodes a JPEG under [maxBytes]. Returns null when the
  /// bytes are not a decodable image.
  static Thumbnail? generateSync(
    Uint8List source, {
    int maxSide = maxSide,
    int maxBytes = maxBytes,
    int quality = quality,
  }) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(source);
    } catch (_) {
      return null;
    }
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) return null;
    img.Image image;
    try {
      image = img.bakeOrientation(decoded);
    } catch (_) {
      image = decoded;
    }
    image.exif = img.ExifData();

    var side = maxSide;
    var q = quality;
    var scaled = _fit(image, side);
    var out = _encode(scaled, q);
    while (out == null || out.length > maxBytes) {
      if (q > 30) {
        q -= 10;
      } else if (side > minSide) {
        side = max(minSide, (side * 3) ~/ 4);
        q = 50;
        scaled = _fit(image, side);
      } else {
        return null;
      }
      out = _encode(scaled, q);
    }
    return Thumbnail(jpeg: out, width: scaled.width, height: scaled.height);
  }

  static Uint8List? _encode(img.Image image, int quality) {
    try {
      return img.encodeJpg(image, quality: quality);
    } catch (_) {
      return null;
    }
  }

  static img.Image _fit(img.Image image, int maxSide) {
    final longest = max(image.width, image.height);
    if (longest <= maxSide) return image;
    final scale = maxSide / longest;
    final w = max(1, (image.width * scale).round());
    final h = max(1, (image.height * scale).round());
    return img.copyResize(image,
        width: w, height: h, interpolation: img.Interpolation.average);
  }

  /// [generateSync] on a worker isolate (decoding a photo in Dart takes
  /// long enough to drop frames on the UI thread).
  static Future<Thumbnail?> generate(
    Uint8List source, {
    int maxSide = maxSide,
    int maxBytes = maxBytes,
    int quality = quality,
  }) =>
      compute(_generateJob, _ThumbnailJob(source, maxSide, maxBytes, quality),
          debugLabel: 'thumbnail');

  /// Preview of the image at [path]; null when missing, too large to
  /// decode, or not an image.
  static Future<Thumbnail?> fromFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      if (await file.length() > maxSourceBytes) return null;
      return await generate(await file.readAsBytes());
    } catch (e) {
      debugPrint('[Thumbnailer] $path: $e');
      return null;
    }
  }
}

class _ThumbnailJob {
  final Uint8List source;
  final int maxSide;
  final int maxBytes;
  final int quality;
  const _ThumbnailJob(this.source, this.maxSide, this.maxBytes, this.quality);
}

Thumbnail? _generateJob(_ThumbnailJob job) => Thumbnailer.generateSync(
      job.source,
      maxSide: job.maxSide,
      maxBytes: job.maxBytes,
      quality: job.quality,
    );
