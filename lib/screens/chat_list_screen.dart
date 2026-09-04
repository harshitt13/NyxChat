import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/network/connection_manager.dart';
import '../core/storage/outbox.dart';
import '../core/storage/trust_store.dart';
import '../l10n/l10n_context.dart';
import '../models/chat_room.dart';
import '../services/chat_service.dart';
import '../services/identity_service.dart';
import '../services/peer_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'contact_verify_screen.dart';
import 'create_group_screen.dart';
import 'emergency_screen.dart';
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
  final TextEditingController _search = TextEditingController();
  String _query = '';

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
        backgroundColor: context.nyx.surface,
        title: Text(context.l10n.safetyNumberChangedTitle,
            style: TextStyle(color: context.nyx.textPrimary)),
        content: Text(
          context.l10n.safetyNumberChangedBody(check.peer.displayName, check.peer.nyxChatId),
          style: TextStyle(color: context.nyx.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              connections.rejectKeyChange(check.peer.nyxChatId);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.keepBlocking),
          ),
          TextButton(
            onPressed: () async {
              await connections.acceptKeyChange(check.peer.nyxChatId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(context.l10n.acceptNewKeys,
                style: TextStyle(color: context.nyx.warning)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _keyChangeSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Container(
          decoration: BoxDecoration(
            color: context.nyx.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.nyx.hairline(0.05)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            style: TextStyle(color: context.nyx.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: context.l10n.searchConversationsHint,
              hintStyle: TextStyle(color: context.nyx.textMuted, fontSize: 13),
              border: InputBorder.none,
              icon: Icon(Icons.search_rounded, color: context.nyx.textMuted, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: context.nyx.textMuted),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nyx.background,
      appBar: _appBar(context),
      body: _body(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'group',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
            backgroundColor: context.nyx.surface,
            foregroundColor: context.nyx.textSecondary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.nyx.hairline(0.06)),
            ),
            child: const Icon(Icons.group_add_outlined, size: 20),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'discover',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PeerDiscoveryScreen())),
            backgroundColor: context.nyx.surfaceLight,
            foregroundColor: context.nyx.textPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: context.nyx.hairline(0.06)),
            ),
            child: const Icon(Icons.add_rounded, size: 26),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return AppBar(
      backgroundColor: context.nyx.background,
      elevation: 0,
      title: Text(context.l10n.appTitle,
          style: TextStyle(
              color: context.nyx.textPrimary,
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
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Row(
                children: [
                  if (pending > 0)
                    _chip(Icons.schedule_rounded, '$pending', context.nyx.warning),
                  _chip(Icons.wifi_rounded, '$direct',
                      direct > 0 ? context.nyx.accentGreen : context.nyx.textMuted),
                  const SizedBox(width: 6),
                  _chip(Icons.bluetooth_rounded, '$ble',
                      ble > 0 ? context.nyx.accentBlue : context.nyx.textMuted),
                ],
              ),
            );
          },
        ),
        IconButton(
          tooltip: context.l10n.emergencyBroadcastTitle,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyScreen())),
          icon: Icon(Icons.campaign_outlined, color: context.nyx.error, size: 22),
        ),
        IconButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          icon: Icon(Icons.settings_outlined,
              color: context.nyx.textSecondary, size: 22),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsetsDirectional.only(end: 4),
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
        final all = chat.chatRooms;
        final rooms = _query.isEmpty
            ? all
            : all.where((r) {
                if (r.peerDisplayName.toLowerCase().contains(_query)) return true;
                return chat.getMessages(r.id).any((m) => m.content.toLowerCase().contains(_query));
              }).toList();
        if (all.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined,
                    size: 52, color: context.nyx.textMuted.withValues(alpha: 0.4)),
                const SizedBox(height: 14),
                Text(context.l10n.noConversationsYet,
                    style: TextStyle(color: context.nyx.textSecondary, fontSize: 15)),
                const SizedBox(height: 6),
                Text(context.l10n.tapPlusToFindPeople,
                    style: TextStyle(color: context.nyx.textMuted, fontSize: 13)),
              ],
            ),
          );
        }
        final peers = context.read<PeerService>();
        return Column(children: [
          _searchBar(),
          if (rooms.isEmpty)
            Expanded(child: Center(child: Text(context.l10n.noMatches, style: TextStyle(color: context.nyx.textMuted))))
          else
          Expanded(child: ListView.separated(
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
        )),
        ]);
      },
    );
  }

  void _roomMenu(BuildContext context, ChatRoom room) {
    final chat = context.read<ChatService>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.nyx.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!room.isGroup)
            ListTile(
              leading: Icon(Icons.verified_user_outlined, color: context.nyx.accentBlue),
              title: Text(context.l10n.verifySafetyNumber, style: TextStyle(color: context.nyx.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ContactVerifyScreen(peerId: room.peerId)));
              },
            ),
          ListTile(
            leading: Icon(room.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                color: context.nyx.textSecondary),
            title: Text(room.muted ? context.l10n.unmute : context.l10n.mute, style: TextStyle(color: context.nyx.textPrimary)),
            onTap: () { chat.setMuted(room.id, !room.muted); Navigator.pop(ctx); },
          ),
          if (room.isGroup && !room.left)
            ListTile(
              leading: Icon(Icons.logout_rounded, color: context.nyx.warning),
              title: Text(context.l10n.leaveGroup, style: TextStyle(color: context.nyx.textPrimary)),
              onTap: () { chat.leaveGroup(room.id); Navigator.pop(ctx); },
            ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: context.nyx.error),
            title: Text(context.l10n.deleteConversation, style: TextStyle(color: context.nyx.error)),
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
        ? (room.isGroup ? context.l10n.membersCount(room.memberCount) : context.l10n.noMessagesYet)
        : (lastMessage.content as String);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: context.nyx.glass(opacity: 0.03, borderRadius: 14),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: context.nyx.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.nyx.hairline(0.06)),
              ),
              child: Center(
                child: room.isGroup
                    ? Icon(Icons.group_outlined, color: context.nyx.textMuted, size: 20)
                    : Text(room.displayInitials,
                        style: TextStyle(color: context.nyx.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            if (online != null)
              PositionedDirectional(
                end: 0, bottom: 0,
                child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    color: online! ? context.nyx.online : context.nyx.offline,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.nyx.background, width: 2),
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
                      style: TextStyle(color: context.nyx.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
                if (verified) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified_rounded, size: 14, color: context.nyx.accentGreen),
                ],
                if (room.disappearAfterSeconds > 0) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.timer_outlined, size: 13, color: context.nyx.textMuted),
                ],
              ]),
              const SizedBox(height: 3),
              Text(preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.nyx.textSecondary, fontSize: 13)),
            ]),
          ),
          if (room.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.nyx.accentBlue.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${room.unreadCount}',
                  style: TextStyle(color: context.nyx.accentBlue, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}