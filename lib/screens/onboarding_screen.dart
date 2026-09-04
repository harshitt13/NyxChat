import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
      _snack('Enter a display name (max 64 characters)');
      return;
    }
    setState(() => _busy = true);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await context.read<IdentityService>().generateIdentity(name);
      unawaited(services.bringUp());
    } catch (e) {
      _snack('Could not create identity: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: AppTheme.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(children: [
            const Spacer(flex: 3),
            const Text('NyxChat',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text('peer-to-peer · encrypted · offline-capable',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, letterSpacing: 0.3)),
            const Spacer(flex: 2),
            _feature(Icons.lock_outline_rounded, 'End-to-end encrypted',
                'Double Ratchet with a hybrid X25519 + Kyber-768 handshake'),
            _feature(Icons.bluetooth_rounded, 'Works without internet',
                'Wi-Fi LAN and Bluetooth mesh, store-and-forward delivery'),
            _feature(Icons.cloud_off_rounded, 'No servers, no accounts',
                'Your identity is a key pair that never leaves this device'),
            const Spacer(flex: 2),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _name,
                enabled: !_busy,
                maxLength: 64,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Display name',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
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
                  backgroundColor: AppTheme.surfaceLight,
                  foregroundColor: AppTheme.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue))
                    : const Text('Create identity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Generates X25519, Ed25519 and Kyber-768 keys locally. Nothing is uploaded.',
                textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
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
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppTheme.accentBlue, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ]),
          ),
        ]),
      );
}