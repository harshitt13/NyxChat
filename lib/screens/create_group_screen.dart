import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/identity_service.dart';
import '../services/chat_service.dart';
import '../services/peer_service.dart';
import '../models/chat_room.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _selectedPeerIds = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a group name'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_selectedPeerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one member'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final identity = context.read<IdentityService>().identity!;
    final peerService = context.read<PeerService>();
    final chatService = context.read<ChatService>();

    // Build member list including self
    final members = <GroupMember>[
      GroupMember(
        nyxChatId: identity.nyxChatId,
        displayName: identity.displayName,
        publicKeyHex: identity.publicKeyHex,
        isAdmin: true,
        joinedAt: DateTime.now(),
      ),
    ];

    for (final peerId in _selectedPeerIds) {
      final peer = peerService.peers[peerId];
      if (peer != null) {
        members.add(GroupMember(
          nyxChatId: peer.nyxChatId,
          displayName: peer.displayName,
          publicKeyHex: peer.publicKeyHex,
          joinedAt: DateTime.now(),
        ));
      }
    }

    final room = await chatService.createGroupChat(
      groupName: _nameController.text.trim(),
      members: members,
      myNyxChatId: identity.nyxChatId,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
    );

    if (mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(room: room)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary, size: 20),
        ),
        title: const Text('New Group',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isCreating ? null : _createGroup,
              child: _isCreating
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.accentBlue))
                  : const Text('Create',
                      style: TextStyle(
                          color: AppTheme.accentBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Group Info Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Icon(Icons.group_outlined,
                          color: AppTheme.textMuted, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 18),
                        decoration: const InputDecoration(
                          hintText: 'Group name',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          filled: false,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.04),
          ),

          // Members Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text('SELECT MEMBERS',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1)),
                const Spacer(),
                Text('${_selectedPeerIds.length} selected',
                    style: const TextStyle(
                        color: AppTheme.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // Peer List
          Expanded(
            child: Consumer<PeerService>(
              builder: (_, peerService, __) {
                final connectedPeers = peerService.connectedPeers;

                if (connectedPeers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('No connected peers',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text('Connect to peers first to add them',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: connectedPeers.length,
                  itemBuilder: (_, i) {
                    final peer = connectedPeers[i];
                    final isSelected =
                        _selectedPeerIds.contains(peer.nyxChatId);

                    return ListTile(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPeerIds.remove(peer.nyxChatId);
                          } else {
                            _selectedPeerIds.add(peer.nyxChatId);
                          }
                        });
                      },
                      leading: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentBlue.withValues(alpha: 0.2)
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: isSelected
                              ? Border.all(
                                  color: AppTheme.accentBlue, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: isSelected
                              ? const Icon(Icons.check_rounded,
                                  color: AppTheme.accentBlue, size: 22)
                              : Text(
                                  peer.displayName.isNotEmpty
                                      ? peer.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                      title: Text(peer.displayName,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                      subtitle: Text(peer.nyxChatId,
                          style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis),
                      trailing: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
