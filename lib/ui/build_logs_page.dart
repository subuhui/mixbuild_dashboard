import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';
import 'package:mixbuild_dashboard/ui/log_viewport.dart';

class BuildLogsPage extends ConsumerStatefulWidget {
  const BuildLogsPage({super.key, this.initialExecutionId});

  final String? initialExecutionId;

  @override
  ConsumerState<BuildLogsPage> createState() => _BuildLogsPageState();
}

class _BuildLogsPageState extends ConsumerState<BuildLogsPage> {
  String? _selectedExecutionId;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _visibleLogCounts = <String, int>{};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedExecutionId = widget.initialExecutionId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final history = dashboardState.executionHistory;
    final selectedRecord = _resolveSelectedRecord(history);
    final logViewport = selectedRecord == null
        ? const LogViewportSlice(
            visibleLogs: <LogEntry>[],
            totalMatches: 0,
            hiddenCount: 0,
          )
        : buildLogViewport(
            logs: selectedRecord.logs,
            query: _searchQuery,
            visibleCount: _visibleLogCountFor(selectedRecord.id),
          );

    return Scaffold(
      body: Stack(
        children: [
          const DashboardBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _BuildLogsHeader(
                    hasRecords: history.isNotEmpty,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 360,
                          child: _BuildExecutionHistoryList(
                            records: history,
                            selectedExecutionId: selectedRecord?.id,
                            onSelected: (record) {
                              setState(() {
                                _selectedExecutionId = record.id;
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _BuildExecutionLogDetail(
                            record: selectedRecord,
                            visibleLogs: logViewport.visibleLogs,
                            hiddenLogCount: logViewport.hiddenCount,
                            searchController: _searchController,
                            searchQuery: _searchQuery,
                            onSearchChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                if (selectedRecord != null) {
                                  _visibleLogCounts[selectedRecord.id] =
                                      kBuildHistoryLogPageSize;
                                }
                              });
                            },
                            onLoadOlderLogs: selectedRecord != null &&
                                    logViewport.canLoadOlder
                                ? () {
                                    setState(() {
                                      _visibleLogCounts[selectedRecord.id] =
                                          _visibleLogCountFor(
                                                  selectedRecord.id) +
                                              kBuildHistoryLogPageSize;
                                    });
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BuildExecutionRecord? _resolveSelectedRecord(
      List<BuildExecutionRecord> history) {
    if (history.isEmpty) {
      return null;
    }
    for (final record in history) {
      if (record.id == _selectedExecutionId) {
        return record;
      }
    }
    return history.first;
  }

  int _visibleLogCountFor(String executionId) {
    return _visibleLogCounts.putIfAbsent(
      executionId,
      () => kBuildHistoryLogPageSize,
    );
  }
}

class _BuildLogsHeader extends StatelessWidget {
  const _BuildLogsHeader({
    required this.hasRecords,
    required this.onBack,
  });

  final bool hasRecords;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: MixBuildTheme.glassPanel(radius: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            tooltip: strings.btnBack,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.buildLogsTitle, style: theme.textTheme.titleLarge),
              Text(
                hasRecords
                    ? strings.buildLogsSubtitle
                    : strings.buildLogsEmptyDetail,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuildExecutionHistoryList extends StatelessWidget {
  const _BuildExecutionHistoryList({
    required this.records,
    required this.selectedExecutionId,
    required this.onSelected,
  });

  final List<BuildExecutionRecord> records;
  final String? selectedExecutionId;
  final ValueChanged<BuildExecutionRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (records.isEmpty) {
      return Container(
        decoration: MixBuildTheme.glassPanel(radius: 24),
        alignment: Alignment.center,
        child: Text(
          strings.buildLogsEmpty,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Container(
      decoration: MixBuildTheme.glassPanel(radius: 24),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final record = records[index];
          final selected = record.id == selectedExecutionId;
          return InkWell(
            onTap: () => onSelected(record),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? MixBuildPalette.primary.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? MixBuildPalette.primary.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.projectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      StatusChip(status: record.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    record.scenarioName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatExecutionTime(record, strings),
                    style: MixBuildTheme.monoTextStyle(
                      fontSize: 11,
                      color: MixBuildPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    record.command,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MixBuildTheme.monoTextStyle(
                      fontSize: 11,
                      color: MixBuildPalette.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BuildExecutionLogDetail extends StatelessWidget {
  const _BuildExecutionLogDetail({
    required this.record,
    required this.visibleLogs,
    required this.hiddenLogCount,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onLoadOlderLogs,
  });

  final BuildExecutionRecord? record;
  final List<LogEntry> visibleLogs;
  final int hiddenLogCount;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onLoadOlderLogs;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (record == null) {
      return Container(
        decoration: MixBuildTheme.glassPanel(radius: 24),
        alignment: Alignment.center,
        child: Text(
          strings.buildLogsSelectRecord,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Container(
      decoration: MixBuildTheme.glassPanel(radius: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${record!.projectName} / ${record!.scenarioName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusChip(status: record!.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  strings.branchInfo(record!.branch),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatExecutionTime(record!, strings),
                  style: MixBuildTheme.monoTextStyle(
                    fontSize: 11,
                    color: MixBuildPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: MixBuildTheme.monoTextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.82),
              ),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close, size: 16),
                        splashRadius: 14,
                        tooltip: strings.btnClose,
                      ),
                hintText: strings.buildLogsNoMatch,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: record!.logs.isEmpty
                ? Center(
                    child: Text(
                      strings.buildLogsNoLogs,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : visibleLogs.isEmpty
                    ? Center(
                        child: Text(
                          strings.noLogMatch(searchQuery),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount:
                            visibleLogs.length + (hiddenLogCount > 0 ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          if (index == visibleLogs.length) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: onLoadOlderLogs,
                                child: Text(
                                  strings.buildLogsLoadOlder(hiddenLogCount),
                                ),
                              ),
                            );
                          }
                          final log = visibleLogs[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 84,
                                child: Text(
                                  '[${log.time}]',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: MixBuildTheme.monoTextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  '[${log.level}]',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: MixBuildTheme.monoTextStyle(
                                    fontSize: 12,
                                    color: log.accent,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  log.message,
                                  style: MixBuildTheme.monoTextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

String _formatExecutionTime(BuildExecutionRecord record, AppStrings strings) {
  final start = record.startedAt;
  final startLabel =
      '${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:${start.second.toString().padLeft(2, '0')}';
  final finish = record.finishedAt;
  if (finish == null) {
    return '${strings.buildLogsStart} $startLabel';
  }
  final finishLabel =
      '${finish.hour.toString().padLeft(2, '0')}:${finish.minute.toString().padLeft(2, '0')}:${finish.second.toString().padLeft(2, '0')}';
  return '${strings.buildLogsStart} $startLabel · ${strings.buildLogsStartFinish.split(' · ').last} $finishLabel';
}
