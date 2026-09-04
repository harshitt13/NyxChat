import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/storage/trust_store.dart';
import '../l10n/l10n_context.dart';
import '../l10n/system_messages.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/peer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/media_strings.dart';
import '../widgets/message_bubble.dart';
import '../widgets/voice_record_button.dart';
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
      _snack(context.l10n.filesNeedDirectConnection);
    }
    _scrollToBottom();
  }

  Future<void> _sendVoice(String path, Duration duration) async {
    final sent = await context
        .read<ChatService>()
        .sendVoiceNote(roomId: widget.roomId, filePath: path, duration: duration);
    if (sent == null && mounted) _snack(MediaStrings.voiceNeedsCarrier);
    _scrollToBottom();
  }

  void _snack(String text, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: color ?? context.nyx.surfaceLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _messageMenu(ChatMessage msg, bool isMe) {
    final chat = context.read<ChatService>();
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '🎉'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.nyx.surface,
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
            leading: Icon(Icons.reply_rounded, color: context.nyx.textSecondary),
            title: Text(context.l10n.reply, style: TextStyle(color: context.nyx.textPrimary)),
            onTap: () {
              setState(() => _replyTo = msg);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: Icon(Icons.copy_rounded, color: context.nyx.textSecondary),
            title: Text(context.l10n.copyText, style: TextStyle(color: context.nyx.textPrimary)),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg.content));
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: context.nyx.error),
            title: Text(context.l10n.deleteForMe, style: TextStyle(color: context.nyx.error)),
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
    final options = {
      context.l10n.off: 0, context.l10n.disappear5Minutes: 300, context.l10n.disappear1Hour: 3600, context.l10n.disappear1Day: 86400, context.l10n.disappear1Week: 604800,
    };
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.nyx.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(context.l10n.disappearingMessages,
                style: TextStyle(color: context.nyx.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ...options.entries.map((e) => ListTile(
                title: Text(e.key, style: TextStyle(color: context.nyx.textPrimary)),
                trailing: room.disappearAfterSeconds == e.value
                    ? Icon(Icons.check_rounded, color: context.nyx.accentBlue)
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
    final locale = Localizations.localeOf(context).toString();
    return sameDay ? DateFormat.Hm(locale).format(t) : DateFormat.MMMd(locale).add_Hm().format(t);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ChatService, PeerService, TrustStore>(
      builder: (context, chat, peers, trust, _) {
        final room = chat.room(widget.roomId);
        if (room == null) {
          return Scaffold(
              backgroundColor: context.nyx.background,
              body: Center(child: Text(context.l10n.conversationDeleted,
                  style: TextStyle(color: context.nyx.textSecondary))));
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
          backgroundColor: context.nyx.background,
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
                          return _system(localizeSystemMessage(context.l10n, m.content));
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
        ? (room.left ? context.l10n.membersCountLeft(room.memberCount) : context.l10n.membersCount(room.memberCount))
        : direct ? context.l10n.statusConnected : mesh ? context.l10n.statusReachableViaMesh : context.l10n.statusOfflineDeliverLater;
    final color = direct ? context.nyx.accentGreen : mesh ? context.nyx.accentBlue : context.nyx.textMuted;
    return Container(
      padding: EdgeInsetsDirectional.only(
          top: MediaQuery.of(context).padding.top + 6, start: 4, end: 8, bottom: 10),
      decoration: BoxDecoration(
        color: context.nyx.surface,
        border: Border(bottom: BorderSide(color: context.nyx.hairline(0.04))),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_rounded, color: context.nyx.textPrimary, size: 18),
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
                      style: TextStyle(color: context.nyx.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 6),
                Icon(verified ? Icons.verified_rounded : Icons.lock_outline_rounded,
                    size: 14, color: verified ? context.nyx.accentGreen : context.nyx.textMuted),
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
              color: room.disappearAfterSeconds > 0 ? context.nyx.accentBlue : context.nyx.textSecondary, size: 21),
        ),
        IconButton(
          onPressed: room.left ? null : _attach,
          icon: Icon(Icons.attach_file_rounded, color: context.nyx.textSecondary, size: 21),
        ),
      ]),
    );
  }

  Widget _empty(ChatRoom room) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 40, color: context.nyx.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(context.l10n.endToEndEncrypted, style: TextStyle(color: context.nyx.textSecondary)),
          const SizedBox(height: 4),
          Text(
            room.isGroup ? context.l10n.groupEncryptionHint
                         : context.l10n.directEncryptionHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.nyx.textMuted, fontSize: 12),
          ),
        ]),
      );

  Widget _system(String text) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: context.nyx.surfaceLight, borderRadius: BorderRadius.circular(12)),
            child: Text(text, style: TextStyle(color: context.nyx.textMuted, fontSize: 12)),
          ),
        ),
      );

  Widget _replyBar() => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 0),
        color: context.nyx.background,
        child: Row(children: [
          Container(width: 3, height: 32, color: context.nyx.accentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_replyTo!.content,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.nyx.textSecondary, fontSize: 13)),
          ),
          IconButton(
            onPressed: () => setState(() => _replyTo = null),
            icon: Icon(Icons.close_rounded, size: 18, color: context.nyx.textMuted),
          ),
        ]),
      );

  Widget _inputBar(ChatRoom room) => Container(
        padding: EdgeInsetsDirectional.only(start: 14, end: 8, top: 10, bottom: MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: context.nyx.background,
          border: Border(top: BorderSide(color: context.nyx.hairline(0.03))),
        ),
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.nyx.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.nyx.hairline(0.04)),
              ),
              padding: const EdgeInsetsDirectional.only(start: 16),
              child: TextField(
                controller: _input,
                enabled: !room.left,
                style: TextStyle(color: context.nyx.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: room.left ? context.l10n.noLongerMemberHint : context.l10n.messageHint,
                  hintStyle: TextStyle(color: context.nyx.textMuted),
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
          VoiceRecordButton(
            enabled: !room.left,
            onRecorded: _sendVoice,
            onError: _snack,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: room.left ? null : _send,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: context.nyx.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.nyx.hairline(0.06)),
              ),
              child: Icon(Icons.arrow_upward_rounded, color: context.nyx.textSecondary, size: 20),
            ),
          ),
        ]),
      );
}