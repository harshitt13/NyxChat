import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
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
      alignment: isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          gradient: isMe ? context.nyx.messageSentGradient : null,
          color: isMe ? null : context.nyx.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(16),
            topEnd: const Radius.circular(16),
            bottomStart: Radius.circular(isMe ? 16 : 4),
            bottomEnd: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(color: context.nyx.hairline(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(senderName!,
                    style: TextStyle(
                        color: context.nyx.accentBlue, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            if (repliedTo != null) _quote(context, repliedTo!),
            if (message.attachment != null) _attachment(context),
            if (message.attachment == null || message.messageType == MessageType.text)
              Text(message.content,
                  style: TextStyle(color: context.nyx.textPrimary, fontSize: 15, height: 1.3)),
            if (message.reactions.isNotEmpty) _reactions(context),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (message.expiresAt != null) ...[
                Icon(Icons.timer_outlined, size: 11, color: context.nyx.textMuted),
                const SizedBox(width: 3),
              ],
              Text(timeLabel, style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
              if (isMe) ...[const SizedBox(width: 5), _status(context, message.status)],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _quote(BuildContext context, ChatMessage q) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: context.nyx.hairline(0.04),
          borderRadius: BorderRadius.circular(8),
          border: BorderDirectional(start: BorderSide(color: context.nyx.accentBlue, width: 3)),
        ),
        child: Text(q.content,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.nyx.textSecondary, fontSize: 12)),
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
              errorBuilder: (_, _, _) => _fileRow(context, att, complete)),
        ),
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: _fileRow(context, att, complete));
  }

  Widget _fileRow(BuildContext context, FileAttachment att, bool complete) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.nyx.hairline(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(att.isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
              color: context.nyx.accentBlue, size: 26),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(att.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.nyx.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              if (complete)
                Text(att.fileSizeFormatted, style: TextStyle(color: context.nyx.textMuted, fontSize: 11))
              else
                SizedBox(
                  width: 140,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LinearProgressIndicator(
                      value: att.progress,
                      minHeight: 3,
                      backgroundColor: context.nyx.hairline(0.06),
                      color: context.nyx.accentBlue,
                    ),
                    const SizedBox(height: 3),
                    Text(context.l10n.attachmentProgress((att.progress * 100).toStringAsFixed(0), att.fileSizeFormatted),
                        style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
                  ]),
                ),
            ]),
          ),
        ]),
      );

  Widget _reactions(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 4,
          children: message.reactionCounts.entries
              .map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.nyx.hairline(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${e.key}${e.value > 1 ? ' ${e.value}' : ''}',
                        style: TextStyle(fontSize: 12, color: context.nyx.textPrimary)),
                  ))
              .toList(),
        ),
      );

  Widget _status(BuildContext context, MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule_rounded, size: 13, color: context.nyx.textMuted);
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 14, color: context.nyx.textMuted);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 14, color: context.nyx.textMuted);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded, size: 14, color: context.nyx.accentBlue);
      case MessageStatus.failed:
        return Icon(Icons.error_outline_rounded, size: 14, color: context.nyx.error);
    }
  }
}

class AppThemeLimits {
  static const double bubbleWidth = 0.76;
}