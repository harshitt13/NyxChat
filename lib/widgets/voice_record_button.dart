import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/voice_recorder.dart';
import '../theme/app_theme.dart';
import 'media_strings.dart';
import 'message_preview.dart';

/// Hold-to-record microphone button for the composer.
///
/// Press and hold to record; release to send; slide the finger left (or
/// tap the X in the recording strip) to cancel. While recording, a strip
/// with the elapsed time and a level meter is drawn over the text field
/// through the app overlay, so the composer itself needs no changes.
///
/// The recorder is created on the first press, so the button builds and
/// simply reports an error where the recording plugin is unavailable.
class VoiceRecordButton extends StatefulWidget {
  final bool enabled;
  final Future<void> Function(String path, Duration duration) onRecorded;
  final void Function(String message)? onError;
  final double size;

  const VoiceRecordButton({
    super.key,
    required this.onRecorded,
    this.onError,
    this.enabled = true,
    this.size = 40,
  });

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  /// Horizontal travel (logical pixels) that cancels the recording.
  static const double cancelDistance = 72;

  VoiceRecorder? _recorder;
  OverlayEntry? _hud;
  final ValueNotifier<bool> _cancelArmed = ValueNotifier(false);
  bool _pressed = false;
  bool _starting = false;
  bool _busy = false;
  Offset? _down;

  VoiceRecorder get _rec => _recorder ??= VoiceRecorder()..onLimitReached = _onLimit;

  bool get _recording => _recorder?.isRecording ?? false;

  @override
  void dispose() {
    _removeHud();
    final rec = _recorder;
    if (rec != null) {
      if (rec.isRecording) unawaited(rec.cancel().then((_) => rec.dispose()));
      if (!rec.isRecording) rec.dispose();
    }
    _cancelArmed.dispose();
    super.dispose();
  }

  Future<void> _onDown(PointerDownEvent e) async {
    if (!widget.enabled || _pressed || _busy) return;
    _pressed = true;
    _starting = true;
    _down = e.position;
    _cancelArmed.value = false;
    try {
      unawaited(HapticFeedback.selectionClick());
    } catch (_) {}
    final err = await _rec.start();
    _starting = false;
    if (!mounted) return;
    if (err != null) {
      _pressed = false;
      widget.onError?.call(err);
      return;
    }
    if (!_pressed) {
      // Released while the permission dialog was up.
      await _rec.cancel();
      return;
    }
    _showHud();
    setState(() {});
  }

  void _onMove(PointerMoveEvent e) {
    final down = _down;
    if (!_pressed || down == null) return;
    final armed = e.position.dx - down.dx < -cancelDistance;
    if (armed != _cancelArmed.value) {
      _cancelArmed.value = armed;
      try {
        unawaited(HapticFeedback.selectionClick());
      } catch (_) {}
    }
  }

