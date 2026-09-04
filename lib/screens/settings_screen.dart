import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants.dart';
import '../core/network/ble_manager.dart';
import '../services/identity_service.dart';
import '../services/peer_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'mesh_map_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Consumer4<IdentityService, SettingsService, PeerService, BleManager>(
        builder: (context, identity, settings, peers, ble, _) {
          final id = identity.identity;
          if (id == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _profile(context, identity),
              const SizedBox(height: 24),
              _title('Privacy'),
              _card([
                _toggle(Icons.screenshot_monitor_outlined, 'Block screenshots', settings.blockScreenshots, settings.setBlockScreenshots,
                    subtitle: 'Hides the app in recents and prevents screen capture'),
                _toggle(Icons.done_all_rounded, 'Send read receipts', settings.readReceipts, settings.setReadReceipts),
                _toggle(Icons.notifications_none_rounded, 'Notifications', settings.notifications, settings.setNotifications),
                _toggle(Icons.visibility_outlined, 'Show message text in notifications', settings.notificationPreview, settings.setNotificationPreview),
                _toggle(Icons.blur_on_rounded, 'Cover traffic', settings.dummyTraffic, settings.setDummyTraffic,
                    subtitle: 'Random mesh packets so idle and active periods look alike'),
                _toggle(Icons.visibility_off_outlined, 'Stealth mode', peers.isStealth, (v) => peers.setStealth(v),
                    subtitle: 'No advertising or scanning. Existing links stay up.'),
              ]),
              const SizedBox(height: 24),
              _title('Network'),
              _card([
                _row(Icons.wifi_rounded, 'Local network', peers.isNetworkActive ? 'Active' : 'Inactive',
                    color: peers.isNetworkActive ? AppTheme.accentGreen : AppTheme.textMuted),
                _row(Icons.people_alt_outlined, 'Direct links', '${peers.connectedPeers.length}'),
                _row(Icons.bluetooth_rounded, 'Bluetooth mesh',
                    !ble.isSupported ? 'Unsupported' : ble.isAdvertising ? 'Advertising · ${ble.linkCount} links' : ble.isScanning ? 'Scanning · ${ble.linkCount} links' : 'Off',
                    color: ble.isScanning || ble.isAdvertising ? AppTheme.accentGreen : AppTheme.textMuted),
                _toggle(Icons.settings_input_antenna_rounded, 'BLE long range (Coded PHY)', settings.longRangeBle, (v) async {
                  await settings.setLongRangeBle(v);
                  ble.setLongRange(v);
                }, subtitle: 'Bluetooth 5 S=8 coding; lower throughput, longer reach'),
                _row(Icons.router_rounded, 'Listening port', '${AppConstants.defaultPort}'),
                _row(Icons.language_rounded, 'Global DHT', peers.isDHTActive ? 'Active' : 'Inactive',
                    color: peers.isDHTActive ? AppTheme.accentGreen : AppTheme.textMuted),
                _nav(Icons.hub_outlined, 'Mesh diagnostics', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeshMapScreen()))),
              ]),
              const SizedBox(height: 24),
              _title('Internet delivery'),
              _card([
                _toggle(Icons.public_rounded, 'Deliver through public relays (Nostr)', settings.nostrEnabled, settings.setNostrEnabled,
                    subtitle: 'Sealed envelopes under rotating tokens on public Nostr relays. No account, no server of ours. Off by default.'),
                _toggle(Icons.shield_moon_outlined, 'Route relays through Tor (Orbot)', settings.nostrViaTor, settings.setNostrViaTor,
                    subtitle: 'Requires Orbot running with its HTTP proxy on 127.0.0.1:8118'),
              ]),
              const SizedBox(height: 24),
              _title('Security'),
              _card([
                _nav(Icons.lock_outline_rounded, 'App lock, duress password, panic wipe',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()))),
              ]),
              const SizedBox(height: 24),
              _title('About'),
              _card([
                _row(Icons.info_outline_rounded, 'Version', AppConstants.appVersion),
                _row(Icons.shield_outlined, 'Protocol', 'v${AppConstants.protocolVersion} · X25519+Kyber-768 · Double Ratchet · Sender Keys'),
                _row(Icons.code_rounded, 'License', 'GPL-3.0'),
              ]),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _profile(BuildContext context, IdentityService identity) {
    final id = identity.identity!;
    final card = identity.contactCard();
    final cardText = 'nyx3;${card['id']};${card['name']};${card['ik']};${card['sk']};${card['kpk']}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
            child: Center(child: Text(id.initials, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 20, fontWeight: FontWeight.w500))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(id.displayName, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w500))),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textMuted),
                onPressed: () => _rename(context, identity),
              ),
            ]),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: id.nyxChatId));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NyxChat ID copied')));
              },
              child: Text(id.nyxChatId, style: const TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontFamily: 'monospace')),
            ),
          ])),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: QrImageView(data: cardText, size: 180, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: cardText));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact card copied')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy contact card'),
        ),
        const Text('Share this so others can pin and verify your keys out of band.',
            textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ]),
    );
  }

  Future<void> _rename(BuildContext context, IdentityService identity) async {
    final ctrl = TextEditingController(text: identity.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Display name', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(controller: ctrl, maxLength: 64, style: const TextStyle(color: AppTheme.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await identity.updateDisplayName(name);
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t.toUpperCase(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: AppTheme.glassDecoration(opacity: 0.04, borderRadius: 14),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Divider(height: 1, color: Colors.white.withValues(alpha: 0.04)),
          ],
        ]),
      );

  Widget _toggle(IconData icon, String title, bool value, Future<void> Function(bool) onChanged, {String? subtitle}) =>
      SwitchListTile(
        secondary: Icon(icon, color: AppTheme.textSecondary, size: 20),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        value: value,
        activeThumbColor: AppTheme.accentBlue,
        onChanged: (v) => onChanged(v),
      );

  Widget _row(IconData icon, String title, String value, {Color color = AppTheme.textSecondary}) => ListTile(
        leading: Icon(icon, color: AppTheme.textSecondary, size: 20),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(value, textAlign: TextAlign.end, style: TextStyle(color: color, fontSize: 12)),
        ),
      );

  Widget _nav(IconData icon, String title, VoidCallback onTap) => ListTile(
        leading: Icon(icon, color: AppTheme.textSecondary, size: 20),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        onTap: onTap,
      );
}