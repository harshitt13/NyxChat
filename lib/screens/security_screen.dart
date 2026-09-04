import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/app_lock_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'password_screen.dart';

/// App lock, duress password and destructive actions.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('Security', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Consumer2<AppLockService, SettingsService>(
        builder: (context, lock, settings, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _title('Database lock'),
            _card([
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary, size: 20),
                title: const Text('Require password', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                subtitle: const Text('Argon2id-wrapped database key. No recovery if forgotten.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                value: lock.isLockEnabled,
                activeThumbColor: AppTheme.accentBlue,
                onChanged: (v) async {
                  if (v) {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordScreen(isSetupMode: true)));
                  } else {
                    await lock.setLockEnabled(false);
                  }
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.lock_clock_outlined, color: AppTheme.textSecondary, size: 20),
                title: const Text('Lock when in background', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                value: settings.lockOnBackground,
                activeThumbColor: AppTheme.accentBlue,
                onChanged: lock.isLockEnabled ? (v) => settings.setLockOnBackground(v) : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.local_fire_department_outlined, color: AppTheme.textSecondary, size: 20),
                title: const Text('Wipe after 5 failed attempts', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                value: lock.wipeOnFailure,
                activeThumbColor: AppTheme.accentBlue,
                onChanged: (v) => lock.setWipeOnFailure(v),
              ),
            ]),
            const SizedBox(height: 24),
            _title('Duress password'),
            _card([
              ListTile(
                leading: const Icon(Icons.theater_comedy_outlined, color: AppTheme.textSecondary, size: 20),
                title: Text(lock.hasDuressPassword ? 'Duress password set' : 'Set a duress password',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                subtitle: Text(
                  lock.hasDuressPassword
                      ? (lock.duressWipesReal ? 'Opens a decoy profile and destroys the real one' : 'Opens an empty decoy profile')
                      : 'Entering it at the lock screen opens an empty decoy profile',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                enabled: lock.isLockEnabled,
                onTap: () => _duressDialog(context, lock),
              ),
              if (lock.hasDuressPassword)
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined, color: AppTheme.textSecondary, size: 20),
                  title: const Text('Remove duress password', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  onTap: () => lock.setDuressPassword(null),
                ),
            ]),
            const SizedBox(height: 24),
            _title('Danger zone'),
            _card([
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
                title: const Text('Panic wipe', style: TextStyle(color: AppTheme.error, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Destroys messages, contacts, sessions and identity keys. Irreversible.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                onTap: () => _confirmWipe(context),
              ),
            ]),
            const SizedBox(height: 24),
            const Text(
              'Keys live in the Android keystore-backed secure storage. The message database is AES-256 encrypted '
              'with a random master key; with a password enabled that key is additionally wrapped with '
              'AES-256-GCM under an Argon2id-derived key (32 MiB, 2 passes).',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duressDialog(BuildContext context, AppLockService lock) async {
    final ctrl = TextEditingController();
    var wipes = lock.duressWipesReal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Duress password', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl, obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(hintText: 'Different from your real password'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Also destroy the real profile', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
              value: wipes,
              activeThumbColor: AppTheme.error,
              onChanged: (v) => setState(() => wipes = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && ctrl.text.length >= 4) {
      await lock.setDuressPassword(ctrl.text, wipesReal: wipes);
    }
  }

  Future<void> _confirmWipe(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Wipe everything?', style: TextStyle(color: AppTheme.error)),
        content: const Text(
          'All messages, contacts, sessions and your identity keys will be destroyed on this device. '
          'Peers will see a key change the next time you meet.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Wipe', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true) {
      await services.panicWipe();
      if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
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
}