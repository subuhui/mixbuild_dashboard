import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:intl/intl.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:path/path.dart' as p;

class BuildExecutionHistoryStore {
  const BuildExecutionHistoryStore({String? configHomePath})
      : _configHomePathOverride = configHomePath;

  final String? _configHomePathOverride;

  String get appConfigDirectoryPath =>
      p.join(_configHomePath, 'mixbuild_dashboard');

  String get logsDirectoryPath =>
      p.join(appConfigDirectoryPath, 'execution_logs');

  String getDailyLogFilePath([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    return p.join(logsDirectoryPath, '$dateStr.json');
  }

  List<BuildExecutionRecord> loadHistorySync() {
    try {
      final file = File(getDailyLogFilePath());
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
      final file = File(getDailyLogFilePath());
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode(
          history.map((record) => record.toJson()).toList(growable: false),
        ),
      );
    } catch (_) {}
  }

  Future<void> saveHistory(List<BuildExecutionRecord> history) async {
    final payload =
        history.map((record) => record.toJson()).toList(growable: false);
    final filePath = getDailyLogFilePath();
    try {
      await Isolate.run<void>(() => _writeHistoryPayload(filePath, payload));
    } catch (_) {}
  }

  /// 清除所有历史日志文件
  Future<int> clearAllLogs() async {
    try {
      final dir = Directory(logsDirectoryPath);
      if (!dir.existsSync()) {
        return 0;
      }
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      for (final file in files) {
        file.deleteSync();
      }
      return files.length;
    } catch (_) {
      return 0;
    }
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

void _writeHistoryPayload(
  String filePath,
  List<Map<String, dynamic>> payload,
) {
  final file = File(filePath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(payload));
}
