import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'At least 8 characters';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final lock = context.read<AppLockService>();
    if (widget.isSetupMode) {
      if (!_formKey.currentState!.validate()) return;
      if (_password.text != _confirm.text) {
        setState(() => _error = 'Passwords do not match');
        return;
      }
      setState(() => _busy = true);
      await lock.setupPassword(_password.text);
      if (mounted) Navigator.pop(context, true);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password');
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
          ? 'All data has been wiped.'
          : 'Incorrect password${lock.wipeOnFailure ? ' · ${lock.attemptsRemaining} attempts left before wipe' : ''}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: widget.isSetupMode
          ? AppBar(title: const Text('Set app lock'), backgroundColor: AppTheme.background, elevation: 0)
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
                  const Icon(Icons.lock_rounded, size: 44, color: AppTheme.accentBlue),
                  const SizedBox(height: 16),
                  const Text('NyxChat is locked',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Your database is encrypted. Enter your password to unlock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 28),
                ] else ...[
                  const Text(
                    'The database key will be wrapped with a key derived from this password using Argon2id. '
                    'There is no recovery: a forgotten password means the data is gone.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofocus: true,
                  enabled: !_busy,
                  validator: widget.isSetupMode ? _validate : null,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _decoration('Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textMuted, size: 20),
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
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: _decoration('Confirm password'),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
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
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue))
                        : Text(widget.isSetupMode ? 'Enable lock' : 'Unlock',
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
        hintStyle: const TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.accentBlue)),
      );
}