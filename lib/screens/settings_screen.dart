import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/identity_service.dart';
import '../services/peer_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        title: const Text('Settings',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: Consumer<IdentityService>(
        builder: (context, identityService, _) {
          final identity = identityService.identity;
          if (identity == null) return const SizedBox.shrink();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Center(
                        child: Text(identity.initials,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 22,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(identity.displayName,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: identity.bitChatId));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Nyx ID copied!'),
                          backgroundColor: AppTheme.accentGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(identity.bitChatId,
                                style: const TextStyle(
                                    color: AppTheme.accentBlue,
                                    fontSize: 14,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy_rounded,
                                size: 16, color: AppTheme.accentBlue),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Network Status
              const Text('Network',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              Consumer<PeerService>(
                builder: (_, peerService, __) {
                  return Container(
                    decoration: AppTheme.glassDecoration(
                        opacity: 0.04, borderRadius: 14),
                    child: Column(
                      children: [
                        _settingsTile(
                          icon: Icons.wifi_rounded,
                          title: 'Network Status',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: peerService.isNetworkActive
                                  ? AppTheme.accentGreen
                                      .withValues(alpha: 0.15)
                                  : AppTheme.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              peerService.isNetworkActive
                                  ? 'Active'
                                  : 'Inactive',
                              style: TextStyle(
                                color: peerService.isNetworkActive
                                    ? AppTheme.accentGreen
                                    : AppTheme.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        _divider(),
                        _settingsTile(
                          icon: Icons.people_alt_rounded,
                          title: 'Connected Peers',
                          trailing: Text(
                            '${peerService.peerList.where((p) => peerService.isPeerConnected(p.bitChatId)).length}',
                            style: const TextStyle(
                                color: AppTheme.accentBlue,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        _divider(),
                        _settingsTile(
                          icon: Icons.router_rounded,
                          title: 'Listening Port',
                          trailing: const Text('42420',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontFamily: 'monospace')),
                        ),
                        _divider(),
                        _settingsTile(
                          icon: Icons.language_rounded,
                          title: 'Global DHT',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: peerService.isDHTActive
                                  ? AppTheme.accentGreen
                                      .withValues(alpha: 0.15)
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              peerService.isDHTActive
                                  ? 'Active'
                                  : 'Inactive',
                              style: TextStyle(
                                color: peerService.isDHTActive
                                    ? AppTheme.accentGreen
                                    : AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Security
              const Text('Security',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              Container(
                decoration: AppTheme.glassDecoration(
                    opacity: 0.04, borderRadius: 14),
                child: Column(
                  children: [
                    _settingsTile(
                      icon: Icons.vpn_key_rounded,
                      title: 'Public Key',
                      subtitle: '${identity.publicKeyHex.substring(0, 16)}...',
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: identity.publicKeyHex));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Public key copied!'),
                          backgroundColor: AppTheme.accentGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      },
                    ),
                    _divider(),
                    _settingsTile(
                      icon: Icons.enhanced_encryption_rounded,
                      title: 'Encryption',
                      trailing: const Text('AES-256-GCM',
                          style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                    _divider(),
                    _settingsTile(
                      icon: Icons.fingerprint_rounded,
                      title: 'Key Exchange',
                      trailing: const Text('X25519 ECDH',
                          style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                    _divider(),
                    _settingsTile(
                      icon: Icons.autorenew_rounded,
                      title: 'Forward Secrecy',
                      trailing: const Text('Active (Rotating)',
                          style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // About
              const Text('About',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
              const SizedBox(height: 10),
              Container(
                decoration: AppTheme.glassDecoration(
                    opacity: 0.04, borderRadius: 14),
                child: _settingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'NyxChat',
                  subtitle: 'v1.0.0 • Decentralized P2P Messaging',
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.accentBlue, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontFamily: 'monospace'))
          : null,
      trailing: trailing,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 70,
      color: Colors.white.withValues(alpha: 0.04),
    );
  }
}
