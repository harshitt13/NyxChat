import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/storage/trust_store.dart';
import '../models/chat_room.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'contact_verify_screen.dart';

/// Group members, admin actions, leave.
class GroupInfoScreen extends StatelessWidget {
  final String roomId;
  const GroupInfoScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatService, TrustStore>(
      builder: (context, chat, trust, _) {
        final room = chat.room(roomId);
        if (room == null) return const SizedBox.shrink();
        final me = chat.myId;
        final iAmAdmin = room.members.any((m) => m.nyxChatId == me && m.isAdmin);
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            elevation: 0,
            title: Text(room.peerDisplayName,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
            actions: [
              if (!room.left)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
                  onPressed: () => _rename(context, chat, room),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (room.groupDescription != null && room.groupDescription!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(room.groupDescription!, style: const TextStyle(color: AppTheme.textSecondary)),
                ),
              Text('${room.members.length} MEMBERS',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const SizedBox(height: 8),
              ...room.members.map((m) => _memberTile(context, chat, trust, room, m, me, iAmAdmin)),
              const SizedBox(height: 20),
              if (!room.left)
                _action(context, Icons.person_add_alt_1_outlined, 'Add members', AppTheme.accentBlue,
                    () => _addMembers(context, chat, trust, room)),
              if (!room.left)
                _action(context, Icons.logout_rounded, 'Leave group', AppTheme.warning, () async {
                  await chat.leaveGroup(room.id);
                  if (context.mounted) Navigator.pop(context);
                }),
              _action(context, Icons.delete_outline_rounded, 'Delete conversation', AppTheme.error, () async {
                await chat.deleteRoom(room.id);
                if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
              }),
              const SizedBox(height: 24),
              const Text(
                'Group messages are encrypted with per-member sender keys distributed over pairwise '
                'Double Ratchet sessions. Keys rotate whenever someone leaves.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _memberTile(BuildContext context, ChatService chat, TrustStore trust,
      ChatRoom room, GroupMember m, String me, bool iAmAdmin) {
    final isMe = m.nyxChatId == me;
    final verified = trust.isVerified(m.nyxChatId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
        child: Center(
          child: Text(m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w600)),
        ),
      ),
      title: Row(children: [
        Flexible(child: Text(isMe ? '${m.displayName} (you)' : m.displayName,
            overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14))),
        if (verified) ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, size: 13, color: AppTheme.accentGreen)],
      ]),
      subtitle: Text(m.nyxChatId, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (m.isAdmin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.accentPurple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: const Text('Admin', style: TextStyle(color: AppTheme.accentPurple, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        if (!isMe && iAmAdmin && !room.left)
          IconButton(
            icon: const Icon(Icons.person_remove_outlined, size: 18, color: AppTheme.textMuted),
            onPressed: () => chat.removeGroupMember(room.id, m.nyxChatId),
          ),
      ]),
      onTap: isMe || trust.get(m.nyxChatId) == null
          ? null
          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContactVerifyScreen(peerId: m.nyxChatId))),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: color, size: 20),
        title: Text(label, style: TextStyle(color: color, fontSize: 14)),
        onTap: onTap,
      );

  Future<void> _rename(BuildContext context, ChatService chat, ChatRoom room) async {
    final ctrl = TextEditingController(text: room.peerDisplayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Rename group', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(controller: ctrl, maxLength: 64, style: const TextStyle(color: AppTheme.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await chat.renameGroup(room.id, name);
  }

  Future<void> _addMembers(BuildContext context, ChatService chat, TrustStore trust, ChatRoom room) async {
    final current = room.members.map((m) => m.nyxChatId).toSet();
    final candidates = trust.all.where((p) => !current.contains(p.nyxChatId)).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No other known contacts')));
      return;
    }
    final selected = <PinnedPeer>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Add members', style: TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: candidates
                  .map((p) => CheckboxListTile(
                        value: selected.contains(p),
                        title: Text(p.displayName, style: const TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text(p.nyxChatId, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        onChanged: (v) => setState(() => v == true ? selected.add(p) : selected.remove(p)),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok == true && selected.isNotEmpty) await chat.addGroupMembers(room.id, selected.toList());
  }
}