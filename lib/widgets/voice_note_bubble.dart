import 'dart:io';

import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/voice_player.dart';
import '../theme/app_theme.dart';
import 'media_strings.dart';
import 'message_preview.dart';

/// Voice note inside a message bubble: play/pause, seekable progress bar,
/// total length, and remaining time while playing. Playback state comes
/// from the app-wide [VoicePlayer], so it survives scrolling and only one
/// note plays at a time.
class VoiceNoteBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final double width;

  const VoiceNoteBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.width = 224,
  });

  @override
  Widget build(BuildContext context) {
    final att = message.attachment;
    final path = att?.filePath;
    final ready = att != null &&
        att.isComplete &&
        path != null &&
        File(path).existsSync();
    return ListenableBuilder(
      listenable: VoicePlayer.instance,
      builder: (context, _) {
        final player = VoicePlayer.instance;
        final id = message.id;
        final current = player.isCurrent(id);
        final playing = player.isPlaying(id);
        final loading = player.isLoading(id);
        final total = (current ? player.duration : null) ??
            message.voiceDuration ??
            Duration.zero;
        final pos = current ? player.position : Duration.zero;
        final progress = total.inMilliseconds <= 0
            ? 0.0
            : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        final active = current && (playing || pos > Duration.zero);
        final label = active
            ? '-${formatClock(total - pos)}'
            : (total == Duration.zero
                ? MediaStrings.voiceMessage
                : formatClock(total));
        final errorText = current ? player.error : null;
        return SizedBox(
          width: width,
          child: Row(children: [
            _PlayButton(
              ready: ready,
              playing: playing,
              loading: loading,
              progress: att?.progress ?? 0,
              onTap: ready ? () => player.toggle(id, path) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 26,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: context.nyx.accentBlue,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                        disabledActiveTrackColor:
                            Colors.white.withValues(alpha: 0.12),
                        disabledInactiveTrackColor:
                            Colors.white.withValues(alpha: 0.08),
                        thumbColor: context.nyx.accentBlue,
                        disabledThumbColor: context.nyx.textMuted,
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: ready && total > Duration.zero
                            ? (v) => player.seek(id, path, total * v)
                            : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Row(children: [
                      Icon(Icons.mic_rounded,
                          size: 11, color: context.nyx.textMuted),
                      const SizedBox(width: 3),
                      Text(label,
                          style: TextStyle(
                              color: context.nyx.textMuted, fontSize: 11)),
                      if (!ready && att != null && !att.isComplete) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${MediaStrings.receiving} ${(att.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: context.nyx.textMuted, fontSize: 11),
                        ),
                      ],
                      if (errorText != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(errorText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.nyx.error, fontSize: 11)),
                        ),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool ready;
  final bool playing;
  final bool loading;
  final double progress;
  final VoidCallback? onTap;

  const _PlayButton({
    required this.ready,
    required this.playing,
    required this.loading,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const size = 38.0;
    if (!ready) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: progress <= 0 ? null : progress,
            strokeWidth: 2.5,
            color: context.nyx.accentBlue,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
          ),
          Icon(Icons.mic_rounded, size: 16, color: context.nyx.textMuted),
        ]),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.nyx.accentBlue.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: context.nyx.accentBlue.withValues(alpha: 0.4)),
        ),
        child: loading
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: context.nyx.accentBlue),
              )
            : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: context.nyx.accentBlue, size: 22),
      ),
    );
  }
}
