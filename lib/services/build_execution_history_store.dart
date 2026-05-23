import 'dart:convert';
import 'dart:io';

import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:path/path.dart' as p;

class BuildExecutionHistoryStore {
  const BuildExecutionHistoryStore({String? configHomePath})
      : _configHomePathOverride = configHomePath;

  final String? _configHomePathOverride;

  String get appConfigDirectoryPath =>
      p.join(_configHomePath, 'mixbuild_dashboard');
  String get historyFilePath =>
      p.join(appConfigDirectoryPath, 'execution_history.json');

  List<BuildExecutionRecord> loadHistorySync() {
    try {
      final file = File(historyFilePath);
      if (!file.existsSync()) {
        return const <BuildExecutionRecord>[];
      }
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! List) {
        return const <BuildExecutionRecord>[];
      }
      return raw
          .whereType<Map>()
          .map(
            (entry) => BuildExecutionRecord.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <BuildExecutionRecord>[];
    }
  }

  void saveHistorySync(List<BuildExecutionRecord> history) {
    try {
      final file = File(historyFilePath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode(
          history.map((record) => record.toJson()).toList(growable: false),
        ),
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
