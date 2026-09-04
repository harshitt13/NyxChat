import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/constants.dart';
import '../core/network/ble_manager.dart';
import '../l10n/l10n_context.dart';
import '../l10n/language_names.dart';
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
      backgroundColor: context.nyx.background,
      appBar: AppBar(
        backgroundColor: context.nyx.background,
        elevation: 0,
        title: Text(context.l10n.settings, style: TextStyle(color: context.nyx.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
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
              _title(context, context.l10n.appearance),
              _card(context, [
                _nav(context, Icons.brightness_6_outlined, context.l10n.theme, () => _pickTheme(context, settings),
                    value: _themeName(context, settings.themeMode)),
                _nav(context, Icons.translate_rounded, context.l10n.language, () => _pickLanguage(context, settings),
                    value: settings.locale == null ? context.l10n.languageSystemDefault : languageNameOf(settings.locale!)),
              ]),
              const SizedBox(height: 24),
              _title(context, context.l10n.privacy),
              _card(context, [
                _toggle(context, Icons.screenshot_monitor_outlined, context.l10n.blockScreenshots, settings.blockScreenshots, settings.setBlockScreenshots,
                    subtitle: context.l10n.blockScreenshotsSubtitle),
                _toggle(context, Icons.done_all_rounded, context.l10n.sendReadReceipts, settings.readReceipts, settings.setReadReceipts),
                _toggle(context, Icons.notifications_none_rounded, context.l10n.notifications, settings.notifications, settings.setNotifications),
                _toggle(context, Icons.visibility_outlined, context.l10n.showMessageTextInNotifications, settings.notificationPreview, settings.setNotificationPreview),
                _toggle(context, Icons.blur_on_rounded, context.l10n.coverTraffic, settings.dummyTraffic, settings.setDummyTraffic,
                    subtitle: context.l10n.coverTrafficSubtitle),
                _toggle(context, Icons.visibility_off_outlined, context.l10n.stealthMode, peers.isStealth, (v) => peers.setStealth(v),
                    subtitle: context.l10n.stealthModeSubtitle),
              ]),
              const SizedBox(height: 24),
              _title(context, context.l10n.network),
              _card(context, [
                _row(context, Icons.wifi_rounded, context.l10n.localNetwork, peers.isNetworkActive ? context.l10n.active : context.l10n.inactive,
                    color: peers.isNetworkActive ? context.nyx.accentGreen : context.nyx.textMuted),
                _row(context, Icons.people_alt_outlined, context.l10n.directLinks, '${peers.connectedPeers.length}'),
                _row(context, Icons.bluetooth_rounded, context.l10n.bluetoothMesh,
                    !ble.isSupported ? context.l10n.unsupported : ble.isAdvertising ? context.l10n.advertisingLinks(ble.linkCount) : ble.isScanning ? context.l10n.scanningLinks(ble.linkCount) : context.l10n.off,
                    color: ble.isScanning || ble.isAdvertising ? context.nyx.accentGreen : context.nyx.textMuted),
                _toggle(context, Icons.settings_input_antenna_rounded, context.l10n.bleLongRange, settings.longRangeBle, (v) async {
                  await settings.setLongRangeBle(v);
                  ble.setLongRange(v);
                }, subtitle: context.l10n.bleLongRangeSubtitle),
                _row(context, Icons.wifi_tethering_rounded, context.l10n.wifiAware, peers.awareManager.statusText,
                    color: peers.isAwareActive ? context.nyx.accentGreen : context.nyx.textMuted),
                _toggle(context, Icons.podcasts_rounded, context.l10n.useWifiAware, settings.wifiAware, (v) async {
                  await settings.setWifiAware(v);
                  await peers.applyAwareSetting();
                }, subtitle: context.l10n.useWifiAwareSubtitle),
                _row(context, Icons.router_rounded, context.l10n.listeningPort, '${AppConstants.defaultPort}'),
                _row(context, Icons.language_rounded, context.l10n.globalDht, peers.isDHTActive ? context.l10n.active : context.l10n.inactive,
                    color: peers.isDHTActive ? context.nyx.accentGreen : context.nyx.textMuted),
                _nav(context, Icons.hub_outlined, context.l10n.meshDiagnostics, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeshMapScreen()))),
              ]),
              const SizedBox(height: 24),
              _title(context, context.l10n.internetDelivery),
              _card(context, [
                _toggle(context, Icons.public_rounded, context.l10n.deliverThroughRelays, settings.nostrEnabled, settings.setNostrEnabled,
                    subtitle: context.l10n.deliverThroughRelaysSubtitle),
                _toggle(context, Icons.shield_moon_outlined, context.l10n.routeThroughTor, settings.nostrViaTor, settings.setNostrViaTor,
                    subtitle: context.l10n.routeThroughTorSubtitle),
              ]),
              const SizedBox(height: 24),
              _title(context, context.l10n.security),
              _card(context, [
                _nav(context, Icons.lock_outline_rounded, context.l10n.appLockDuressPanic,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()))),
              ]),
              const SizedBox(height: 24),
              _title(context, context.l10n.about),
              _card(context, [
                _row(context, Icons.info_outline_rounded, context.l10n.version, AppConstants.appVersion),
                _row(context, Icons.shield_outlined, context.l10n.protocol, context.l10n.protocolValue(AppConstants.protocolVersion)),
                _row(context, Icons.code_rounded, context.l10n.license, 'GPL-3.0'),
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
        color: context.nyx.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.nyx.hairline(0.04)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: context.nyx.surfaceLight, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.nyx.hairline(0.06))),
            child: Center(child: Text(id.initials, style: TextStyle(color: context.nyx.textSecondary, fontSize: 20, fontWeight: FontWeight.w500))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(id.displayName, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.nyx.textPrimary, fontSize: 17, fontWeight: FontWeight.w500))),
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 16, color: context.nyx.textMuted),
                onPressed: () => _rename(context, identity),
              ),
            ]),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: id.nyxChatId));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.nyxChatIdCopied)));
              },
              child: Text(id.nyxChatId, style: TextStyle(color: context.nyx.accentBlue, fontSize: 13, fontFamily: 'monospace')),
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.contactCardCopied)));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(context.l10n.copyContactCard),
        ),
        Text(context.l10n.shareContactCardHint,
            textAlign: TextAlign.center, style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
      ]),
    );
  }

  Future<void> _rename(BuildContext context, IdentityService identity) async {
    final ctrl = TextEditingController(text: identity.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nyx.surface,
        title: Text(context.l10n.displayName, style: TextStyle(color: context.nyx.textPrimary)),
        content: TextField(controller: ctrl, maxLength: 64, style: TextStyle(color: context.nyx.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(context.l10n.save)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await identity.updateDisplayName(name);
  }

  Widget _title(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t.toUpperCase(), style: TextStyle(color: context.nyx.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
      );

  Widget _card(BuildContext context, List<Widget> children) => Container(
        decoration: context.nyx.glass(opacity: 0.04, borderRadius: 14),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Divider(height: 1, color: context.nyx.hairline(0.04)),
          ],
        ]),
      );

  Widget _toggle(BuildContext context, IconData icon, String title, bool value, Future<void> Function(bool) onChanged, {String? subtitle}) =>
      SwitchListTile(
        secondary: Icon(icon, color: context.nyx.textSecondary, size: 20),
        title: Text(title, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
        subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
        value: value,
        activeThumbColor: context.nyx.accentBlue,
        onChanged: (v) => onChanged(v),
      );

  Widget _row(BuildContext context, IconData icon, String title, String value, {Color? color}) => ListTile(
        leading: Icon(icon, color: context.nyx.textSecondary, size: 20),
        title: Text(title, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(value, textAlign: TextAlign.end, style: TextStyle(color: color ?? context.nyx.textSecondary, fontSize: 12)),
        ),
      );

  Widget _nav(BuildContext context, IconData icon, String title, VoidCallback onTap, {String? value}) => ListTile(
        leading: Icon(icon, color: context.nyx.textSecondary, size: 20),
        title: Text(title, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value != null) Text(value, style: TextStyle(color: context.nyx.textSecondary, fontSize: 12)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: context.nyx.textMuted),
        ]),
        onTap: onTap,
      );

  String _themeName(BuildContext context, ThemeMode mode) => switch (mode) {
        ThemeMode.system => context.l10n.themeSystem,
        ThemeMode.light => context.l10n.themeLight,
        ThemeMode.dark => context.l10n.themeDark,
      };

  void _pickTheme(BuildContext context, SettingsService settings) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.nyx.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final mode in ThemeMode.values)
            ListTile(
              leading: Icon(
                  switch (mode) {
                    ThemeMode.system => Icons.brightness_auto_outlined,
                    ThemeMode.light => Icons.light_mode_outlined,
                    ThemeMode.dark => Icons.dark_mode_outlined,
                  },
                  color: context.nyx.textSecondary),
              title: Text(_themeName(context, mode), style: TextStyle(color: context.nyx.textPrimary)),
              trailing: settings.themeMode == mode ? Icon(Icons.check_rounded, color: context.nyx.accentBlue) : null,
              onTap: () {
                settings.setThemeMode(mode);
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    );
  }

  void _pickLanguage(BuildContext context, SettingsService settings) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.nyx.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          _localeTile(context, ctx, settings, null, context.l10n.languageSystemDefault),
          for (final locale in kSupportedUiLocales) _localeTile(context, ctx, settings, locale, languageNameOf(locale)),
        ]),
      ),
    );
  }

  Widget _localeTile(BuildContext context, BuildContext sheet, SettingsService settings, Locale? locale, String name) {
    final selected = settings.locale?.languageCode == locale?.languageCode;
    return ListTile(
      title: Text(name, style: TextStyle(color: context.nyx.textPrimary)),
      trailing: selected ? Icon(Icons.check_rounded, color: context.nyx.accentBlue) : null,
      onTap: () {
        settings.setLocale(locale);
        Navigator.pop(sheet);
      },
    );
  }
}