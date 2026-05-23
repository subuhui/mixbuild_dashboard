import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';

class DashboardBackground extends StatelessWidget {
  const DashboardBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: MixBuildPalette.background),
        Positioned(
          top: -120,
          left: -80,
          child: Container(
            width: 420,
            height: 420,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x330A84FF), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          right: -120,
          bottom: -160,
          child: Container(
            width: 520,
            height: 520,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x26EB6A12), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.currentWorkspaceName,
    required this.availableWorkspaceNames,
    required this.runningCount,
    required this.onWorkspaceChanged,
    required this.onReloadTopology,
  });

  final String currentWorkspaceName;
  final List<String> availableWorkspaceNames;
  final int runningCount;
  final ValueChanged<String> onWorkspaceChanged;
  final VoidCallback onReloadTopology;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderedWorkspaceNames = <String>[
      currentWorkspaceName,
      ...availableWorkspaceNames.where((name) => name != currentWorkspaceName),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 960;
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: MixBuildPalette.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'MixBuild Dashboard v3.1',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 14),
                          Container(
                            width: 1,
                            height: 18,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: MixBuildPalette.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: MixBuildPalette.primary
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: MixBuildPalette.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Parallel Running: $runningCount',
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: MixBuildPalette.foreground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 230,
                      child: DropdownButtonFormField<String>(
                        initialValue: currentWorkspaceName,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (value) {
                          if (value != null && value != currentWorkspaceName) {
                            onWorkspaceChanged(value);
                          }
                        },
                        items: orderedWorkspaceNames
                            .map(
                              (name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (compact)
                    IconButton(
                      onPressed: onReloadTopology,
                      icon: const Icon(Icons.refresh, size: 18),
                    )
                  else
                    TextButton.icon(
                      onPressed: onReloadTopology,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reload'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DashboardSideBar extends StatelessWidget {
  const DashboardSideBar({
    super.key,
    required this.project,
    required this.scenario,
    required this.cleanBeforeBuild,
    required this.branchOptions,
    required this.onBranchChanged,
    required this.onScenarioChanged,
    required this.onDependencyBranchChanged,
    required this.dependencyBranchOptions,
    required this.onCleanChanged,
    required this.onTrigger,
    required this.onStop,
  });

  final ProjectBuild project;
  final BuildScenario scenario;
  final bool cleanBeforeBuild;
  final List<String> branchOptions;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<String> onScenarioChanged;
  final void Function(String dependencyName, String branch)
      onDependencyBranchChanged;
  final List<String> Function(DependencyBranch dependency)
      dependencyBranchOptions;
  final ValueChanged<bool> onCleanChanged;
  final VoidCallback onTrigger;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 332,
      decoration: BoxDecoration(
        color: MixBuildPalette.surfaceLow.withValues(alpha: 0.88),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MixBuild',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: MixBuildPalette.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'v3.1.0-stable · Flutter Desktop / macOS',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: MixBuildTheme.glassPanel(
                radius: 20,
                color: MixBuildPalette.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project.name,
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              project.description,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      StatusChip(status: scenario.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '主工程分支',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: MixBuildPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: project.branch,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: scenario.status.controlsLocked
                        ? null
                        : (value) {
                            if (value != null) {
                              onBranchChanged(value);
                            }
                          },
                    items: branchOptions
                        .map(
                          (branch) => DropdownMenuItem<String>(
                            value: branch,
                            child: Text(branch),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '依赖项拓扑视图',
              style: theme.textTheme.labelLarge?.copyWith(
                color: MixBuildPalette.muted,
              ),
            ),
            const SizedBox(height: 10),
            for (final dependency in scenario.dependencies)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            dependency.icon,
                            size: 16,
                            color:
                                dependency.highlight ?? MixBuildPalette.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dependency.name,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (dependency.isOverride)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (dependency.highlight ??
                                        MixBuildPalette.primary)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Override',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: dependency.highlight ??
                                      MixBuildPalette.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: dependency.branch,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        onChanged: scenario.status.controlsLocked
                            ? null
                            : (value) {
                                if (value != null) {
                                  onDependencyBranchChanged(
                                      dependency.name, value);
                                }
                              },
                        items: dependencyBranchOptions(dependency)
                            .map(
                              (branch) => DropdownMenuItem<String>(
                                value: branch,
                                child: Text(branch),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '构建场景配置',
              style: theme.textTheme.labelLarge?.copyWith(
                color: MixBuildPalette.muted,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: scenario.id,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              onChanged: scenario.status.controlsLocked
                  ? null
                  : (value) {
                      if (value != null) {
                        onScenarioChanged(value);
                      }
                    },
              items: project.scenarios
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                scenario.command,
                style: MixBuildTheme.monoTextStyle(
                  fontSize: 12,
                  color: MixBuildPalette.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: cleanBeforeBuild,
                  onChanged: scenario.status.controlsLocked
                      ? null
                      : (value) => onCleanChanged(value ?? false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '执行构建前强制清理 (--clean)',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: scenario.status.canTrigger ? onTrigger : null,
              icon: Icon(
                scenario.status.controlsLocked ? Icons.sync : Icons.play_arrow,
              ),
              label: Text(scenario.status.triggerLabel),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: scenario.status.canStop ? onStop : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: MixBuildPalette.error,
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('停止'),
            ),
          ],
        ),
      ),
    );
  }
}

class ScenarioInspectorPanel extends StatelessWidget {
  const ScenarioInspectorPanel({
    super.key,
    required this.project,
    required this.scenario,
    required this.onOpenYaml,
  });

  final ProjectBuild project;
  final BuildScenario scenario;
  final VoidCallback onOpenYaml;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: MixBuildTheme.glassPanel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scenario.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(project.name, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenYaml,
                  icon: const Icon(Icons.data_object_outlined, size: 18),
                  label: const Text('YAML'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BuildStatus.values.map((status) {
                final active = status == scenario.status;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: active ? Colors.white : MixBuildPalette.muted,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: MixBuildPalette.muted.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scenario.status.description,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('任务历史')),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              MacDot(color: MixBuildPalette.error),
                              const SizedBox(width: 6),
                              MacDot(color: MixBuildPalette.warning),
                              const SizedBox(width: 6),
                              MacDot(color: MixBuildPalette.primary),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'zsh — ${scenario.command} — ${project.name}',
                              overflow: TextOverflow.ellipsis,
                              style: MixBuildTheme.monoTextStyle(
                                fontSize: 11,
                                color: MixBuildPalette.muted,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.search,
                            size: 18,
                            color: MixBuildPalette.muted,
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.download_outlined,
                            size: 18,
                            color: MixBuildPalette.muted,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: scenario.logs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = scenario.logs[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 72,
                                child: Text(
                                  '[${log.time}]',
                                  style: MixBuildTheme.monoTextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.36),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  '[${log.level}]',
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('输出目录', style: theme.textTheme.bodySmall),
                              const Spacer(),
                              Text(
                                '${(scenario.progress * 100).toStringAsFixed(1)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scenario.status.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: scenario.status == BuildStatus.idle
                                ? 0.0
                                : scenario.progress,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              scenario.status.color,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            scenario.outputPath,
                            style: MixBuildTheme.monoTextStyle(
                              fontSize: 12,
                              color: MixBuildPalette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MixBuildPalette.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MixBuildPalette.primary.withValues(alpha: 0.14),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('依赖分支覆盖', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 12),
                    for (final dependency in scenario.dependencies)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(
                              dependency.icon,
                              size: 18,
                              color:
                                  dependency.highlight ?? MixBuildPalette.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                dependency.name,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: (dependency.highlight ??
                                        MixBuildPalette.surfaceHighest)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: (dependency.highlight ??
                                          MixBuildPalette.muted)
                                      .withValues(alpha: 0.18),
                                ),
                              ),
                              child: Text(
                                dependency.branch,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: dependency.highlight ??
                                      MixBuildPalette.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardFooterBar extends StatelessWidget {
  const DashboardFooterBar({
    super.key,
    required this.metrics,
    required this.projects,
  });

  final List<ResourceMetric> metrics;
  final List<ProjectBuild> projects;

  _SystemRuntimeStatus get _systemStatus {
    final scenarios = projects.expand((project) => project.scenarios).toList();
    final running =
        scenarios.where((scenario) => scenario.status.isPipelineActive).length;
    final failed = scenarios
        .where((scenario) => scenario.status == BuildStatus.failed)
        .length;
    if (running > 0) {
      return _SystemRuntimeStatus(
        label: running == 1 ? 'Running' : 'Running $running',
        color: MixBuildPalette.warning,
      );
    }
    if (failed > 0) {
      return _SystemRuntimeStatus(
        label: failed == 1 ? 'Failed' : 'Failed $failed',
        color: MixBuildPalette.error,
      );
    }
    return _SystemRuntimeStatus(
      label: 'Ready',
      color: MixBuildPalette.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final systemStatus = _systemStatus;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: MixBuildPalette.surfaceLow.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 10,
            children: [
              Text('© 2026 MixBuild Systems', style: theme.textTheme.bodySmall),
              for (final metric in metrics) DashboardMetricBar(metric: metric),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: systemStatus.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    systemStatus.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: systemStatus.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemRuntimeStatus {
  const _SystemRuntimeStatus({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

class DashboardMetricBar extends StatelessWidget {
  const DashboardMetricBar({super.key, required this.metric});

  final ResourceMetric metric;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${metric.label}: ${metric.value}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: metric.color,
              ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: LinearProgressIndicator(
            value: metric.progress,
            minHeight: 5,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation<Color>(metric.color),
          ),
        ),
      ],
    );
  }
}

class TinyBadge extends StatelessWidget {
  const TinyBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatefulWidget {
  const StatusChip({super.key, required this.status});

  final BuildStatus status;

  @override
  State<StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<StatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulse = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.status.isPipelineActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status.isPipelineActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.status.isPipelineActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: widget.status.color.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              return Opacity(
                opacity: widget.status.isPipelineActive ? _pulse.value : 1.0,
                child: child,
              );
            },
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.status.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.status.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: widget.status.color,
                ),
          ),
        ],
      ),
    );
  }
}

class ScenarioSummary extends StatelessWidget {
  const ScenarioSummary({super.key, required this.scenario});

  final BuildScenario scenario;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(scenario.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${scenario.subtitle} · ${scenario.command}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MixBuildTheme.monoTextStyle(
            fontSize: 12,
            color: MixBuildPalette.muted.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class ScenarioActionButton extends StatelessWidget {
  const ScenarioActionButton({
    super.key,
    required this.color,
    required this.enabled,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final Color color;
  final bool enabled;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 18),
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: color.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        label: Text(label),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 18),
      style: FilledButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      label: Text(label),
    );
  }
}

class MacDot extends StatelessWidget {
  const MacDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
    );
  }
}