  Future<void> _onUp(PointerUpEvent e) async {
    if (!_pressed) return;
    _pressed = false;
    if (_starting) return; // _onDown notices and discards the recording
    if (_cancelArmed.value) {
      await _cancel();
    } else {
      await _finish();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (!_pressed) return;
    _pressed = false;
    if (_starting) return;
    unawaited(_cancel());
  }

  void _onLimit() {
    if (!_pressed) return;
    _pressed = false;
    unawaited(_finish());
  }

  void _cancelFromHud() {
    _pressed = false;
    unawaited(_cancel());
  }

  Future<void> _finish() async {
    _removeHud();
    _busy = true;
    final rec = await _rec.stop();
    if (mounted) setState(() {});
    if (rec == null) {
      _busy = false;
      widget.onError?.call(MediaStrings.holdToRecord);
      return;
    }
    try {
      await widget.onRecorded(rec.path, rec.duration);
    } finally {
      _busy = false;
    }
  }

  Future<void> _cancel() async {
    _removeHud();
    await _rec.cancel();
    if (mounted) setState(() {});
  }

  void _showHud() {
    if (_hud != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = context.findRenderObject();
    if (overlay == null || box is! RenderBox || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 12,
        right: (screenWidth - origin.dx + 8).clamp(0.0, screenWidth),
        top: origin.dy - 4,
        height: size.height + 8,
        child: _RecordingStrip(
          recorder: _rec,
          cancelArmed: _cancelArmed,
          onCancel: _cancelFromHud,
        ),
      ),
    );
    _hud = entry;
    overlay.insert(entry);
  }

  void _removeHud() {
    _hud?.remove();
    _hud = null;
  }

  @override
  Widget build(BuildContext context) {
    final recording = _recording;
    final enabled = widget.enabled;
    final color = !enabled
        ? context.nyx.textMuted
        : recording
            ? context.nyx.error
            : context.nyx.textSecondary;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled ? (e) => unawaited(_onDown(e)) : null,
      onPointerMove: _onMove,
      onPointerUp: (e) => unawaited(_onUp(e)),
      onPointerCancel: _onPointerCancel,
      child: Semantics(
        button: true,
        label: MediaStrings.holdToRecord,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: recording
                ? context.nyx.error.withValues(alpha: 0.16)
                : context.nyx.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: recording
                  ? context.nyx.error.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(recording ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: color, size: 20),
        ),
      ),
    );
  }
}

/// The strip drawn over the text field while recording: blinking dot,
/// elapsed time, level meter, slide-to-cancel hint and a cancel button.
class _RecordingStrip extends StatelessWidget {
  final VoiceRecorder recorder;
  final ValueListenable<bool> cancelArmed;
  final VoidCallback onCancel;

  const _RecordingStrip({
    required this.recorder,
    required this.cancelArmed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ValueListenableBuilder<bool>(
        valueListenable: cancelArmed,
        builder: (context, armed, _) {
          final accent = armed ? context.nyx.error : context.nyx.accentBlue;
          return Container(
            padding: const EdgeInsets.only(left: 12, right: 2),
            decoration: BoxDecoration(
              color: context.nyx.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: ListenableBuilder(
              listenable: recorder,
              builder: (context, _) {
                final nearLimit =
                    recorder.remaining <= const Duration(seconds: 10);
                return Row(children: [
                  const _BlinkingDot(),
                  const SizedBox(width: 8),
                  Text(
                    formatClock(recorder.elapsed),
                    style: TextStyle(
                      color: nearLimit ? context.nyx.warning : context.nyx.textPrimary,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 22,
                      child: CustomPaint(
                        painter: _LevelMeterPainter(
                          levels: List<double>.from(recorder.levels),
                          capacity: VoiceRecorder.levelHistory,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    armed
                        ? MediaStrings.releaseToCancel
                        : '‹ ${MediaStrings.slideToCancel}',
                    style: TextStyle(
                        color: armed ? context.nyx.error : context.nyx.textMuted,
                        fontSize: 12),
                  ),
                  IconButton(
                    onPressed: onCancel,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: context.nyx.textSecondary),
                  ),
                ]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 0.25, end: 1).animate(_c),
        child: Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: context.nyx.error, shape: BoxShape.circle),
        ),
      );
}

/// Bars for the most recent input levels, newest at the right.
class _LevelMeterPainter extends CustomPainter {
  final List<double> levels;
  final int capacity;
  final Color color;

  _LevelMeterPainter(
      {required this.levels, required this.capacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (capacity <= 0) return;
    final slot = size.width / capacity;
    final barWidth = (slot * 0.55).clamp(1.0, 4.0);
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final faint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    final mid = size.height / 2;
    final minHalf = 1.0;
    for (var i = 0; i < capacity; i++) {
      final idx = levels.length - capacity + i;
      final level = idx >= 0 ? levels[idx] : 0.0;
      final half = minHalf + (mid - minHalf) * level;
      final x = slot * i + slot / 2;
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half),
          idx >= 0 ? paint : faint);
    }
  }

  @override
  bool shouldRepaint(_LevelMeterPainter old) =>
      old.color != color || !listEquals(old.levels, levels);
}
