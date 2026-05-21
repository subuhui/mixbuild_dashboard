import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MixBuildPalette {
  static const background = Color(0xFF0C0C0C);
  static const surface = Color(0xFF131313);
  static const surfaceLow = Color(0xFF1B1B1C);
  static const surfaceHigh = Color(0xFF2A2A2A);
  static const surfaceHighest = Color(0xFF353535);
  static const foreground = Color(0xFFE5E2E1);
  static const muted = Color(0xFFC0C6D6);
  static const primary = Color(0xFF0A84FF);
  static const primarySoft = Color(0x331EA1FF);
  static const tertiary = Color(0xFFEB6A12);
  static const success = Color(0xFF45D483);
  static const warning = Color(0xFFFFB55E);
  static const error = Color(0xFFFF6B6B);
}

class MixBuildTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: MixBuildPalette.foreground,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: MixBuildPalette.foreground,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: MixBuildPalette.foreground,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: MixBuildPalette.foreground,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 17,
        color: MixBuildPalette.foreground,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 15,
        color: MixBuildPalette.foreground,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: MixBuildPalette.muted,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 13,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: MixBuildPalette.foreground,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: MixBuildPalette.background,
      colorScheme: const ColorScheme.dark(
        primary: MixBuildPalette.primary,
        secondary: MixBuildPalette.tertiary,
        surface: MixBuildPalette.surface,
        error: MixBuildPalette.error,
      ),
      textTheme: textTheme,
      dividerColor: Colors.white.withValues(alpha: 0.08),
      cardColor: MixBuildPalette.surface.withValues(alpha: 0.76),
      canvasColor: MixBuildPalette.surface,
      splashFactory: NoSplash.splashFactory,
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.24),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: MixBuildPalette.muted.withValues(alpha: 0.35),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MixBuildPalette.primary, width: 1.2),
        ),
      ),
    );
  }

  static BoxDecoration glassPanel({double radius = 24, Color? color}) {
    return BoxDecoration(
      color: (color ?? MixBuildPalette.surfaceHigh).withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static TextStyle monoTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: _monoFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static String get _monoFontFamily {
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS => 'Menlo',
      TargetPlatform.windows => 'Consolas',
      TargetPlatform.linux => 'DejaVu Sans Mono',
      _ => 'monospace',
    };
  }
}