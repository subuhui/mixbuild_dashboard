/// @Author subuhui
/// @Date 2026/7/3 13:53
/// @Description 本地构建服务端口的配置读取与持久化存储
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ServerPreferenceStore {
  const ServerPreferenceStore({String? configHomePath})
      : _configHomePathOverride = configHomePath;

  final String? _configHomePathOverride;

  String get appConfigDirectoryPath =>
      p.join(_configHomePath, 'mixbuild_dashboard');
  String get preferenceFilePath =>
      p.join(appConfigDirectoryPath, 'server_preferences.json');

  int loadPortSync() {
    try {
      final file = File(preferenceFilePath);
      if (!file.existsSync()) {
        return 8765;
      }
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map) {
        return 8765;
      }
      final value = raw['port'] as int?;
      return value ?? 8765;
    } catch (_) {
      return 8765;
    }
  }

  void savePortSync(int port) {
    try {
      final file = File(preferenceFilePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode(<String, dynamic>{
          'port': port,
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
