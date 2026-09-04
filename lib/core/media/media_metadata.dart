import 'dart:convert';
import 'dart:typed_data';

import '../protocol/parse.dart';

/// Hints about a file that ride inside its descriptor, end-to-end
/// encrypted with it: an inline JPEG preview for images and the duration
/// of a voice note. Advisory only; the file itself is authenticated by its
/// per-file key and SHA-256 like every other transfer.
class MediaMetadata {
  /// The most inline preview a peer can make us hold. The generator
  /// targets less (Thumbnailer.maxBytes).
  static const int maxThumbnailBytes = 16 * 1024;

  /// A preview larger than this on either side is refused before any
  /// decoder sees it, so a tiny hostile JPEG cannot declare a huge frame.
  static const int maxThumbnailSide = 1024;

  /// Voice notes are capped at five minutes; allow a little slack.
  static const int maxDurationMs = 6 * 60 * 1000;

  /// JPEG preview, or null.
  final Uint8List? thumbnail;

  /// Preview dimensions in pixels (same aspect ratio as the full image).
  final int? width;
  final int? height;

  /// Voice note length.
  final int? durationMs;

  /// The file is a recorded voice message (rendered with a player rather
  /// than as a generic audio attachment).
  final bool voice;

  const MediaMetadata({
    this.thumbnail,
    this.width,
    this.height,
    this.durationMs,
    this.voice = false,
  });

  bool get isEmpty =>
      thumbnail == null &&
      width == null &&
      height == null &&
      durationMs == null &&
      !voice;

  String? get thumbnailB64 =>
      thumbnail == null ? null : base64Encode(thumbnail!);

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);

  /// Wire form: the `meta` object of an InnerMessage.file body.
  Map<String, dynamic> toWire() => {
        'thumb': ?thumbnailB64,
        'w': ?width,
        'h': ?height,
        'dur': ?durationMs,
        if (voice) 'voice': true,
      };

  /// What is kept on the local ChatMessage. The preview itself is stored
  /// on the attachment (FileAttachment.thumbnailB64), not duplicated here.
  Map<String, dynamic> toMessageMetadata() => {
        'w': ?width,
        'h': ?height,
        'durationMs': ?durationMs,
        if (voice) 'voice': true,
      };

  /// Parses an untrusted `meta` object. Throws [FormatException] on
  /// anything out of bounds; callers drop the hints and keep the file.
  static MediaMetadata? fromWire(Map<String, dynamic>? m) {
    if (m == null) return null;
    return parseOr(() {
      const ctx = 'media metadata';
      Uint8List? thumb;
      int? w;
      int? h;
      if (m['thumb'] != null) {
        thumb = requireBase64(m, 'thumb',
            maxBytes: maxThumbnailBytes, context: ctx);
        final size = jpegSize(thumb);
        if (size == null) {
          throw const FormatException('$ctx: thumbnail is not a JPEG');
        }
        if (size.$1 > maxThumbnailSide || size.$2 > maxThumbnailSide) {
          throw const FormatException('$ctx: thumbnail too large');
        }
        w = optionalInt(m, 'w', min: 1, max: maxThumbnailSide, context: ctx);
        h = optionalInt(m, 'h', min: 1, max: maxThumbnailSide, context: ctx);
      }
      final dur =
          optionalInt(m, 'dur', min: 0, max: maxDurationMs, context: ctx);
      final voice = optionalBool(m, 'voice', context: ctx) ?? false;
      return MediaMetadata(
          thumbnail: thumb, width: w, height: h, durationMs: dur, voice: voice);
    }, context: 'media metadata');
  }

  /// (width, height) from the SOF marker of a JPEG stream, or null when
  /// [bytes] is not a baseline/progressive JPEG.
  static (int, int)? jpegSize(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
    var i = 2;
    while (i + 3 < bytes.length) {
      if (bytes[i] != 0xFF) return null;
      final marker = bytes[i + 1];
      if (marker == 0xFF) {
        i++;
        continue;
      }
      if (marker == 0xD8 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2;
        continue;
      }
      if (marker == 0xD9 || marker == 0xDA) return null;
      final len = (bytes[i + 2] << 8) | bytes[i + 3];
      if (len < 2) return null;
      final isSof = marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isSof) {
        if (i + 8 >= bytes.length) return null;
        final h = (bytes[i + 5] << 8) | bytes[i + 6];
        final w = (bytes[i + 7] << 8) | bytes[i + 8];
        if (w == 0 || h == 0) return null;
        return (w, h);
      }
      i += 2 + len;
    }
    return null;
  }
}
