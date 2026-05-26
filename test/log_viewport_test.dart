import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/ui/log_viewport.dart';

void main() {
  test('buildLogViewport returns the newest window when query is empty', () {
    final logs = List<LogEntry>.generate(
      6,
      (index) => LogEntry(
        time: '11:20:0$index',
        level: 'OUT',
        message: 'line-$index',
        accent: Colors.white,
      ),
      growable: false,
    );

    final viewport = buildLogViewport(
      logs: logs,
      query: '',
      visibleCount: 3,
    );

    expect(viewport.visibleLogs.map((log) => log.message).toList(), <String>[
      'line-0',
      'line-1',
      'line-2',
    ]);
    expect(viewport.totalMatches, 6);
    expect(viewport.hiddenCount, 3);
    expect(viewport.canLoadOlder, isTrue);
  });

  test('buildLogViewport pages filtered results when query is provided', () {
    final logs = <LogEntry>[
      const LogEntry(
        time: '11:20:00',
        level: 'OUT',
        message: 'gradle assemble release',
        accent: Colors.white,
      ),
      const LogEntry(
        time: '11:20:01',
        level: 'OUT',
        message: 'copy output bundle',
        accent: Colors.white,
      ),
      const LogEntry(
        time: '11:20:02',
        level: 'ERR',
        message: 'gradle daemon warning',
        accent: Colors.red,
      ),
      const LogEntry(
        time: '11:20:03',
        level: 'OUT',
        message: 'gradle task finished',
        accent: Colors.white,
      ),
    ];

    final viewport = buildLogViewport(
      logs: logs,
      query: 'gradle',
      visibleCount: 2,
    );

    expect(viewport.visibleLogs.map((log) => log.message).toList(), <String>[
      'gradle assemble release',
      'gradle daemon warning',
    ]);
    expect(viewport.totalMatches, 3);
    expect(viewport.hiddenCount, 1);
    expect(viewport.canLoadOlder, isTrue);
  });
}
