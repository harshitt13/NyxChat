import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_context.dart';
import '../main.dart';
import '../services/identity_service.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 64) {
      _snack(context.l10n.enterDisplayName);
      return;
    }
    setState(() => _busy = true);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await context.read<IdentityService>().generateIdentity(name);
      unawaited(services.bringUp());
    } catch (e) {
      if (mounted) _snack(context.l10n.couldNotCreateIdentity('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: context.nyx.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nyx.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(flex: 3),
            Text(context.l10n.appTitle,
                style: TextStyle(color: context.nyx.textPrimary, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(context.l10n.tagline,
                style: TextStyle(color: context.nyx.textSecondary, fontSize: 13, letterSpacing: 0.3)),
            const Spacer(flex: 2),
            _feature(Icons.lock_outline_rounded, context.l10n.endToEndEncrypted,
                context.l10n.featureE2eSubtitle),
            _feature(Icons.bluetooth_rounded, context.l10n.featureOfflineTitle,
                context.l10n.featureOfflineSubtitle),
            _feature(Icons.cloud_off_rounded, context.l10n.featureNoServersTitle,
                context.l10n.featureNoServersSubtitle),
            const Spacer(flex: 2),
            Container(
              decoration: BoxDecoration(
                color: context.nyx.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.nyx.hairline(0.06)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _name,
                enabled: !_busy,
                maxLength: 64,
                style: TextStyle(color: context.nyx.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: context.l10n.displayName,
                  hintStyle: TextStyle(color: context.nyx.textMuted),
                  border: InputBorder.none,
                  counterText: '',
                ),
                onSubmitted: (_) => _create(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nyx.surfaceLight,
                  foregroundColor: context.nyx.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: context.nyx.hairline(0.08)),
                  ),
                ),
                child: _busy
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.nyx.accentBlue))
                    : Text(context.l10n.createIdentity, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.keysGeneratedLocally,
                textAlign: TextAlign.center, style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
            const Spacer(),
          ]),
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String title, String subtitle) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: context.nyx.surface, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: context.nyx.accentBlue, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: context.nyx.textSecondary, fontSize: 12)),
            ]),
          ),
        ]),
      );
}