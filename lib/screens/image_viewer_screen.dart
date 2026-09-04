import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/media_strings.dart';

/// Full-screen image viewer with pinch zoom, pan and double-tap zoom.
class ImageViewerScreen extends StatefulWidget {
  final String path;
  final String? title;
  final Object? heroTag;

  const ImageViewerScreen({
    super.key,
    required this.path,
    this.title,
    this.heroTag,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final TransformationController _transform = TransformationController();
  Offset? _doubleTapAt;
  bool _chromeVisible = true;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.05;
    if (zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    final at = _doubleTapAt;
    if (at == null) return;
    const scale = 2.5;
    // Zoom around the tapped point: translate so the point stays put.
    final m = Matrix4.translationValues(
        -at.dx * (scale - 1), -at.dy * (scale - 1), 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
    _transform.value = m;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final image = Image.file(
      File(widget.path),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.broken_image_outlined, size: 40, color: AppTheme.textMuted),
          SizedBox(height: 8),
          Text(MediaStrings.imageUnavailable,
              style: TextStyle(color: AppTheme.textSecondary)),
        ]),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => setState(() => _chromeVisible = !_chromeVisible),
            onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 6,
              clipBehavior: Clip.none,
              child: Center(
                child: widget.heroTag == null
                    ? image
                    : Hero(tag: widget.heroTag!, child: image),
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !_chromeVisible,
            child: Container(
              padding: EdgeInsets.only(top: top + 4, left: 4, right: 12, bottom: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 24),
                ),
                if (widget.title != null)
                  Expanded(
                    child: Text(widget.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
