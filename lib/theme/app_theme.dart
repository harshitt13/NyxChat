import 'package:flutter/material.dart';

class AppTheme {
  // ─── Core: Absolute Black ─────────────────────────────────────
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0A);
  static const Color surfaceLight = Color(0xFF141414);
  static const Color cardColor = Color(0xFF0F0F0F);

  // ─── Accents (muted and refined) ──────────────────────────────
  static const Color accentBlue = Color(0xFF4A9EFF);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentGreen = Color(0xFF34D399);

  // ─── Text (clean hierarchy) ───────────────────────────────────
  static const Color textPrimary = Color(0xFFE8E8E8);
  static const Color textSecondary = Color(0xFF737373);
  static const Color textMuted = Color(0xFF404040);

  // ─── Status ───────────────────────────────────────────────────
  static const Color online = Color(0xFF34D399);
  static const Color offline = Color(0xFF404040);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // ─── Gradients (subtle) ───────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF0A0A0A), Color(0xFF0F0F0F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient messageSentGradient = LinearGradient(
    colors: [Color(0xFF0F1A2E), Color(0xFF0A1628)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0xFF0A0A0A),
      Color(0xFF141414),
      Color(0xFF0A0A0A),
    ],
  );

  // ─── Borders ──────────────────────────────────────────────────
  static BoxDecoration glassDecoration({
    double opacity = 0.04,
    double borderRadius = 12,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.04),
        width: 0.5,
      ),
    );
  }

  static BoxDecoration glowDecoration({
    Color glowColor = accentBlue,
    double spread = 4,
    double blur = 12,
  }) {
    return BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.15),
          spreadRadius: spread,
          blurRadius: blur,
        ),
      ],
    );
  }

  // ─── Theme Data ───────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentPurple,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.04),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: surfaceLight,
        foregroundColor: textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: accentBlue.withValues(alpha: 0.4), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceLight,
          foregroundColor: textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: accentBlue,
        unselectedItemColor: textMuted,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.04),
        thickness: 0.5,
      ),
    );
  }
}
