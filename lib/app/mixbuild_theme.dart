import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MixBuildPalette {
  static bool get _isLight =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.light;

  static Color get background =>
      _isLight ? const Color(0xFFF4F7FB) : const Color(0xFF0C0C0C);
  static Color get surface =>
      _isLight ? const Color(0xFFFFFFFF) : const Color(0xFF131313);
  static Color get surfaceLow =>
      _isLight ? const Color(0xFFE9EEF6) : const Color(0xFF1B1B1C);
  static Color get surfaceHigh =>
      _isLight ? const Color(0xFFF8FAFE) : const Color(0xFF2A2A2A);
  static Color get surfaceHighest =>
      _isLight ? const Color(0xFFE1E8F2) : const Color(0xFF353535);
  static Color get foreground =>
      _isLight ? const Color(0xFF1D2430) : const Color(0xFFE5E2E1);
  static Color get muted =>
      _isLight ? const Color(0xFF627085) : const Color(0xFFC0C6D6);
  static Color get primary =>
      _isLight ? const Color(0xFF1F5FBF) : const Color(0xFFAAC7FF);
  static const primarySoft = Color(0x33AAC7FF);
  static Color get tertiary =>
      _isLight ? const Color(0xFFC4510D) : const Color(0xFFEB6A12);
  static Color get success =>
      _isLight ? const Color(0xFF14864B) : const Color(0xFF45D483);
  static Color get warning =>
      _isLight ? const Color(0xFFB35A00) : const Color(0xFFFFB55E);
  static Color get error =>
      _isLight ? const Color(0xFFD53B3B) : const Color(0xFFFF6B6B);
}

class MixBuildTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = isLight
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);
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
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: MixBuildPalette.primary,
        onPrimary: isLight ? Colors.white : const Color(0xFF102544),
        secondary: MixBuildPalette.tertiary,
        onSecondary: Colors.white,
        tertiary: MixBuildPalette.tertiary,
        onTertiary: Colors.white,
        error: MixBuildPalette.error,
        onError: Colors.white,
        surface: MixBuildPalette.surface,
        onSurface: MixBuildPalette.foreground,
      ),
      textTheme: textTheme,
      dividerColor:
          (isLight ? Colors.black : Colors.white).withValues(alpha: 0.08),
      cardColor: MixBuildPalette.surface.withValues(alpha: 0.76),
      canvasColor: MixBuildPalette.surface,
      splashFactory: NoSplash.splashFactory,
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: isLight ? 0.28 : 0.65),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: (isLight ? Colors.white : Colors.black).withValues(
          alpha: isLight ? 0.72 : 0.24,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: MixBuildPalette.muted.withValues(alpha: 0.35),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color:
                (isLight ? Colors.black : Colors.white).withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color:
                (isLight ? Colors.black : Colors.white).withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: MixBuildPalette.primary, width: 1.2),
        ),
      ),
    );
  }

  static BoxDecoration glassPanel({double radius = 24, Color? color}) {
    final isLight = MixBuildPalette._isLight;
    return BoxDecoration(
      color: (color ?? MixBuildPalette.surfaceHigh).withValues(
        alpha: isLight ? 0.86 : 0.72,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: (isLight ? Colors.black : Colors.white).withValues(alpha: 0.1),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.32),
          blurRadius: isLight ? 24 : 32,
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
