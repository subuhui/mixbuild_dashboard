import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class _MixBuildPaletteSpec {
  const _MixBuildPaletteSpec({
    required this.background,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.foreground,
    required this.muted,
    required this.primary,
    required this.primarySoft,
    required this.tertiary,
    required this.success,
    required this.warning,
    required this.error,
    required this.barrier,
  });

  final Color background;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color foreground;
  final Color muted;
  final Color primary;
  final Color primarySoft;
  final Color tertiary;
  final Color success;
  final Color warning;
  final Color error;
  final Color barrier;
}

class MixBuildPalette {
  static const _light = _MixBuildPaletteSpec(
    background: Color(0xFFF6F8FB),
    surface: Color(0xFFFFFFFF),
    surfaceLow: Color(0xFFF1F4F9),
    surfaceHigh: Color(0xFFE8EDF5),
    surfaceHighest: Color(0xFFDDE5F0),
    foreground: Color(0xFF1A1F2B),
    muted: Color(0xFF607080),
    primary: Color(0xFF0B57D0),
    primarySoft: Color(0x1F0B57D0),
    tertiary: Color(0xFFB35A00),
    success: Color(0xFF1E8E3E),
    warning: Color(0xFFB06000),
    error: Color(0xFFC5221F),
    barrier: Color(0x3D000000),
  );

  static const _dark = _MixBuildPaletteSpec(
    background: Color(0xFF111318),
    surface: Color(0xFF1A1C22),
    surfaceLow: Color(0xFF20232A),
    surfaceHigh: Color(0xFF2A2E37),
    surfaceHighest: Color(0xFF333844),
    foreground: Color(0xFFE3E8F2),
    muted: Color(0xFFA5B0C5),
    primary: Color(0xFFAAC7FF),
    primarySoft: Color(0x33AAC7FF),
    tertiary: Color(0xFFFFB870),
    success: Color(0xFF7AD69A),
    warning: Color(0xFFFFC870),
    error: Color(0xFFFFB4AB),
    barrier: Color(0x8A000000),
  );

  static _MixBuildPaletteSpec _active = _light;

  static void applyThemeMode(ThemeMode themeMode) {
    _active = themeMode == ThemeMode.dark ? _dark : _light;
  }

  static void applyBrightness(Brightness brightness) {
    _active = brightness == Brightness.dark ? _dark : _light;
  }

  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get surfaceLow => _active.surfaceLow;
  static Color get surfaceHigh => _active.surfaceHigh;
  static Color get surfaceHighest => _active.surfaceHighest;
  static Color get foreground => _active.foreground;
  static Color get muted => _active.muted;
  static Color get primary => _active.primary;
  static Color get primarySoft => _active.primarySoft;
  static Color get tertiary => _active.tertiary;
  static Color get success => _active.success;
  static Color get warning => _active.warning;
  static Color get error => _active.error;
  static Color get barrier => _active.barrier;
}

class MixBuildTheme {
  static ThemeData get lightTheme {
    return _buildTheme(
        _MixBuildPaletteSpec(
          background: MixBuildPalette._light.background,
          surface: MixBuildPalette._light.surface,
          surfaceLow: MixBuildPalette._light.surfaceLow,
          surfaceHigh: MixBuildPalette._light.surfaceHigh,
          surfaceHighest: MixBuildPalette._light.surfaceHighest,
          foreground: MixBuildPalette._light.foreground,
          muted: MixBuildPalette._light.muted,
          primary: MixBuildPalette._light.primary,
          primarySoft: MixBuildPalette._light.primarySoft,
          tertiary: MixBuildPalette._light.tertiary,
          success: MixBuildPalette._light.success,
          warning: MixBuildPalette._light.warning,
          error: MixBuildPalette._light.error,
          barrier: MixBuildPalette._light.barrier,
        ),
        Brightness.light);
  }

  static ThemeData get darkTheme {
    return _buildTheme(
        _MixBuildPaletteSpec(
          background: MixBuildPalette._dark.background,
          surface: MixBuildPalette._dark.surface,
          surfaceLow: MixBuildPalette._dark.surfaceLow,
          surfaceHigh: MixBuildPalette._dark.surfaceHigh,
          surfaceHighest: MixBuildPalette._dark.surfaceHighest,
          foreground: MixBuildPalette._dark.foreground,
          muted: MixBuildPalette._dark.muted,
          primary: MixBuildPalette._dark.primary,
          primarySoft: MixBuildPalette._dark.primarySoft,
          tertiary: MixBuildPalette._dark.tertiary,
          success: MixBuildPalette._dark.success,
          warning: MixBuildPalette._dark.warning,
          error: MixBuildPalette._dark.error,
          barrier: MixBuildPalette._dark.barrier,
        ),
        Brightness.dark);
  }

  static ThemeData _buildTheme(
    _MixBuildPaletteSpec palette,
    Brightness brightness,
  ) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: palette.foreground,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: palette.foreground,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: palette.foreground,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: palette.foreground,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 17,
        color: palette.foreground,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 15,
        color: palette.foreground,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: palette.muted,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 13,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: palette.foreground,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: brightness,
        primary: palette.primary,
        secondary: palette.tertiary,
        surface: palette.surface,
        error: palette.error,
      ),
      textTheme: textTheme,
      dividerColor: palette.foreground.withValues(alpha: 0.08),
      cardColor: palette.surfaceHigh,
      canvasColor: palette.surface,
      splashFactory: NoSplash.splashFactory,
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        barrierColor: palette.barrier,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceLow,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: palette.muted.withValues(alpha: 0.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: palette.foreground.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: palette.foreground.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.primary, width: 1.2),
        ),
      ),
    );
  }

  static BoxDecoration surfacePanel({double radius = 24, Color? color}) {
    return BoxDecoration(
      color: color ?? MixBuildPalette.surfaceHigh,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: MixBuildPalette.foreground.withValues(alpha: 0.08),
      ),
    );
  }

  /// 平台等宽字体样式：macOS 用 Menlo，Windows 用 Consolas，Linux 用 DejaVu Sans Mono。
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
