import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class ThemePreferenceStore {
  const ThemePreferenceStore({String? configHomePath})
      : _configHomePathOverride = configHomePath;

  final String? _configHomePathOverride;

  String get appConfigDirectoryPath =>
      p.join(_configHomePath, 'mixbuild_dashboard');
  String get preferenceFilePath =>
      p.join(appConfigDirectoryPath, 'theme_preferences.json');

  ThemeMode loadThemeModeSync() {
    try {
      final file = File(preferenceFilePath);
      if (!file.existsSync()) {
        return ThemeMode.system;
      }
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map) {
        return ThemeMode.system;
      }
      final value = raw['themeMode'] as String?;
      return switch (value) {
        'system' => ThemeMode.system,
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
    } catch (_) {
      return ThemeMode.system;
    }
  }

  void saveThemeModeSync(ThemeMode themeMode) {
    try {
      final file = File(preferenceFilePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode(<String, String>{
          'themeMode': switch (themeMode) {
            ThemeMode.system => 'system',
            ThemeMode.dark => 'dark',
            _ => 'light',
          },
        }),
      );
    } catch (_) {}
  }

  String get _configHomePath {
    final overridePath = _configHomePathOverride;
    if (overridePath != null && overridePath.trim().isNotEmpty) {
      return overridePath.trim();
    }

    final xdgConfigHome = Platform.environment['XDG_CONFIG_HOME'];
    if (xdgConfigHome != null && xdgConfigHome.trim().isNotEmpty) {
      return xdgConfigHome.trim();
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return p.join(home.trim(), '.config');
    }

    throw StateError('Unable to determine user config directory.');
  }
}
