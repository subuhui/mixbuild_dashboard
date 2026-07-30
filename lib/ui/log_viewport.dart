import 'package:mixbuild_dashboard/data/mixbuild_models.dart';

const int kProjectDetailLogPageSize = 120;
const int kBuildHistoryLogPageSize = 200;

class LogViewportSlice {
  const LogViewportSlice({
    required this.visibleLogs,
    required this.totalMatches,
    required this.hiddenCount,
  });

  final List<LogEntry> visibleLogs;
  final int totalMatches;
  final int hiddenCount;

  bool get canLoadOlder => hiddenCount > 0;
}

LogViewportSlice buildLogViewport({
  required List<LogEntry> logs,
  required String query,
  required int visibleCount,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final matchedLogs = normalizedQuery.isEmpty
      ? logs
      : logs.where((log) {
          final haystack =
              '${log.time} ${log.level} ${log.message}'.toLowerCase();
          return haystack.contains(normalizedQuery);
        }).toList(growable: false);
  final clampedVisibleCount = visibleCount.clamp(0, matchedLogs.length);
  return LogViewportSlice(
    visibleLogs: matchedLogs.take(clampedVisibleCount).toList(growable: false),
    totalMatches: matchedLogs.length,
    hiddenCount: matchedLogs.length - clampedVisibleCount,
  );
}
