import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/storage/trust_store.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/peer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';
import 'contact_verify_screen.dart';
import 'group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  const ChatScreen({super.key, required this.roomId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  ChatMessage? _replyTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatService>().markRoomAsRead(widget.roomId);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final chat = context.read<ChatService>();
    _input.clear();
    final reply = _replyTo?.id;
    setState(() => _replyTo = null);
    await chat.sendText(roomId: widget.roomId, text: text, replyToId: reply);
    _scrollToBottom();
  }

  Future<void> _attach() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    final sent = await context
        .read<ChatService>()
        .sendFile(roomId: widget.roomId, filePath: path);
    if (sent == null && mounted) {
      _snack('Files need a direct connection. Come within Wi-Fi range first.');
    }
    _scrollToBottom();
  }

  void _snack(String text, {Color color = AppTheme.surfaceLight}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _messageMenu(ChatMessage msg, bool isMe) {
    final chat = context.read<ChatService>();
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '🎉'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: emojis
                  .map((e) => GestureDetector(
                        onTap: () {
                          chat.toggleReaction(
                              roomId: widget.roomId, messageId: msg.id, emoji: e);
                          Navigator.pop(ctx);
                        },
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ))
                  .toList(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: AppTheme.textSecondary),
            title: const Text('Reply', style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              setState(() => _replyTo = msg);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded, color: AppTheme.textSecondary),
            title: const Text('Copy text', style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg.content));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
            title: const Text('Delete for me', style: TextStyle(color: AppTheme.error)),
            onTap: () {
              chat.deleteMessage(widget.roomId, msg.id);
              Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }

  void _disappearingPicker(ChatRoom room) {
    const options = {
      'Off': 0, '5 minutes': 300, '1 hour': 3600, '1 day': 86400, '1 week': 604800,
    };
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Disappearing messages',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ...options.entries.map((e) => ListTile(
                title: Text(e.key, style: const TextStyle(color: AppTheme.textPrimary)),
                trailing: room.disappearAfterSeconds == e.value
                    ? const Icon(Icons.check_rounded, color: AppTheme.accentBlue)
                    : null,
                onTap: () {
                  context.read<ChatService>().setDisappearing(room.id, e.value);
                  Navigator.pop(ctx);
                },
              )),
        ]),
      ),
    );
  }

  String _time(DateTime t) {
    final now = DateTime.now();
    final sameDay = t.day == now.day && t.month == now.month && t.year == now.year;
    return sameDay ? DateFormat.Hm().format(t) : DateFormat('MMM d, HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ChatService, PeerService, TrustStore>(
      builder: (context, chat, peers, trust, _) {
        final room = chat.room(widget.roomId);
        if (room == null) {
          return const Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(child: Text('Conversation deleted',
                  style: TextStyle(color: AppTheme.textSecondary))));
        }
        final messages = chat.getMessages(room.id);
        final direct = !room.isGroup && peers.isPeerConnected(room.peerId);
        final mesh = !room.isGroup && !direct && peers.isReachableByMesh(room.peerId);
        final verified = !room.isGroup && trust.isVerified(room.peerId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients &&
              _scroll.position.maxScrollExtent - _scroll.position.pixels < 160) {
            _scrollToBottom();
          }
        });
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Column(children: [
            _appBar(room, direct: direct, mesh: mesh, verified: verified),
            Expanded(
              child: messages.isEmpty
                  ? _empty(room)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        final isMe = m.senderId == chat.myId;
                        if (m.messageType == MessageType.system) {
                          return _system(m.content);
                        }
                        final senderName = room.isGroup && !isMe
                            ? (room.members
                                    .where((x) => x.nyxChatId == m.senderId)
                                    .map((x) => x.displayName)
                                    .firstOrNull ??
                                trust.get(m.senderId)?.displayName ??
                                m.senderId)
                            : null;
                        final replied = m.replyToId == null
                            ? null
                            : messages.where((x) => x.id == m.replyToId).firstOrNull;
                        return GestureDetector(
                          onLongPress: () => _messageMenu(m, isMe),
                          child: MessageBubble(
                            message: m,
                            isMe: isMe,
                            senderName: senderName,
                            repliedTo: replied,
                            timeLabel: _time(m.timestamp),
                          ),
                        );
                      },
                    ),
            ),
            if (_replyTo != null) _replyBar(),
            _inputBar(room),
          ]),
        );
      },
    );
  }

  Widget _appBar(ChatRoom room,
      {required bool direct, required bool mesh, required bool verified}) {
    final status = room.isGroup
        ? '${room.memberCount} members${room.left ? ' (left)' : ''}'
        : direct ? 'Connected' : mesh ? 'Reachable via mesh' : 'Offline · will deliver later';
    final color = direct ? AppTheme.accentGreen : mesh ? AppTheme.accentBlue : AppTheme.textMuted;
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 6, left: 4, right: 8, bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary, size: 18),
        ),
        Expanded(
          child: InkWell(
            onTap: () => room.isGroup
                ? Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(roomId: room.id)))
                : Navigator.push(context, MaterialPageRoute(builder: (_) => ContactVerifyScreen(peerId: room.peerId))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(room.peerDisplayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 6),
                Icon(verified ? Icons.verified_rounded : Icons.lock_outline_rounded,
                    size: 14, color: verified ? AppTheme.accentGreen : AppTheme.textMuted),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(status, style: TextStyle(color: color, fontSize: 12)),
              ]),
            ]),
          ),
        ),
        IconButton(
          onPressed: () => _disappearingPicker(room),
          icon: Icon(Icons.timer_outlined,
              color: room.disappearAfterSeconds > 0 ? AppTheme.accentBlue : AppTheme.textSecondary, size: 21),
        ),
        IconButton(
          onPressed: room.left ? null : _attach,
          icon: const Icon(Icons.attach_file_rounded, color: AppTheme.textSecondary, size: 21),
        ),
      ]),
    );
  }

  Widget _empty(ChatRoom room) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 40, color: AppTheme.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('End-to-end encrypted', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            room.isGroup ? 'Messages use per-sender keys; only members can read them.'
                         : 'Messages are protected by a Double Ratchet session.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ]),
      );

  Widget _system(String text) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12)),
            child: Text(text, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ),
        ),
      );

  Widget _replyBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
        color: AppTheme.background,
        child: Row(children: [
          Container(width: 3, height: 32, color: AppTheme.accentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_replyTo!.content,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          IconButton(
            onPressed: () => setState(() => _replyTo = null),
            icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
          ),
        ]),
      );

  Widget _inputBar(ChatRoom room) => Container(
        padding: EdgeInsets.only(left: 14, right: 8, top: 10, bottom: MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.03))),
        ),
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              padding: const EdgeInsets.only(left: 16),
              child: TextField(
                controller: _input,
                enabled: !room.left,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: room.left ? 'You are no longer a member' : 'Message',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                maxLines: 5, minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: room.left ? null : _send,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: AppTheme.textSecondary, size: 20),
            ),
          ),
        ]),
      );
}