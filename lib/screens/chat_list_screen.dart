import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/identity_service.dart';
import '../services/chat_service.dart';
import '../services/peer_service.dart';
import '../models/chat_room.dart';
import 'chat_screen.dart';
import 'peer_discovery_screen.dart';
import 'create_group_screen.dart';
import 'settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );

    _initNetwork();
  }

  Future<void> _initNetwork() async {
    final identityService = context.read<IdentityService>();
    final peerService = context.read<PeerService>();
    final chatService = context.read<ChatService>();

    if (identityService.hasIdentity) {
      final id = identityService.identity!;
      final pubKey = await identityService.getPublicKeyHex();
      final signPubKey = await identityService.getSigningPublicKeyHex();

      // Start network
      await peerService.startNetwork(
        nyxChatId: id.nyxChatId,
        displayName: id.displayName,
        publicKeyHex: pubKey,
        signingPublicKeyHex: signPubKey,
      );

      // Init chat service
      await chatService.init(id.nyxChatId);
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'group',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              ),
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.textSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Icon(Icons.group_add_outlined, size: 20),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'discover',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PeerDiscoveryScreen()),
              ),
              backgroundColor: AppTheme.surfaceLight,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Icon(Icons.add_rounded, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.background,
      title: const Text(
        'NyxChat',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Consumer<PeerService>(
          builder: (_, peerService, __) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: peerService.isNetworkActive
                          ? AppTheme.accentGreen
                          : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    peerService.isNetworkActive ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: peerService.isNetworkActive
                          ? AppTheme.textSecondary
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(
            Icons.settings_outlined,
            color: AppTheme.textMuted,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<ChatService>(
      builder: (context, chatService, _) {
        final rooms = chatService.chatRooms;

        if (rooms.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            final messages = chatService.getMessages(room.id);
            final lastMessage = messages.isNotEmpty ? messages.last : null;

            return _ChatTile(
              room: room,
              lastMessageText: lastMessage?.content,
              lastMessageTime: lastMessage?.timestamp ?? room.createdAt,
              isOnline: context.read<PeerService>().isPeerConnected(room.peerId),
              onTap: () => _openChat(room),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 36,
            color: AppTheme.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'No conversations',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Discover peers to start chatting',
            style: TextStyle(
              color: AppTheme.textMuted.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PeerDiscoveryScreen(),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.surfaceLight,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: const Text(
              'Discover Peers',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(ChatRoom room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(room: room),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatRoom room;
  final String? lastMessageText;
  final DateTime lastMessageTime;
  final bool isOnline;
  final VoidCallback onTap;

  const _ChatTile({
    required this.room,
    this.lastMessageText,
    required this.lastMessageTime,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: room.isGroup
                        ? AppTheme.surfaceLight
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Center(
                    child: room.isGroup
                        ? Icon(Icons.group_outlined,
                            color: AppTheme.textMuted, size: 20)
                        : Text(
                            room.displayInitials,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentGreen,
                        border: Border.all(
                          color: AppTheme.background,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          room.peerDisplayName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(lastMessageTime),
                        style: TextStyle(
                          color: room.unreadCount > 0
                              ? AppTheme.accentBlue
                              : AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: room.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 12,
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lastMessageText ?? 'No messages yet',
                          style: TextStyle(
                            color: lastMessageText != null
                                ? AppTheme.textSecondary
                                : AppTheme.textMuted,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${room.unreadCount}',
                            style: const TextStyle(
                              color: AppTheme.accentBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('dd/MM').format(time);
    }
  }
}
