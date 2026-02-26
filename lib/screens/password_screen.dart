import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/app_lock_service.dart';
import '../services/identity_service.dart';
import '../theme/app_theme.dart';

class PasswordScreen extends StatefulWidget {
  final bool isSetupMode;
  
  const PasswordScreen({
    super.key, 
    this.isSetupMode = false,
  });

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Minimum 8 characters required';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Requires one uppercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Requires one number';
    if (!value.contains(RegExp(r'[!@#\$&*~]'))) return 'Requires one special symbol (!@#\$&*~)';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    if (widget.isSetupMode) {
      if (_formKey.currentState!.validate()) {
        if (_passwordController.text != _confirmController.text) {
          setState(() => _errorMessage = 'Passwords do not match');
          return;
        }

        setState(() => _isLoading = true);
        await context.read<AppLockService>().setupPassword(_passwordController.text);
        if (mounted) Navigator.pop(context); // Go back to Settings
      }
    } else {
      // Unlock Mode
      if (_passwordController.text.isEmpty) {
        setState(() => _errorMessage = 'Please enter your password');
        return;
      }

      setState(() => _isLoading = true);
      final success = await context.read<AppLockService>().unlock(_passwordController.text);
      
      if (!mounted) return;
      
      if (success) {
        // Databases are now unlocked — reload identity from storage
        await context.read<IdentityService>().init();
      } else {
         final lockService = context.read<AppLockService>();
         final attempts = lockService.failedAttempts;
         final wipe = lockService.wipeOnFailure;
         
         // After a panic wipe, failedAttempts resets to 0 and lock data is gone.
         // Check if we were wiped so we can show the appropriate message.
         if (wipe && attempts == 0) {
           // Panic wipe just happened — show a message briefly, then the
           // Consumer in main.dart will navigate to onboarding.
           setState(() {
             _isLoading = false;
             _errorMessage = 'All data has been wiped for security.';
             _passwordController.clear();
           });
         } else {
           setState(() {
             _isLoading = false;
             _errorMessage = 'Incorrect password. ${wipe ? '(${5 - attempts} attempts before wipe)' : ''}';
             _passwordController.clear();
           });
         }
      }
      // If success is true, main.dart's Consumer will rebuild and route them away automatically.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: widget.isSetupMode 
          ? AppBar(
              title: const Text('Set App Lock'),
              backgroundColor: AppTheme.background,
              elevation: 0,
            )
          : null, // No app bar for unlock screen
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isSetupMode) ...[
                  const Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: AppTheme.accentBlue,
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  const Text(
                    'NyxChat is Locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your password to decrypt the databases.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.key, color: AppTheme.textMuted),
                  ),
                  validator: widget.isSetupMode ? _validatePassword : null,
                  onFieldSubmitted: (_) => widget.isSetupMode ? null : _submit(),
                ),

                if (widget.isSetupMode) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.key, color: AppTheme.textMuted),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.error,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().shake(hz: 8, offset: const Offset(5, 0)),
                ],

                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.accentBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.isSetupMode ? 'Enable Lock' : 'Unlock & Decrypt',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
