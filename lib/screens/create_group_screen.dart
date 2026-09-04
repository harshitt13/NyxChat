import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/storage/trust_store.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final Set<String> _selected = {};
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Give the group a name');
      return;
    }
    if (_selected.isEmpty) {
      _snack('Select at least one member');
      return;
    }
    setState(() => _busy = true);
    final trust = context.read<TrustStore>();
    final chat = context.read<ChatService>();
    final members = _selected.map(trust.get).whereType<PinnedPeer>().toList();
    final room = await chat.createGroup(
      name: name,
      members: members,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
    );
    if (!mounted) return;
    await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: room.id)));
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('New group', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _busy ? null : _create,
            child: const Text('Create', style: TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Consumer<TrustStore>(
        builder: (context, trust, _) {
          final contacts = trust.all..sort((a, b) => a.displayName.compareTo(b.displayName));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(_name, 'Group name', maxLength: 64),
              const SizedBox(height: 10),
              _field(_description, 'Description (optional)', maxLength: 200),
              const SizedBox(height: 20),
              Text('MEMBERS · ${_selected.length} selected',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const SizedBox(height: 8),
              if (contacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No contacts yet. Connect to someone first so their keys are pinned.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ),
              ...contacts.map((p) {
                final on = _selected.contains(p.nyxChatId);
                return InkWell(
                  onTap: () => setState(() => on ? _selected.remove(p.nyxChatId) : _selected.add(p.nyxChatId)),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: AppTheme.glassDecoration(
                        opacity: on ? 0.08 : 0.03,
                        borderRadius: 12,
                        borderColor: on ? AppTheme.accentBlue.withValues(alpha: 0.5) : null),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: Text(p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppTheme.accentBlue, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(p.displayName, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500))),
                            if (p.verified) ...[const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, size: 13, color: AppTheme.accentGreen)],
                          ]),
                          Text(p.nyxChatId, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace')),
                        ]),
                      ),
                      Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: on ? AppTheme.accentBlue : AppTheme.textMuted, size: 22),
                    ]),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {int? maxLength}) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          controller: c,
          maxLength: maxLength,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            border: InputBorder.none,
            counterText: '',
          ),
        ),
      );
}