import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/storage/trust_store.dart';
import '../l10n/l10n_context.dart';
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
      _snack(context.l10n.giveGroupAName);
      return;
    }
    if (_selected.isEmpty) {
      _snack(context.l10n.selectAtLeastOneMember);
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
        backgroundColor: context.nyx.surface,
        behavior: SnackBarBehavior.floating,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nyx.background,
      appBar: AppBar(
        backgroundColor: context.nyx.background,
        elevation: 0,
        title: Text(context.l10n.newGroup, style: TextStyle(color: context.nyx.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _busy ? null : _create,
            child: Text(context.l10n.create, style: TextStyle(color: context.nyx.accentBlue, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Consumer<TrustStore>(
        builder: (context, trust, _) {
          final contacts = trust.all..sort((a, b) => a.displayName.compareTo(b.displayName));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(_name, context.l10n.groupNameHint, maxLength: 64),
              const SizedBox(height: 10),
              _field(_description, context.l10n.descriptionOptionalHint, maxLength: 200),
              const SizedBox(height: 20),
              Text(context.l10n.membersSelectedHeader(_selected.length).toUpperCase(),
                  style: TextStyle(color: context.nyx.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const SizedBox(height: 8),
              if (contacts.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(context.l10n.noContactsYet,
                      style: TextStyle(color: context.nyx.textMuted, fontSize: 13)),
                ),
              ...contacts.map((p) {
                final on = _selected.contains(p.nyxChatId);
                return InkWell(
                  onTap: () => setState(() => on ? _selected.remove(p.nyxChatId) : _selected.add(p.nyxChatId)),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: context.nyx.glass(
                        opacity: on ? 0.08 : 0.03,
                        borderRadius: 12,
                        borderColor: on ? context.nyx.accentBlue.withValues(alpha: 0.5) : null),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: context.nyx.surfaceLight, borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: Text(p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?',
                              style: TextStyle(color: context.nyx.accentBlue, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(p.displayName, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.nyx.textPrimary, fontSize: 14, fontWeight: FontWeight.w500))),
                            if (p.verified) ...[const SizedBox(width: 6),
                              Icon(Icons.verified_rounded, size: 13, color: context.nyx.accentGreen)],
                          ]),
                          Text(p.nyxChatId, style: TextStyle(color: context.nyx.textMuted, fontSize: 11, fontFamily: 'monospace')),
                        ]),
                      ),
                      Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: on ? context.nyx.accentBlue : context.nyx.textMuted, size: 22),
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
          color: context.nyx.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.nyx.hairline(0.06)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          controller: c,
          maxLength: maxLength,
          style: TextStyle(color: context.nyx.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.nyx.textMuted),
            border: InputBorder.none,
            counterText: '',
          ),
        ),
      );
}