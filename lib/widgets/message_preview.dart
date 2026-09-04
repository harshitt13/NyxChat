import 'package:flutter/material.dart';

import '../models/message.dart';
import 'media_strings.dart';

/// `m:ss` (or `h:mm:ss`) for voice-note lengths and playback positions.
String formatClock(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Body text for a notification about [m] when previews are enabled.
/// Media never leaks its file name into the shade.
String notificationBody(ChatMessage m) {
  switch (m.messageType) {
    case MessageType.voice:
      return MediaStrings.voiceMessage;
    case MessageType.image:
      return MediaStrings.photo;
    default:
      return m.content;
  }
}

/// One-line preview of a message for the conversation list: a microphone
/// glyph and the length for voice notes, a picture glyph for images, the
/// text otherwise.
class MessagePreview extends StatelessWidget {
  final ChatMessage? message;
  final String text;
  final TextStyle style;

  const MessagePreview({
    super.key,
    required this.message,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final iconSize = (style.fontSize ?? 13) + 2;
    if (m != null && m.isVoice) {
      final d = m.voiceDuration;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.mic_rounded, size: iconSize, color: style.color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(d == null ? MediaStrings.voiceMessage : formatClock(d),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
      ]);
    }
    if (m != null && m.messageType == MessageType.image) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.image_outlined, size: iconSize, color: style.color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(MediaStrings.photo,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
      ]);
    }
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
  }
}
