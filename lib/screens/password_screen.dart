import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_context.dart';
import '../main.dart';
import '../services/app_lock_service.dart';
import '../services/identity_service.dart';
import '../theme/app_theme.dart';

/// Unlock screen (default) or password setup (isSetupMode).
class PasswordScreen extends StatefulWidget {
  final bool isSetupMode;
  const PasswordScreen({super.key, this.isSetupMode = false});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    if (v == null || v.isEmpty) return context.l10n.passwordRequired;
    if (v.length < 8) return context.l10n.atLeast8Characters;
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final lock = context.read<AppLockService>();
    if (widget.isSetupMode) {
      if (!_formKey.currentState!.validate()) return;
      if (_password.text != _confirm.text) {
        setState(() => _error = context.l10n.passwordsDoNotMatch);
        return;
      }
      setState(() => _busy = true);
      await lock.setupPassword(_password.text);
      if (mounted) Navigator.pop(context, true);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = context.l10n.enterYourPassword);
      return;
    }
    setState(() => _busy = true);
    final ok = await lock.unlock(_password.text);
    if (!mounted) return;
    if (ok) {
      await context.read<IdentityService>().init(decoy: lock.isDecoyProfile);
      await services.bringUp();
      return;
    }
    final wiped = lock.wipeOnFailure && lock.failedAttempts == 0 && !lock.isLockEnabled;
    setState(() {
      _busy = false;
      _password.clear();
      _error = wiped
          ? context.l10n.allDataWiped
          : lock.wipeOnFailure
              ? context.l10n.incorrectPasswordAttemptsLeft(lock.attemptsRemaining)
              : context.l10n.incorrectPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nyx.background,
      appBar: widget.isSetupMode
          ? AppBar(title: Text(context.l10n.setAppLock), backgroundColor: context.nyx.background, elevation: 0)
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isSetupMode) ...[
                  Icon(Icons.lock_rounded, size: 44, color: context.nyx.accentBlue),
                  const SizedBox(height: 16),
                  Text(context.l10n.nyxChatIsLocked,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.nyx.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(context.l10n.unlockPrompt,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.nyx.textSecondary, fontSize: 13)),
                  const SizedBox(height: 28),
                ] else ...[
                  Text(
                    context.l10n.passwordSetupExplanation,
                    style: TextStyle(color: context.nyx.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofocus: true,
                  enabled: !_busy,
                  validator: widget.isSetupMode ? _validate : null,
                  style: TextStyle(color: context.nyx.textPrimary),
                  decoration: _decoration(context.l10n.passwordHint).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: context.nyx.textMuted, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onFieldSubmitted: (_) => widget.isSetupMode ? null : _submit(),
                ),
                if (widget.isSetupMode) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    enabled: !_busy,
                    style: TextStyle(color: context.nyx.textPrimary),
                    decoration: _decoration(context.l10n.confirmPasswordHint),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center,
                      style: TextStyle(color: context.nyx.error, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
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
                        ? SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: context.nyx.accentBlue))
                        : Text(widget.isSetupMode ? context.l10n.enableLock : context.l10n.unlock,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.nyx.textMuted),
        filled: true,
        fillColor: context.nyx.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.nyx.hairline(0.06))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.nyx.accentBlue)),
      );
}