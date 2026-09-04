import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/network/connection_manager.dart';
import '../core/storage/outbox.dart';
import '../core/storage/trust_store.dart';
import '../models/chat_room.dart';
import '../services/chat_service.dart';
import '../services/identity_service.dart';
import '../services/peer_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'contact_verify_screen.dart';
import 'create_group_screen.dart';
import 'peer_discovery_screen.dart';
import 'settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  StreamSubscription<TrustCheck>? _keyChangeSub;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    final identity = context.read<IdentityService>();
    final peers = context.read<PeerService>();
    final connections = context.read<ConnectionManager>();
    if (Platform.isAndroid || Platform.isIOS) {
      await [
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.nearbyWifiDevices,
        Permission.notification,
      ].request();
    }
    if (!mounted || !identity.hasIdentity) return;
    _keyChangeSub = connections.onKeyChange.listen(_onKeyChange);
    await peers.startNetwork(
      nyxChatId: identity.nyxChatId,
      displayName: identity.displayName,
    );
    if (await peers.wasDHTActive()) await peers.startDHT();
  }

  void _onKeyChange(TrustCheck check) {
    if (!mounted) return;
    final connections = context.read<ConnectionManager>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Safety number changed',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '${check.peer.displayName} (${check.peer.nyxChatId}) is presenting '
          'different identity keys than the ones you have pinned.\n\n'
          'This happens when they reinstalled the app, or if someone is '
          'impersonating them. Verify the new safety number in person '
          'before accepting. The connection stays blocked until you decide.',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              connections.rejectKeyChange(check.peer.nyxChatId);
              Navigator.pop(ctx);
            },
            child: const Text('Keep blocking'),
          ),
          TextButton(
            onPressed: () async {
              await connections.acceptKeyChange(check.peer.nyxChatId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Accept new keys',
                style: TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _keyChangeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _appBar(context),
      body: _body(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'group',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
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
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PeerDiscoveryScreen())),
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
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      title: const Text('NyxChat',
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3)),
      actions: [
        Consumer2<PeerService, Outbox>(
          builder: (_, peers, outbox, _) {
            final direct = peers.connectedPeers.length;
            final ble = peers.bleLinkCount;
            final pending = outbox.length;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  if (pending > 0)
                    _chip(Icons.schedule_rounded, '$pending', AppTheme.warning),
                  _chip(Icons.wifi_rounded, '$direct',
                      direct > 0 ? AppTheme.accentGreen : AppTheme.textMuted),
                  const SizedBox(width: 6),
                  _chip(Icons.bluetooth_rounded, '$ble',
                      ble > 0 ? AppTheme.accentBlue : AppTheme.textMuted),
                ],
              ),
            );
          },
        ),
        IconButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: const Icon(Icons.settings_outlined,
              color: AppTheme.textSecondary, size: 22),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _body() {
    return Consumer2<ChatService, TrustStore>(
      builder: (context, chat, trust, _) {
        final rooms = chat.chatRooms;
        if (rooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined,
                    size: 52, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                const SizedBox(height: 14),
                const Text('No conversations yet',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                const SizedBox(height: 6),
                const Text('Tap + to find people nearby',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ],
            ),
          );
        }
        final peers = context.read<PeerService>();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          itemCount: rooms.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _RoomTile(
            room: rooms[i],
            online: rooms[i].isGroup
                ? null
                : peers.isPeerConnected(rooms[i].peerId) ||
                    peers.isReachableByMesh(rooms[i].peerId),
            verified: !rooms[i].isGroup && trust.isVerified(rooms[i].peerId),
            lastMessage: chat.getMessages(rooms[i].id).lastOrNull,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ChatScreen(roomId: rooms[i].id))),
            onLongPress: () => _roomMenu(context, rooms[i]),
          ),
        );
      },
    );
  }

  void _roomMenu(BuildContext context, ChatRoom room) {
    final chat = context.read<ChatService>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!room.isGroup)
            ListTile(
              leading: const Icon(Icons.verified_user_outlined, color: AppTheme.accentBlue),
              title: const Text('Verify safety number', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ContactVerifyScreen(peerId: room.peerId)));
              },
            ),
          ListTile(
            leading: Icon(room.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                color: AppTheme.textSecondary),
            title: Text(room.muted ? 'Unmute' : 'Mute', style: const TextStyle(color: AppTheme.textPrimary)),
            onTap: () { chat.setMuted(room.id, !room.muted); Navigator.pop(ctx); },
          ),
          if (room.isGroup && !room.left)
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.warning),
              title: const Text('Leave group', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () { chat.leaveGroup(room.id); Navigator.pop(ctx); },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
            title: const Text('Delete conversation', style: TextStyle(color: AppTheme.error)),
            onTap: () { chat.deleteRoom(room.id); Navigator.pop(ctx); },
          ),
        ]),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final ChatRoom room;
  final bool? online;
  final bool verified;
  final dynamic lastMessage;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RoomTile({
    required this.room,
    required this.online,
    required this.verified,
    required this.lastMessage,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final preview = lastMessage == null
        ? (room.isGroup ? '${room.memberCount} members' : 'No messages yet')
        : (lastMessage.content as String);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.glassDecoration(opacity: 0.03, borderRadius: 14),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Center(
                child: room.isGroup
                    ? const Icon(Icons.group_outlined, color: AppTheme.textMuted, size: 20)
                    : Text(room.displayInitials,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            if (online != null)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    color: online! ? AppTheme.online : AppTheme.offline,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.background, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(room.peerDisplayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
                if (verified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, size: 14, color: AppTheme.accentGreen),
                ],
                if (room.disappearAfterSeconds > 0) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.timer_outlined, size: 13, color: AppTheme.textMuted),
                ],
              ]),
              const SizedBox(height: 3),
              Text(preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ]),
          ),
          if (room.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${room.unreadCount}',
                  style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}