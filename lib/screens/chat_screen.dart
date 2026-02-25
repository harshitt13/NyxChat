import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/identity_service.dart';
import '../services/chat_service.dart';
import '../services/peer_service.dart';
import '../models/chat_room.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final ChatRoom room;
  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  void _markAsRead() {
    context.read<ChatService>().markRoomAsRead(widget.room.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final identity = context.read<IdentityService>().identity!;

    context.read<ChatService>().sendMessage(
          roomId: widget.room.id,
          peerId: widget.room.peerId,
          content: text,
          myBitChatId: identity.bitChatId,
          peerPublicKeyHex: widget.room.peerPublicKeyHex,
        );

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final identity = context.read<IdentityService>().identity!;

        await context.read<ChatService>().sendFile(
              roomId: widget.room.id,
              peerId: widget.room.peerId,
              filePath: filePath,
              myBitChatId: identity.bitChatId,
              peerPublicKeyHex: widget.room.peerPublicKeyHex,
            );

        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('File pick error: $e');
    }
  }

  void _showReactionPicker(ChatMessage message) {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '🎉'];
    final identity = context.read<IdentityService>().identity!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                context.read<ChatService>().toggleReaction(
                      roomId: widget.room.id,
                      messageId: message.id,
                      emoji: emoji,
                      myBitChatId: identity.bitChatId,
                    );
                Navigator.pop(ctx);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildAppBar(),
          _buildEncryptionBanner(),
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Consumer<PeerService>(
      builder: (_, peerService, __) {
        final isConnected = widget.room.isGroup
            ? true
            : peerService.isPeerConnected(widget.room.peerId);

        return Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8, right: 16, bottom: 12,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AppTheme.textPrimary, size: 18),
              ),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Center(
                  child: widget.room.isGroup
                      ? Icon(Icons.group_outlined,
                          color: AppTheme.textMuted, size: 18)
                      : Text(widget.room.displayInitials,
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.room.peerDisplayName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? AppTheme.accentGreen
                                : AppTheme.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.room.isGroup
                              ? '${widget.room.memberCount} members'
                              : isConnected ? 'Connected' : 'Offline',
                          style: TextStyle(
                            color: isConnected
                                ? AppTheme.accentGreen
                                : AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // File/media attach
              IconButton(
                onPressed: _pickAndSendFile,
                icon: const Icon(Icons.attach_file_rounded,
                    color: AppTheme.textSecondary, size: 22),
              ),
              IconButton(
                onPressed: () => _showPeerInfo(),
                icon: const Icon(Icons.info_outline_rounded,
                    color: AppTheme.textSecondary, size: 22),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEncryptionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 10,
              color: AppTheme.textMuted.withValues(alpha: 0.6)),
          const SizedBox(width: 5),
          Text(
            'encrypted',
            style: TextStyle(
              color: AppTheme.textMuted.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatService>(
      builder: (_, chatService, __) {
        final messages = chatService.getMessages(widget.room.id);
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 48,
                    color: AppTheme.textMuted.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                const Text('No messages yet',
                    style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  widget.room.isGroup
                      ? 'Send the first message to the group'
                      : 'Send a message to start the conversation',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        final myId = context.read<IdentityService>().identity?.bitChatId ?? '';

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final msg = messages[i];
            final isMe = msg.senderId == myId;

            if (msg.messageType == MessageType.system) {
              return _buildSystemMessage(msg);
            }

            return GestureDetector(
              onLongPress: () => _showReactionPicker(msg),
              child: _MessageBubble(
                message: msg,
                isMe: isMe,
                isGroup: widget.room.isGroup,
                formatTimestamp: _formatTimestamp,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSystemMessage(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(msg.content,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 8, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.03)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: AppTheme.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    if (time.day == now.day &&
        time.month == now.month &&
        time.year == now.year) {
      return DateFormat.Hm().format(time);
    }
    return DateFormat('MMM d, HH:mm').format(time);
  }

  void _showPeerInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Center(
                child: widget.room.isGroup
                    ? Icon(Icons.group_outlined,
                        color: AppTheme.textMuted, size: 24)
                    : Text(widget.room.displayInitials,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 20,
                            fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.room.peerDisplayName,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            if (widget.room.isGroup) ...[
              Text('${widget.room.memberCount} members',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14)),
              if (widget.room.groupDescription != null) ...[
                const SizedBox(height: 8),
                Text(widget.room.groupDescription!,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              // Member list
              ...widget.room.members.map((m) => ListTile(
                    dense: true,
                    leading: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                          child: Text(
                              m.displayName.isNotEmpty
                                  ? m.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: AppTheme.accentBlue,
                                  fontWeight: FontWeight.w600))),
                    ),
                    title: Text(m.displayName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14)),
                    trailing: m.isAdmin
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.accentPurple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Admin',
                                style: TextStyle(
                                    color: AppTheme.accentPurple,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          )
                        : null,
                  )),
            ] else ...[
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: widget.room.peerId));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Nyx ID copied!'),
                    backgroundColor: AppTheme.accentGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
                child: Text(widget.room.peerId,
                    style: const TextStyle(
                        color: AppTheme.accentBlue,
                        fontSize: 13,
                        fontFamily: 'monospace')),
              ),
              const SizedBox(height: 16),
              _infoRow(Icons.vpn_key_rounded, 'Public Key',
                  '${widget.room.peerPublicKeyHex.substring(0, 16)}...'),
              _infoRow(Icons.enhanced_encryption_rounded,
                  'Encryption', 'AES-256-GCM + Forward Secrecy'),
              _infoRow(Icons.swap_horiz_rounded, 'Key Exchange',
                  'X25519 ECDH (Rotating)'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.accentBlue),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Message Bubble Widget ──────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isGroup;
  final String Function(DateTime) formatTimestamp;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isGroup,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name for group chats
            if (isGroup && !isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  message.senderId.substring(0, 8),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

            // Message bubble
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.surfaceLight : AppTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMe ? 14 : 3),
                  bottomRight: Radius.circular(isMe ? 3 : 14),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isMe ? 0.06 : 0.03),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File attachment
                  if (message.attachment != null)
                    _buildAttachment(context),

                  // Text content
                  if (message.messageType == MessageType.text ||
                      (message.content.isNotEmpty &&
                          !message.content.startsWith('📎')))
                    Text(
                      message.content,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),

                  const SizedBox(height: 4),
                  // Timestamp + status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatTimestamp(message.timestamp),
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 10),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(message.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Reactions
            if (message.reactions.isNotEmpty) _buildReactions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(BuildContext context) {
    final att = message.attachment!;

    if (att.isImage && att.filePath != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxHeight: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(att.filePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFileIcon(att),
          ),
        ),
      );
    }

    return _buildFileIcon(att);
  }

  Widget _buildFileIcon(FileAttachment att) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              att.isImage
                  ? Icons.image_rounded
                  : Icons.insert_drive_file_rounded,
              color: AppTheme.accentBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(att.fileName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                Text(att.fileSizeFormatted,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    final counts = message.reactionCounts;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        children: counts.entries.map((entry) {
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.accentBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '${entry.key} ${entry.value}',
              style: const TextStyle(fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppTheme.textMuted));
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: AppTheme.textMuted);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: AppTheme.textMuted);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: AppTheme.accentBlue);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: AppTheme.error);
    }
  }
}
