import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_context.dart';
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
      backgroundColor: context.nyx.background,
      appBar: AppBar(
        backgroundColor: context.nyx.background,
        elevation: 0,
        title: Text(context.l10n.security, style: TextStyle(color: context.nyx.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Consumer2<AppLockService, SettingsService>(
        builder: (context, lock, settings, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _title(context, context.l10n.databaseLock),
            _card(context, [
              SwitchListTile(
                secondary: Icon(Icons.lock_outline_rounded, color: context.nyx.textSecondary, size: 20),
                title: Text(context.l10n.requirePassword, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
                subtitle: Text(context.l10n.requirePasswordSubtitle,
                    style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
                value: lock.isLockEnabled,
                activeThumbColor: context.nyx.accentBlue,
                onChanged: (v) async {
                  if (v) {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordScreen(isSetupMode: true)));
                  } else {
                    await lock.setLockEnabled(false);
                  }
                },
              ),
              SwitchListTile(
                secondary: Icon(Icons.lock_clock_outlined, color: context.nyx.textSecondary, size: 20),
                title: Text(context.l10n.lockWhenInBackground, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
                value: settings.lockOnBackground,
                activeThumbColor: context.nyx.accentBlue,
                onChanged: lock.isLockEnabled ? (v) => settings.setLockOnBackground(v) : null,
              ),
              SwitchListTile(
                secondary: Icon(Icons.local_fire_department_outlined, color: context.nyx.textSecondary, size: 20),
                title: Text(context.l10n.wipeAfterFailedAttempts(AppLockService.maxFailedAttempts), style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
                value: lock.wipeOnFailure,
                activeThumbColor: context.nyx.accentBlue,
                onChanged: (v) => lock.setWipeOnFailure(v),
              ),
            ]),
            const SizedBox(height: 24),
            _title(context, context.l10n.duressPassword),
            _card(context, [
              ListTile(
                leading: Icon(Icons.theater_comedy_outlined, color: context.nyx.textSecondary, size: 20),
                title: Text(lock.hasDuressPassword ? context.l10n.duressPasswordSet : context.l10n.setADuressPassword,
                    style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
                subtitle: Text(
                  lock.hasDuressPassword
                      ? (lock.duressWipesReal ? context.l10n.duressOpensDecoyAndDestroys : context.l10n.duressOpensEmptyDecoy)
                      : context.l10n.duressExplanation,
                  style: TextStyle(color: context.nyx.textMuted, fontSize: 11),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: context.nyx.textMuted),
                enabled: lock.isLockEnabled,
                onTap: () => _duressDialog(context, lock),
              ),
              if (lock.hasDuressPassword)
                ListTile(
                  leading: Icon(Icons.delete_sweep_outlined, color: context.nyx.textSecondary, size: 20),
                  title: Text(context.l10n.removeDuressPassword, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
                  onTap: () => lock.setDuressPassword(null),
                ),
            ]),
            const SizedBox(height: 24),
            _title(context, context.l10n.identity),
            _card(context, [
              ListTile(
                leading: Icon(Icons.autorenew_rounded, color: context.nyx.textSecondary, size: 20),
                title: Text(context.l10n.rotateIdentityKeys, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
                subtitle: Text(context.l10n.rotateIdentitySubtitle,
                    style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
                onTap: () => _rotate(context),
              ),
            ]),
            const SizedBox(height: 24),
            _title(context, context.l10n.backup),
            _card(context, [
              ListTile(
                leading: Icon(Icons.save_alt_rounded, color: context.nyx.textSecondary, size: 20),
                title: Text(context.l10n.exportEncryptedBackup, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
                subtitle: Text(context.l10n.exportBackupSubtitle,
                    style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
                onTap: () => _exportBackup(context),
              ),
              ListTile(
                leading: Icon(Icons.restore_rounded, color: context.nyx.textSecondary, size: 20),
                title: Text(context.l10n.restoreFromBackup, style: TextStyle(color: context.nyx.textPrimary, fontSize: 14)),
                subtitle: Text(context.l10n.restoreBackupSubtitle,
                    style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
                onTap: () => _restoreBackup(context),
              ),
            ]),
            const SizedBox(height: 24),
            _title(context, context.l10n.dangerZone),
            _card(context, [
              ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: context.nyx.error, size: 20),
                title: Text(context.l10n.panicWipe, style: TextStyle(color: context.nyx.error, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(context.l10n.panicWipeSubtitle,
                    style: TextStyle(color: context.nyx.textMuted, fontSize: 11)),
                onTap: () => _confirmWipe(context),
              ),
            ]),
            const SizedBox(height: 24),
            Text(
              context.l10n.securityFooter,
              style: TextStyle(color: context.nyx.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askPassphrase(BuildContext context, String title, {bool confirm = false}) async {
    final a = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nyx.surface,
        title: Text(title, style: TextStyle(color: context.nyx.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: a, obscureText: true, autofocus: true, style: TextStyle(color: context.nyx.textPrimary),
              decoration: InputDecoration(hintText: context.l10n.passphraseHint)),
          if (confirm)
            TextField(controller: b, obscureText: true, style: TextStyle(color: context.nyx.textPrimary),
                decoration: InputDecoration(hintText: context.l10n.confirmPassphraseHint)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.continueAction)),
        ],
      ),
    );
    if (ok != true) return null;
    if (a.text.length < 8 || (confirm && a.text != b.text)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.passphraseTooShortOrMismatch)));
      }
      return null;
    }
    return a.text;
  }

  Future<void> _rotate(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nyx.surface,
        title: Text(context.l10n.rotateIdentityKeysQuestion, style: TextStyle(color: context.nyx.textPrimary)),
        content: Text(context.l10n.rotateIdentityWarning,
            style: TextStyle(color: context.nyx.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.rotate, style: TextStyle(color: context.nyx.warning))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await services.rotateIdentity();
      await SystemNavigator.pop();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.rotationFailed('$e'))));
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final pass = await _askPassphrase(context, context.l10n.backupPassphrase, confirm: true);
    if (pass == null || !context.mounted) return;
    try {
      final dialogTitle = context.l10n.saveBackupDialogTitle;
      final bytes = await services.backup.export(pass);
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle, fileName: 'nyxchat-backup-$stamp.nyxbk', bytes: Uint8List.fromList(bytes),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path == null ? context.l10n.backupCancelled : context.l10n.backupSaved)));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.backupFailed('$e'))));
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null || !context.mounted) return;
    final pass = await _askPassphrase(context, context.l10n.backupPassphrase);
    if (pass == null || !context.mounted) return;
    try {
      final backup = await services.backup.inspect(bytes, pass);
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.nyx.surface,
          title: Text(context.l10n.replaceThisProfile, style: TextStyle(color: context.nyx.warning)),
          content: Text(context.l10n.restoreConfirmBody('${backup['created']}', '${backup['displayName']}'),
              style: TextStyle(color: context.nyx.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.restore, style: TextStyle(color: context.nyx.warning))),
          ],
        ),
      );
      if (confirm != true) return;
      await services.backup.restore(backup);
      await SystemNavigator.pop();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.restoreFailed('$e'))));
    }
  }

  Future<void> _duressDialog(BuildContext context, AppLockService lock) async {
    final ctrl = TextEditingController();
    var wipes = lock.duressWipesReal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: context.nyx.surface,
          title: Text(context.l10n.duressPassword, style: TextStyle(color: context.nyx.textPrimary)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl, obscureText: true,
              style: TextStyle(color: context.nyx.textPrimary),
              decoration: InputDecoration(hintText: context.l10n.duressDifferentFromReal),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.alsoDestroyRealProfile, style: TextStyle(color: context.nyx.textPrimary, fontSize: 13)),
              value: wipes,
              activeThumbColor: context.nyx.error,
              onChanged: (v) => setState(() => wipes = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.save)),
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
        backgroundColor: context.nyx.surface,
        title: Text(context.l10n.wipeEverythingQuestion, style: TextStyle(color: context.nyx.error)),
        content: Text(
          context.l10n.wipeEverythingBody,
          style: TextStyle(color: context.nyx.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.wipe, style: TextStyle(color: context.nyx.error, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok == true) {
      await services.panicWipe();
      if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
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
}