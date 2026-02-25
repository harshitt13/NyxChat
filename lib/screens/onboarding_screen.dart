import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/identity_service.dart';
import 'package:provider/provider.dart';
import 'chat_list_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _isGenerating = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _generateIdentity() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a name'),
          backgroundColor: AppTheme.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    try {
      final identityService = context.read<IdentityService>();
      await identityService.generateIdentity(name);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatListScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Title
                const Text(
                  'NyxChat',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'peer-to-peer · encrypted',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(flex: 2),

                // Features — minimal
                _feature('No accounts — key-based identity'),
                const SizedBox(height: 10),
                _feature('End-to-end encrypted'),
                const SizedBox(height: 10),
                _feature('No servers — direct P2P'),

                const Spacer(flex: 2),

                // Name input
                TextField(
                  controller: _nameController,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Display name',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.accentBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _generateIdentity(),
                ),
                const SizedBox(height: 16),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isGenerating ? null : _generateIdentity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      foregroundColor: AppTheme.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    child: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppTheme.textSecondary,
                            ),
                          )
                        : const Text(
                            'Generate Identity',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your identity stays on your device',
                  style: TextStyle(
                    color: AppTheme.textMuted.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: AppTheme.textMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
