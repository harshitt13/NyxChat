import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/ble_manager.dart';
import '../core/storage/trust_store.dart';
import '../l10n/l10n_context.dart';
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

  void _snack(String t, {Color? color}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t), backgroundColor: color ?? context.nyx.surface, behavior: SnackBarBehavior.floating,
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
    _snack(ok ? context.l10n.connectedAndAuthenticated : context.l10n.connectionFailed,
        color: ok ? context.nyx.accentGreen.withValues(alpha: 0.3) : context.nyx.error.withValues(alpha: 0.3));
  }

  Future<void> _scanCard() async {
    final peer = await Navigator.push<PinnedPeer?>(context, MaterialPageRoute(builder: (_) => const ScanCardScreen()));
    if (peer != null && mounted) {
      _snack(context.l10n.pinnedAndVerified(peer.displayName), color: context.nyx.accentGreen.withValues(alpha: 0.3));
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
      if (!mounted) return;
      await context.read<PeerService>().refreshBeacons();
      if (!mounted) return;
      _card.clear();
      _snack(context.l10n.pinnedAndVerified(peer.displayName), color: context.nyx.accentGreen.withValues(alpha: 0.3));
    } catch (e) {
      if (!mounted) return;
      _snack(context.l10n.invalidContactCard('$e'), color: context.nyx.error.withValues(alpha: 0.3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nyx.background,
      appBar: AppBar(
        backgroundColor: context.nyx.background,
        elevation: 0,
        title: Text(context.l10n.findPeople, style: TextStyle(color: context.nyx.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
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
                  title: Text(context.l10n.visibleToEveryoneNearby, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
                  subtitle: Text(
                    settings.discoverableToEveryone
                        ? context.l10n.visibleSubtitlePublic
                        : context.l10n.visibleSubtitlePrivate,
                    style: TextStyle(color: context.nyx.textMuted, fontSize: 11),
                  ),
                  value: settings.discoverableToEveryone,
                  activeThumbColor: context.nyx.accentBlue,
                  onChanged: (v) => settings.setDiscoverableToEveryone(v),
                ),
              ),
              Row(children: [
                Expanded(child: _button(context.l10n.scanContactQr, _scanCard)),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyScreen())),
                    icon: Icon(Icons.campaign_rounded, size: 16, color: context.nyx.error),
                    label: Text(context.l10n.emergency, style: TextStyle(color: context.nyx.error)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: context.nyx.error.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              _section(context.l10n.nearbyOnWifi),
              if (nearby.isEmpty) _hint(context.l10n.nobodyDiscoveredYet),
              ...nearby.map((p) => _peerTile(p, peers, trust)),
              const SizedBox(height: 18),
              _section(context.l10n.bluetoothMesh),
              if (!ble.isSupported) _hint(context.l10n.bleNotAvailable),
              if (ble.isSupported && ble.links.isEmpty && ble.discoveredPeers.isEmpty)
                _hint(ble.isAdvertising ? context.l10n.bleScanningAdvertisingHint : context.l10n.bleScanningHint),
              ...ble.links.map((l) => _bleTile(l.nyxId ?? l.address, context.l10n.bleLinkedSubtitle(l.isCentralRole ? context.l10n.roleCentral : context.l10n.rolePeripheral, l.mtu), true)),
              ...ble.discoveredPeers.where((d) => ble.linkForNyxId(d.nyxId ?? '') == null)
                  .map((d) => _bleTile(d.nyxId ?? d.deviceName, context.l10n.rssiDbm(d.rssi), false)),
              const SizedBox(height: 18),
              _section(context.l10n.contacts),
              if (contacts.isEmpty) _hint(context.l10n.contactsPinnedHint),
              ...contacts.map((c) => _contactTile(c, peers)),
              const SizedBox(height: 18),
              _section(context.l10n.addContactFromCard),
              _hint(context.l10n.pasteContactCardHint),
              _input(_card, 'nyx3;NC-...;name;...', maxLines: 3),
              const SizedBox(height: 8),
              _button(context.l10n.importCard, _importCard),
              const SizedBox(height: 18),
              _section(context.l10n.manualConnection),
              Row(children: [
                Expanded(flex: 3, child: _input(_address, context.l10n.ipAddressHint)),
                const SizedBox(width: 8),
                Expanded(child: _input(_port, context.l10n.portHint)),
              ]),
              const SizedBox(height: 8),
              _button(_busy ? context.l10n.connecting : context.l10n.connect, _busy ? null : _manualConnect),
              const SizedBox(height: 18),
              _section(context.l10n.globalDirectory),
              _hint(context.l10n.dhtHint),
              Row(children: [
                Expanded(child: Text(peers.isDHTActive ? context.l10n.dhtRunning(peers.dhtNode?.knownPeersCount ?? 0) : context.l10n.stopped,
                    style: TextStyle(color: peers.isDHTActive ? context.nyx.accentGreen : context.nyx.textMuted, fontSize: 13))),
                TextButton(
                  onPressed: () => peers.isDHTActive ? peers.stopDHT() : peers.startDHT(),
                  child: Text(peers.isDHTActive ? context.l10n.stop : context.l10n.start),
                ),
              ]),
              if (peers.isDHTActive) ...[
                Row(children: [
                  Expanded(child: _input(_bootstrap, context.l10n.bootstrapHint)),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () {
                    if (_bootstrap.text.contains(':')) {
                      peers.addBootstrapNode(_bootstrap.text.trim());
                      _bootstrap.clear();
                      _snack(context.l10n.bootstrapNodeAdded);
                    }
                  }, child: Text(context.l10n.add)),
                ]),
                Row(children: [
                  Expanded(child: _input(_lookup, context.l10n.lookupHint)),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () async {
                    final p = await peers.lookupGlobalPeer(_lookup.text.trim());
                    if (!context.mounted) return;
                    _snack(p == null ? context.l10n.notFound : context.l10n.foundPeerAt(p.displayName, '${p.ipAddress}:${p.port}'));
                  }, child: Text(context.l10n.find)),
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
        decoration: context.nyx.glass(opacity: 0.04, borderRadius: 14),
        child: Row(children: [
          _stat(Icons.wifi_rounded, peers.isNetworkActive ? context.l10n.lanOn : context.l10n.lanOff, peers.isNetworkActive),
          _stat(Icons.bluetooth_rounded, ble.isAdvertising ? context.l10n.bleOn : ble.isScanning ? context.l10n.bleScan : context.l10n.bleOff, ble.isScanning || ble.isAdvertising),
          _stat(Icons.hub_outlined, context.l10n.linksCount(peers.bleLinkCount), peers.bleLinkCount > 0),
          _stat(Icons.visibility_off_outlined, peers.isStealth ? context.l10n.stealth : context.l10n.visible, !peers.isStealth),
        ]),
      );

  Widget _stat(IconData icon, String label, bool on) => Expanded(
        child: Column(children: [
          Icon(icon, size: 18, color: on ? context.nyx.accentGreen : context.nyx.textMuted),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: on ? context.nyx.textPrimary : context.nyx.textMuted, fontSize: 11)),
        ]),
      );

  Widget _peerTile(Peer p, PeerService peers, TrustStore trust) {
    final connected = peers.isPeerConnected(p.nyxChatId);
    final pinned = trust.get(p.nyxChatId);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: context.nyx.glass(opacity: 0.03, borderRadius: 12),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: connected ? context.nyx.online : context.nyx.offline, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.displayName, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            Text('${p.nyxChatId} · ${p.ipAddress}:${p.port}', style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
          ]),
        ),
        if (!connected)
          TextButton(onPressed: () => peers.connectToKnownPeer(p.nyxChatId), child: Text(context.l10n.connect))
        else if (pinned != null)
          IconButton(icon: Icon(Icons.chat_bubble_outline_rounded, color: context.nyx.accentBlue, size: 20),
              onPressed: () => _openChat(p.nyxChatId, pinned.displayName)),
      ]),
    );
  }

  Widget _bleTile(String title, String subtitle, bool linked) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: context.nyx.glass(opacity: 0.03, borderRadius: 12),
        child: Row(children: [
          Icon(Icons.bluetooth_rounded, size: 18, color: linked ? context.nyx.accentBlue : context.nyx.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: context.nyx.textPrimary, fontSize: 13, fontFamily: 'monospace')),
            Text(subtitle, style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
          ])),
        ]),
      );

  Widget _contactTile(PinnedPeer c, PeerService peers) {
    final reachable = peers.isPeerConnected(c.nyxChatId) || peers.isReachableByMesh(c.nyxChatId);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: context.nyx.glass(opacity: 0.03, borderRadius: 12),
      child: Row(children: [
        Icon(c.verified ? Icons.verified_rounded : Icons.person_outline_rounded, size: 18,
            color: c.verified ? context.nyx.accentGreen : context.nyx.textMuted),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.displayName, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          Text('${c.nyxChatId} · ${reachable ? context.l10n.reachable : context.l10n.offlineQueued}',
              style: TextStyle(color: reachable ? context.nyx.accentGreen : context.nyx.textMuted, fontSize: 11)),
        ])),
        IconButton(icon: Icon(Icons.verified_user_outlined, color: context.nyx.textSecondary, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContactVerifyScreen(peerId: c.nyxChatId)))),
        IconButton(icon: Icon(Icons.chat_bubble_outline_rounded, color: context.nyx.accentBlue, size: 20),
            onPressed: () => _openChat(c.nyxChatId, c.displayName)),
      ]),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t.toUpperCase(), style: TextStyle(color: context.nyx.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      );

  Widget _hint(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(color: context.nyx.textMuted, fontSize: 12, height: 1.4)),
      );

  Widget _input(TextEditingController c, String hint, {int maxLines = 1}) => Container(
        decoration: BoxDecoration(color: context.nyx.surface, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.nyx.hairline(0.06))),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: c, maxLines: maxLines,
          style: TextStyle(color: context.nyx.textPrimary, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: context.nyx.textMuted, fontFamily: 'monospace'), border: InputBorder.none),
        ),
      );

  Widget _button(String label, VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.nyx.textPrimary,
            side: BorderSide(color: context.nyx.hairline(0.1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label),
        ),
      );
}