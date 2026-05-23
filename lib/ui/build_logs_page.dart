import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';

class BuildLogsPage extends ConsumerStatefulWidget {
  const BuildLogsPage({super.key, this.initialExecutionId});

  final String? initialExecutionId;

  @override
  ConsumerState<BuildLogsPage> createState() => _BuildLogsPageState();
}

class _BuildLogsPageState extends ConsumerState<BuildLogsPage> {
  String? _selectedExecutionId;

  @override
  void initState() {
    super.initState();
    _selectedExecutionId = widget.initialExecutionId;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final history = dashboardState.executionHistory;
    final selectedRecord = _resolveSelectedRecord(history);

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
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child:
                              _BuildExecutionLogDetail(record: selectedRecord),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: MixBuildTheme.glassPanel(radius: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            tooltip: '返回',
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Build Logs', style: theme.textTheme.titleLarge),
              Text(
                hasRecords ? '执行任务历史与日志列表' : '暂无执行任务记录',
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
    if (records.isEmpty) {
      return Container(
        decoration: MixBuildTheme.glassPanel(radius: 24),
        alignment: Alignment.center,
        child: Text(
          '暂无任务历史',
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
                    _formatExecutionTime(record),
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
  const _BuildExecutionLogDetail({required this.record});

  final BuildExecutionRecord? record;

  @override
  Widget build(BuildContext context) {
    if (record == null) {
      return Container(
        decoration: MixBuildTheme.glassPanel(radius: 24),
        alignment: Alignment.center,
        child: Text('请选择一条任务记录', style: Theme.of(context).textTheme.bodySmall),
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
                  '分支: ${record!.branch}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatExecutionTime(record!),
                  style: MixBuildTheme.monoTextStyle(
                    fontSize: 11,
                    color: MixBuildPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: record!.logs.isEmpty
                ? Center(
                    child: Text(
                      '当前任务暂无日志',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(18),
                    itemCount: record!.logs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final log = record!.logs[index];
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

String _formatExecutionTime(BuildExecutionRecord record) {
  final start = record.startedAt;
  final startLabel =
      '${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:${start.second.toString().padLeft(2, '0')}';
  final finish = record.finishedAt;
  if (finish == null) {
    return '开始于 $startLabel';
  }
  final finishLabel =
      '${finish.hour.toString().padLeft(2, '0')}:${finish.minute.toString().padLeft(2, '0')}:${finish.second.toString().padLeft(2, '0')}';
  return '开始于 $startLabel · 结束于 $finishLabel';
}
