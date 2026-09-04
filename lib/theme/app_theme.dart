import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colour roles of the NyxChat UI, resolved per theme.
///
/// Widgets read these through `context.nyx` instead of the static
/// [AppTheme] constants so that the light and dark palettes both work.
@immutable
class NyxColors extends ThemeExtension<NyxColors> {
  const NyxColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.cardColor,
    required this.accentBlue,
    required this.accentPurple,
    required this.accentPink,
    required this.accentGreen,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.online,
    required this.offline,
    required this.error,
    required this.warning,
    required this.overlay,
    required this.messageSentGradient,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color cardColor;
  final Color accentBlue;
  final Color accentPurple;
  final Color accentPink;
  final Color accentGreen;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color online;
  final Color offline;
  final Color error;
  final Color warning;

  /// Base colour of translucent hairlines and glass fills: white on the
  /// dark palette, black on the light one.
  final Color overlay;
  final LinearGradient messageSentGradient;

  bool get isDark => brightness == Brightness.dark;

  /// Translucent border/fill colour. Light surfaces need a slightly stronger
  /// tint than black does for the same visual weight.
  Color hairline(double alpha) =>
      overlay.withValues(alpha: (isDark ? alpha : alpha * 1.5).clamp(0.0, 1.0));

  /// Frosted card decoration used throughout the screens.
  BoxDecoration glass({
    double opacity = 0.04,
    double borderRadius = 12,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: isDark
          ? overlay.withValues(alpha: opacity)
          : Color.alphaBlend(overlay.withValues(alpha: opacity), surface),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? hairline(0.04),
        width: isDark ? 0.5 : 1,
      ),
    );
  }

  /// Absolute black with muted accents (the original NyxChat look).
  static const NyxColors dark = NyxColors(
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    surface: Color(0xFF0A0A0A),
    surfaceLight: Color(0xFF141414),
    cardColor: Color(0xFF0F0F0F),
    accentBlue: Color(0xFF4A9EFF),
    accentPurple: Color(0xFF8B5CF6),
    accentPink: Color(0xFFEC4899),
    accentGreen: Color(0xFF34D399),
    textPrimary: Color(0xFFE8E8E8),
    textSecondary: Color(0xFF737373),
    textMuted: Color(0xFF404040),
    online: Color(0xFF34D399),
    offline: Color(0xFF404040),
    error: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    overlay: Colors.white,
    messageSentGradient: LinearGradient(
      colors: [Color(0xFF0F1A2E), Color(0xFF0A1628)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// Near-white background, white surfaces, dark text; the accent hues are
  /// darkened so that every text colour reaches WCAG AA (4.5:1) on the
  /// background.
  static const NyxColors light = NyxColors(
    brightness: Brightness.light,
    background: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFECEEF2),
    cardColor: Color(0xFFFFFFFF),
    accentBlue: Color(0xFF1A66C9),
    accentPurple: Color(0xFF6D3DE8),
    accentPink: Color(0xFFC81E6E),
    accentGreen: Color(0xFF0B7A54),
    textPrimary: Color(0xFF15171C),
    textSecondary: Color(0xFF4A515E),
    textMuted: Color(0xFF676E7B),
    online: Color(0xFF0B7A54),
    offline: Color(0xFFB4BAC4),
    error: Color(0xFFC62828),
    warning: Color(0xFFA35400),
    overlay: Colors.black,
    messageSentGradient: LinearGradient(
      colors: [Color(0xFFE2EDFF), Color(0xFFD6E5FB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  @override
  NyxColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceLight,
    Color? cardColor,
    Color? accentBlue,
    Color? accentPurple,
    Color? accentPink,
    Color? accentGreen,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? online,
    Color? offline,
    Color? error,
    Color? warning,
    Color? overlay,
    LinearGradient? messageSentGradient,
  }) {
    return NyxColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      cardColor: cardColor ?? this.cardColor,
      accentBlue: accentBlue ?? this.accentBlue,
      accentPurple: accentPurple ?? this.accentPurple,
      accentPink: accentPink ?? this.accentPink,
      accentGreen: accentGreen ?? this.accentGreen,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      online: online ?? this.online,
      offline: offline ?? this.offline,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      overlay: overlay ?? this.overlay,
      messageSentGradient: messageSentGradient ?? this.messageSentGradient,
    );
  }

  @override
  NyxColors lerp(ThemeExtension<NyxColors>? other, double t) {
    if (other is! NyxColors) return this;
    return NyxColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      accentBlue: Color.lerp(accentBlue, other.accentBlue, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      accentPink: Color.lerp(accentPink, other.accentPink, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      online: Color.lerp(online, other.online, t)!,
      offline: Color.lerp(offline, other.offline, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      messageSentGradient: LinearGradient.lerp(
          messageSentGradient, other.messageSentGradient, t)!,
    );
  }
}

/// `context.nyx` resolves the palette of the active theme.
extension NyxThemeContext on BuildContext {
  NyxColors get nyx => Theme.of(this).extension<NyxColors>() ?? NyxColors.dark;
}
class AppTheme {
  // ─── Core: Absolute Black ─────────────────────────────────────
  // Static constants of the dark palette. Widgets should use `context.nyx`;
  // these remain for non-widget code and the default (dark) look.
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
  }) =>
      NyxColors.dark.glass(
          opacity: opacity, borderRadius: borderRadius, borderColor: borderColor);

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
  static ThemeData get darkTheme => _build(NyxColors.dark);
  static ThemeData get lightTheme => _build(NyxColors.light);

  /// Status and navigation bar icon colours that match a palette.
  static SystemUiOverlayStyle overlayStyle(NyxColors c) => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: c.brightness,
        systemNavigationBarColor: c.background,
        systemNavigationBarDividerColor: c.background,
        systemNavigationBarIconBrightness:
            c.isDark ? Brightness.light : Brightness.dark,
      );

  static ThemeData _build(NyxColors c) {
    final base = c.isDark ? const ColorScheme.dark() : const ColorScheme.light();
    final rounded10 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      colorScheme: base.copyWith(
        primary: c.accentBlue,
        onPrimary: Colors.white,
        secondary: c.accentPurple,
        onSecondary: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
        onSurfaceVariant: c.textSecondary,
        surfaceContainerHighest: c.surfaceLight,
        surfaceContainerHigh: c.surfaceLight,
        surfaceContainer: c.surface,
        outline: c.hairline(0.2),
        outlineVariant: c.hairline(0.08),
        error: c.error,
        onError: Colors.white,
      ),
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: c.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: c.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: TextStyle(
          color: c.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: TextStyle(
          color: c.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: c.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: c.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: c.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: c.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle(c),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: c.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: c.textPrimary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: c.cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.hairline(0.04)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
            fontFamily: 'Roboto', color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: TextStyle(
            fontFamily: 'Roboto', color: c.textSecondary, fontSize: 14, height: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.hairline(0.06)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceLight,
        contentTextStyle: TextStyle(fontFamily: 'Roboto', color: c.textPrimary, fontSize: 14),
        actionTextColor: c.accentBlue,
        shape: rounded10,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: c.textPrimary, fontSize: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.surfaceLight,
        foregroundColor: c.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.hairline(0.06)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceLight,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: c.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: c.accentBlue.withValues(alpha: 0.4), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accentBlue,
        selectionColor: c.accentBlue.withValues(alpha: 0.3),
        selectionHandleColor: c.accentBlue,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.surfaceLight,
          foregroundColor: c.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: c.hairline(0.06)),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accentBlue),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.hairline(0.1)),
          shape: rounded10,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.accentBlue : c.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? c.accentBlue.withValues(alpha: 0.35)
                : c.surfaceLight),
        trackOutlineColor: WidgetStateProperty.all(c.hairline(0.12)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.accentBlue : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: c.hairline(0.4), width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.accentBlue : c.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accentBlue.withValues(alpha: 0.2),
        checkmarkColor: c.accentBlue,
        labelStyle: TextStyle(color: c.textPrimary, fontSize: 12),
        side: BorderSide(color: c.hairline(0.06)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accentBlue,
        linearTrackColor: c.hairline(0.06),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.background,
        selectedItemColor: c.accentBlue,
        unselectedItemColor: c.textMuted,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: c.hairline(0.04),
        thickness: 0.5,
      ),
    );
  }
}