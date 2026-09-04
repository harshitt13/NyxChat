import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/media/media_metadata.dart';
import '../models/message.dart';
import '../screens/image_viewer_screen.dart';
import '../theme/app_theme.dart';

/// Image inside a message bubble.
///
/// Shows the inline preview from the file descriptor (or the locally
/// cached one) at once, with a progress overlay while the chunks are still
/// arriving, then fades the full picture in over it once the file is
/// complete. Tapping a complete image opens the zoomable viewer.
class ImageAttachmentView extends StatelessWidget {
  final ChatMessage message;

  /// Rendered when there is neither a preview nor a complete file.
  final Widget fallback;
  final double maxWidth;
  final double maxHeight;

  const ImageAttachmentView({
    super.key,
    required this.message,
    required this.fallback,
    this.maxWidth = 260,
    this.maxHeight = 320,
  });

  static final _ThumbnailCache _thumbnails = _ThumbnailCache(256);

  @override
  Widget build(BuildContext context) {
    final att = message.attachment;
    if (att == null) return fallback;
    final path = att.filePath;
    final complete = att.isComplete && path != null && File(path).existsSync();
    final thumb = att.thumbnailB64 == null
        ? null
        : _thumbnails.get(message.id, att.thumbnailB64!);
    if (thumb == null && !complete) return fallback;

    final ratio = _aspectRatio(message.metadata, thumb).clamp(0.5, 2.0);
    final layers = <Widget>[
      if (thumb != null)
        Image.memory(
          thumb,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: AppTheme.surfaceLight),
        )
      else
        const ColoredBox(color: AppTheme.surfaceLight),
      if (complete)
        Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 720,
          gaplessPlayback: true,
          frameBuilder: (_, child, frame, wasSync) => wasSync
              ? child
              : AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: child,
                ),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      if (!complete) _ProgressOverlay(progress: att.progress),
    ];

    final picture = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Hero(
            tag: 'image-${message.id}',
            child: Stack(fit: StackFit.expand, children: layers),
          ),
        ),
      ),
    );
    if (!complete) return picture;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ImageViewerScreen(
          path: path,
          title: att.fileName,
          heroTag: 'image-${message.id}',
        ),
      )),
      child: picture,
    );
  }

  static double _aspectRatio(Map<String, dynamic> meta, Uint8List? thumb) {
    final w = meta['w'];
    final h = meta['h'];
    if (w is int && h is int && w > 0 && h > 0) return w / h;
    if (thumb != null) {
      final size = MediaMetadata.jpegSize(thumb);
      if (size != null) return size.$1 / size.$2;
    }
    return 4 / 3;
  }
}

class _ProgressOverlay extends StatelessWidget {
  final double progress;

  const _ProgressOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.38),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: progress <= 0 ? null : progress,
              strokeWidth: 3,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 6),
          Text('$pct%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Decoded thumbnail bytes by message id. Keeping the same Uint8List
/// instance across rebuilds lets Image.memory reuse its decoded frame
/// instead of decoding the JPEG on every scroll.
class _ThumbnailCache {
  final int capacity;
  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap();

  _ThumbnailCache(this.capacity);

  Uint8List? get(String id, String b64) {
    final hit = _map.remove(id);
    if (hit != null) {
      _map[id] = hit;
      return hit;
    }
    Uint8List bytes;
    try {
      bytes = base64Decode(b64);
    } catch (_) {
      return null;
    }
    if (MediaMetadata.jpegSize(bytes) == null) return null;
    _map[id] = bytes;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
    return bytes;
  }
}
