import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/ble_manager.dart';
import '../core/storage/trust_store.dart';
import '../models/peer.dart';
import '../services/chat_service.dart';
import '../services/peer_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'contact_verify_screen.dart';
import 'emergency_screen.dart';
import 'scan_card_screen.dart';

/// Find people: LAN discovery, Bluetooth neighbours, pinned contacts,
/// manual connection, contact-card import and the experimental DHT.
class PeerDiscoveryScreen extends StatefulWidget {
  const PeerDiscoveryScreen({super.key});
  @override
  State<PeerDiscoveryScreen> createState() => _PeerDiscoveryScreenState();
}

class _PeerDiscoveryScreenState extends State<PeerDiscoveryScreen> {
  final _address = TextEditingController();
  final _port = TextEditingController(text: '42420');
  final _card = TextEditingController();
  final _lookup = TextEditingController();
  final _bootstrap = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_address, _port, _card, _lookup, _bootstrap]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String t, {Color color = AppTheme.surface}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t), backgroundColor: color, behavior: SnackBarBehavior.floating,
      ));

  Future<void> _openChat(String peerId, String name) async {
    final room = await context.read<ChatService>().getOrCreateDirectRoom(peerId: peerId, displayName: name);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(roomId: room.id)));
  }

  Future<void> _manualConnect() async {
    final addr = _address.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 42420;
    if (addr.isEmpty) return;
    setState(() => _busy = true);
    final ok = await context.read<PeerService>().connectToPeer(address: addr, port: port);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(ok ? 'Connected and authenticated' : 'Connection failed (unreachable, refused, or key mismatch)',
        color: ok ? AppTheme.accentGreen.withValues(alpha: 0.3) : AppTheme.error.withValues(alpha: 0.3));
  }

  Future<void> _scanCard() async {
    final peer = await Navigator.push<PinnedPeer?>(context, MaterialPageRoute(builder: (_) => const ScanCardScreen()));
    if (peer != null && mounted) {
      _snack('Pinned and verified ${peer.displayName}', color: AppTheme.accentGreen.withValues(alpha: 0.3));
      await context.read<PeerService>().refreshBeacons();
    }
  }

  Future<void> _importCard() async {
    final raw = _card.text.trim();
    if (raw.isEmpty) return;
    try {
      final card = parseContactCard(raw);
      if (card == null) throw const FormatException('unrecognised format');
      final peer = await context.read<TrustStore>().pinFromContactCard(card, verified: true);
      if (mounted) await context.read<PeerService>().refreshBeacons();
      _card.clear();
      _snack('Pinned and verified ${peer.displayName}', color: AppTheme.accentGreen.withValues(alpha: 0.3));
    } catch (e) {
      _snack('Invalid contact card: $e', color: AppTheme.error.withValues(alpha: 0.3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('Find people', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Consumer3<PeerService, TrustStore, BleManager>(
        builder: (context, peers, trust, ble, _) {
          final nearby = peers.peerList.where((p) => !p.ipAddress.startsWith('ble://')).toList()
            ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
          final contacts = trust.all..sort((a, b) => a.displayName.compareTo(b.displayName));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _status(peers, ble),
              const SizedBox(height: 12),
              Consumer<SettingsService>(
                builder: (_, settings, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible to everyone nearby', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  subtitle: Text(
                    settings.discoverableToEveryone
                        ? 'Your ID and name are broadcast so new people can find you.'
                        : 'Private beacons: only pinned contacts can recognise you; others see random noise.',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  value: settings.discoverableToEveryone,
                  activeThumbColor: AppTheme.accentBlue,
                  onChanged: (v) => settings.setDiscoverableToEveryone(v),
                ),
              ),
              Row(children: [
                Expanded(child: _button('Scan contact QR', _scanCard)),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyScreen())),
                    icon: const Icon(Icons.campaign_rounded, size: 16, color: AppTheme.error),
                    label: const Text('Emergency', style: TextStyle(color: AppTheme.error)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.error.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              _section('Nearby on Wi-Fi'),
              if (nearby.isEmpty) _hint('Nobody discovered yet. Peers on the same Wi-Fi appear here automatically.'),
              ...nearby.map((p) => _peerTile(p, peers, trust)),
              const SizedBox(height: 18),
              _section('Bluetooth mesh'),
              if (!ble.isSupported) _hint('Bluetooth LE is not available on this device.'),
              if (ble.isSupported && ble.links.isEmpty && ble.discoveredPeers.isEmpty)
                _hint('Scanning${ble.isAdvertising ? ' and advertising' : ''}. Other NyxChat devices within range will link automatically.'),
              ...ble.links.map((l) => _bleTile(l.nyxId ?? l.address, 'linked · ${l.isCentralRole ? 'central' : 'peripheral'} · MTU ${l.mtu}', true)),
              ...ble.discoveredPeers.where((d) => ble.linkForNyxId(d.nyxId ?? '') == null)
                  .map((d) => _bleTile(d.nyxId ?? d.deviceName, '${d.rssi} dBm', false)),
              const SizedBox(height: 18),
              _section('Contacts'),
              if (contacts.isEmpty) _hint('Keys of every peer you connect to are pinned here.'),
              ...contacts.map((c) => _contactTile(c, peers)),
              const SizedBox(height: 18),
              _section('Add contact from card'),
              _hint('Paste the text of a contact card (shown as QR in Verify). This pins and verifies their keys.'),
              _input(_card, 'nyx3;NC-...;name;...', maxLines: 3),
              const SizedBox(height: 8),
              _button('Import card', _importCard),
              const SizedBox(height: 18),
              _section('Manual connection'),
              Row(children: [
                Expanded(flex: 3, child: _input(_address, 'IP address')),
                const SizedBox(width: 8),
                Expanded(child: _input(_port, 'Port')),
              ]),
              const SizedBox(height: 8),
              _button(_busy ? 'Connecting...' : 'Connect', _busy ? null : _manualConnect),
              const SizedBox(height: 18),
              _section('Global directory (DHT, experimental)'),
              _hint('Needs a reachable bootstrap node. Announcements are signed; the handshake still decides trust.'),
              Row(children: [
                Expanded(child: Text(peers.isDHTActive ? 'Running · ${peers.dhtNode?.knownPeersCount ?? 0} nodes' : 'Stopped',
                    style: TextStyle(color: peers.isDHTActive ? AppTheme.accentGreen : AppTheme.textMuted, fontSize: 13))),
                TextButton(
                  onPressed: () => peers.isDHTActive ? peers.stopDHT() : peers.startDHT(),
                  child: Text(peers.isDHTActive ? 'Stop' : 'Start'),
                ),
              ]),
              if (peers.isDHTActive) ...[
                Row(children: [
                  Expanded(child: _input(_bootstrap, 'bootstrap host:port')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () {
                    if (_bootstrap.text.contains(':')) {
                      peers.addBootstrapNode(_bootstrap.text.trim());
                      _bootstrap.clear();
                      _snack('Bootstrap node added');
                    }
                  }, child: const Text('Add')),
                ]),
                Row(children: [
                  Expanded(child: _input(_lookup, 'NC-... to look up')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () async {
                    final p = await peers.lookupGlobalPeer(_lookup.text.trim());
                    if (!mounted) return;
                    _snack(p == null ? 'Not found' : 'Found ${p.displayName} at ${p.ipAddress}:${p.port}');
                  }, child: const Text('Find')),
                ]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _status(PeerService peers, BleManager ble) => Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassDecoration(opacity: 0.04, borderRadius: 14),
        child: Row(children: [
          _stat(Icons.wifi_rounded, peers.isNetworkActive ? 'LAN on' : 'LAN off', peers.isNetworkActive),
          _stat(Icons.bluetooth_rounded, ble.isAdvertising ? 'BLE on' : ble.isScanning ? 'BLE scan' : 'BLE off', ble.isScanning || ble.isAdvertising),
          _stat(Icons.hub_outlined, '${peers.bleLinkCount} links', peers.bleLinkCount > 0),
          _stat(Icons.visibility_off_outlined, peers.isStealth ? 'stealth' : 'visible', !peers.isStealth),
        ]),
      );

  Widget _stat(IconData icon, String label, bool on) => Expanded(
        child: Column(children: [
          Icon(icon, size: 18, color: on ? AppTheme.accentGreen : AppTheme.textMuted),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: on ? AppTheme.textPrimary : AppTheme.textMuted, fontSize: 11)),
        ]),
      );

  Widget _peerTile(Peer p, PeerService peers, TrustStore trust) {
    final connected = peers.isPeerConnected(p.nyxChatId);
    final pinned = trust.get(p.nyxChatId);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassDecoration(opacity: 0.03, borderRadius: 12),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: connected ? AppTheme.online : AppTheme.offline, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.displayName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            Text('${p.nyxChatId} · ${p.ipAddress}:${p.port}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ]),
        ),
        if (!connected)
          TextButton(onPressed: () => peers.connectToKnownPeer(p.nyxChatId), child: const Text('Connect'))
        else if (pinned != null)
          IconButton(icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.accentBlue, size: 20),
              onPressed: () => _openChat(p.nyxChatId, pinned.displayName)),
      ]),
    );
  }

  Widget _bleTile(String title, String subtitle, bool linked) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.glassDecoration(opacity: 0.03, borderRadius: 12),
        child: Row(children: [
          Icon(Icons.bluetooth_rounded, size: 18, color: linked ? AppTheme.accentBlue : AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace')),
            Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ])),
        ]),
      );

  Widget _contactTile(PinnedPeer c, PeerService peers) {
    final reachable = peers.isPeerConnected(c.nyxChatId) || peers.isReachableByMesh(c.nyxChatId);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassDecoration(opacity: 0.03, borderRadius: 12),
      child: Row(children: [
        Icon(c.verified ? Icons.verified_rounded : Icons.person_outline_rounded, size: 18,
            color: c.verified ? AppTheme.accentGreen : AppTheme.textMuted),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.displayName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          Text('${c.nyxChatId} · ${reachable ? 'reachable' : 'offline, queued delivery'}',
              style: TextStyle(color: reachable ? AppTheme.accentGreen : AppTheme.textMuted, fontSize: 11)),
        ])),
        IconButton(icon: const Icon(Icons.verified_user_outlined, color: AppTheme.textSecondary, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContactVerifyScreen(peerId: c.nyxChatId)))),
        IconButton(icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.accentBlue, size: 20),
            onPressed: () => _openChat(c.nyxChatId, c.displayName)),
      ]),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t.toUpperCase(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      );

  Widget _hint(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4)),
      );

  Widget _input(TextEditingController c, String hint, {int maxLines = 1}) => Container(
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: c, maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppTheme.textMuted, fontFamily: 'monospace'), border: InputBorder.none),
        ),
      );

  Widget _button(String label, VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label),
        ),
      );
}