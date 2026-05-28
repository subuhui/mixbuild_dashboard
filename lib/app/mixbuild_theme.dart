import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 亮色主题调色板，所有颜色均为固定值。
class MixBuildPalette {
  static const background = Color(0xFFF6F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF1F4F9);
  static const surfaceHigh = Color(0xFFE8EDF5);
  static const surfaceHighest = Color(0xFFDDE5F0);
  static const foreground = Color(0xFF1A1F2B);
  static const muted = Color(0xFF607080);
  static const primary = Color(0xFF0B57D0);
  static const primarySoft = Color(0x1F0B57D0);
  static const tertiary = Color(0xFFB35A00);
  static const success = Color(0xFF1E8E3E);
  static const warning = Color(0xFFB06000);
  static const error = Color(0xFFC5221F);
}

/// Material 3 亮色主题构建器。
class MixBuildTheme {
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
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
      colorScheme: const ColorScheme.light(
        primary: MixBuildPalette.primary,
        secondary: MixBuildPalette.tertiary,
        surface: MixBuildPalette.surface,
        error: MixBuildPalette.error,
      ),
      textTheme: textTheme,
      dividerColor: Colors.black.withValues(alpha: 0.08),
      cardColor: MixBuildPalette.surfaceHigh,
      canvasColor: MixBuildPalette.surface,
      splashFactory: NoSplash.splashFactory,
      dialogTheme: DialogThemeData(
        backgroundColor: MixBuildPalette.surface,
        barrierColor: Colors.black.withValues(alpha: 0.24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MixBuildPalette.surfaceLow,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: MixBuildPalette.muted.withValues(alpha: 0.35),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: MixBuildPalette.primary, width: 1.2),
        ),
      ),
    );
  }

  static BoxDecoration surfacePanel({double radius = 24, Color? color}) {
    return BoxDecoration(
      color: color ?? MixBuildPalette.surfaceHigh,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.black.withValues(alpha: 0.08),
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
