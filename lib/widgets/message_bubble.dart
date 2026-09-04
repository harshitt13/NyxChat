import 'dart:io';

import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/app_theme.dart';

/// One chat bubble: text or attachment, reply quote, reactions, status.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String? senderName;
  final ChatMessage? repliedTo;
  final String timeLabel;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.timeLabel,
    this.senderName,
    this.repliedTo,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * AppThemeLimits.bubbleWidth;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          gradient: isMe ? AppTheme.messageSentGradient : null,
          color: isMe ? null : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(senderName!,
                    style: const TextStyle(
                        color: AppTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            if (repliedTo != null) _quote(repliedTo!),
            if (message.attachment != null) _attachment(context),
            if (message.attachment == null || message.messageType == MessageType.text)
              Text(message.content,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, height: 1.3)),
            if (message.reactions.isNotEmpty) _reactions(),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (message.expiresAt != null) ...[
                const Icon(Icons.timer_outlined, size: 11, color: AppTheme.textMuted),
                const SizedBox(width: 3),
              ],
              Text(timeLabel, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              if (isMe) ...[const SizedBox(width: 5), _status(message.status)],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _quote(ChatMessage q) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: AppTheme.accentBlue, width: 3)),
        ),
        child: Text(q.content,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      );

  Widget _attachment(BuildContext context) {
    final att = message.attachment!;
    final path = att.filePath;
    final complete = att.isComplete;
    if (att.isImage && complete && path != null && File(path).existsSync()) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(File(path), fit: BoxFit.cover, cacheWidth: 720,
              errorBuilder: (_, _, _) => _fileRow(att, complete)),
        ),
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: _fileRow(att, complete));
  }

  Widget _fileRow(FileAttachment att, bool complete) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(att.isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
              color: AppTheme.accentBlue, size: 26),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(att.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              if (complete)
                Text(att.fileSizeFormatted, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))
              else
                SizedBox(
                  width: 140,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LinearProgressIndicator(
                      value: att.progress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      color: AppTheme.accentBlue,
                    ),
                    const SizedBox(height: 3),
                    Text('${(att.progress * 100).toStringAsFixed(0)}% · ${att.fileSizeFormatted}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ]),
                ),
            ]),
          ),
        ]),
      );

  Widget _reactions() => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 4,
          children: message.reactionCounts.entries
              .map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${e.key}${e.value > 1 ? ' ${e.value}' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                  ))
              .toList(),
        ),
      );

  Widget _status(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.textMuted);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 14, color: AppTheme.textMuted);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 14, color: AppTheme.textMuted);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 14, color: AppTheme.accentBlue);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded, size: 14, color: AppTheme.error);
    }
  }
}

class AppThemeLimits {
  static const double bubbleWidth = 0.76;
}