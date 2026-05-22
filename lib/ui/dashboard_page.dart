import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/state/dashboard_state.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DashboardController get _controller =>
      ref.read(dashboardControllerProvider.notifier);

  void _selectScenario(ProjectBuild project, BuildScenario scenario) {
    _controller.selectScenario(project, scenario);
  }

  void _toggleScenario(ProjectBuild project, BuildScenario scenario) {
    _controller.selectScenario(project, scenario);
    _controller.triggerSelectedScenario();
  }

  void _stopSelectedScenario({ProjectBuild? project, BuildScenario? scenario}) {
    if (project != null && scenario != null) {
      _controller.selectScenario(project, scenario);
    }
    _controller.stopSelectedScenario();
  }

  void _changeProjectBranch(String branch) {
    _controller.changeProjectBranch(branch);
  }

  void _changeScenario(String scenarioId) {
    _controller.changeScenario(scenarioId);
  }

  void _changeDependencyBranch(String dependencyName, String branch) {
    _controller.changeDependencyBranch(dependencyName, branch);
  }

  void _reloadTopology() {
    _controller.reloadTopology();
  }

  void _setCleanBeforeBuild(bool value) {
    _controller.setCleanBeforeBuild(value);
  }

  Future<void> _openYamlDialog(BuildScenario scenario) async {
    final initialValue = _controller.readCurrentYaml();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _YamlEditorDialog(initialValue: initialValue),
    );
    if (result == null) {
      return;
    }

    try {
      await _controller.saveCurrentYaml(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('YAML 保存失败: $error')),
      );
    }
  }

  Future<void> _openConfigCenter() async {
    final dashboardState = ref.read(dashboardControllerProvider);
    final result = await showDialog<GlobalConfig>(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          _ConfigCenterDialog(config: dashboardState.globalConfig),
    );
    if (result != null) {
      await _controller.updateGlobalConfig(result);
    }
  }

  Future<void> _openAddScenarioDialog() async {
    final dashboardState = ref.read(dashboardControllerProvider);
    final result = await showDialog<BuildScenario>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AddScenarioDialog(
          baseDependencies: dashboardState.selectedScenario.dependencies),
    );
    if (result == null) {
      return;
    }

    _controller.addScenario(result);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final selectedProject = dashboardState.selectedProject;
    final selectedScenario = dashboardState.selectedScenario;
    final isWide = MediaQuery.sizeOf(context).width >= 1380;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const _DashboardBackground(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  currentWorkspaceName: dashboardState.config.workspace.name,
                  availableWorkspaceNames:
                      dashboardState.availableWorkspaceNames,
                  runningCount: dashboardState.runningCount,
                  onWorkspaceChanged: (value) =>
                      _controller.switchWorkspace(value),
                  onReloadTopology: _reloadTopology,
                  onOpenYaml: () => _controller.openYamlInEditor(),
                  onOpenConfig: _openConfigCenter,
                ),
                Expanded(
                  child: Row(
                    children: [
                      _SideBar(
                        project: selectedProject,
                        scenario: selectedScenario,
                        cleanBeforeBuild: dashboardState.cleanBeforeBuild[
                                dashboardState.selectedScenarioId] ??
                            false,
                        branchOptions:
                            _controller.branchOptions(selectedProject),
                        onBranchChanged: _changeProjectBranch,
                        onScenarioChanged: _changeScenario,
                        onDependencyBranchChanged: _changeDependencyBranch,
                        dependencyBranchOptions:
                            _controller.dependencyBranchOptions,
                        onCleanChanged: _setCleanBeforeBuild,
                        onTrigger: () =>
                            _toggleScenario(selectedProject, selectedScenario),
                        onStop: _stopSelectedScenario,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                          child: Column(
                            children: [
                              Expanded(
                                child: isWide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 7,
                                            child: _buildMatrix(
                                                theme, dashboardState),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            flex: 4,
                                            child: _InspectorPanel(
                                              project: selectedProject,
                                              scenario: selectedScenario,
                                              onOpenYaml: () => _openYamlDialog(
                                                  selectedScenario),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: _buildMatrix(
                                                theme, dashboardState),
                                          ),
                                          const SizedBox(height: 20),
                                          Expanded(
                                            flex: 2,
                                            child: _InspectorPanel(
                                              project: selectedProject,
                                              scenario: selectedScenario,
                                              onOpenYaml: () => _openYamlDialog(
                                                  selectedScenario),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 12),
                              _FooterBar(metrics: dashboardState.metrics),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddScenarioDialog,
        backgroundColor: MixBuildPalette.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增构建场景'),
      ),
    );
  }

  Widget _buildMatrix(ThemeData theme, DashboardState dashboardState) {
    return ListView.separated(
      itemCount: dashboardState.projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final project = dashboardState.projects[index];
        return DecoratedBox(
          decoration: MixBuildTheme.glassPanel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Row(
                  children: [
                    Text(project.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${project.name} (${project.description})',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Branch: ${project.branch}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _selectScenario(project, project.scenarios.first);
                        _openYamlDialog(project.scenarios.first);
                      },
                      icon: const Icon(Icons.data_object_outlined, size: 18),
                      label: const Text('YAML Override'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        _selectScenario(project, project.scenarios.first);
                      },
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final scenario in project.scenarios)
                _ScenarioRow(
                  project: project,
                  scenario: scenario,
                  selected: project.id == dashboardState.selectedProjectId &&
                      scenario.id == dashboardState.selectedScenarioId,
                  onTap: () => _selectScenario(project, scenario),
                  onToggle: () => _toggleScenario(project, scenario),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.currentWorkspaceName,
    required this.availableWorkspaceNames,
    required this.runningCount,
    required this.onWorkspaceChanged,
    required this.onReloadTopology,
    required this.onOpenYaml,
    required this.onOpenConfig,
  });

  final String currentWorkspaceName;
  final List<String> availableWorkspaceNames;
  final int runningCount;
  final ValueChanged<String> onWorkspaceChanged;
  final VoidCallback onReloadTopology;
  final VoidCallback onOpenYaml;
  final VoidCallback onOpenConfig;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 960;
        return ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: MixBuildPalette.surface.withValues(alpha: 0.72),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
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
                            child: _TinyBadge(
                              label: 'Parallel Running: $runningCount',
                              color: MixBuildPalette.primary,
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
                        items: availableWorkspaceNames
                            .map(
                              (name) => DropdownMenuItem<String>(
                                value: name,
                                child:
                                    Text(name, overflow: TextOverflow.ellipsis),
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
                      label: const Text('重载 YAML'),
                    ),
                  const SizedBox(width: 8),
                  if (compact)
                    IconButton(
                      onPressed: onOpenYaml,
                      icon: const Icon(Icons.open_in_new, size: 18),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onOpenYaml,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('打开 YAML'),
                    ),
                  const SizedBox(width: 8),
                  if (compact)
                    IconButton(
                      onPressed: onOpenConfig,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed: onOpenConfig,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Global Config'),
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

class _SideBar extends StatelessWidget {
  const _SideBar({
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
            Text('v3.1.0-stable · Flutter Desktop / macOS',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: MixBuildTheme.glassPanel(
                  radius: 20, color: MixBuildPalette.surface),
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
                            Text(project.description,
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      _StatusChip(status: scenario.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('主工程分支',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: MixBuildPalette.muted)),
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
                        .map((branch) => DropdownMenuItem<String>(
                              value: branch,
                              child: Text(branch),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('依赖项拓扑视图',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: MixBuildPalette.muted)),
            const SizedBox(height: 10),
            for (final dependency in scenario.dependencies)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(dependency.icon,
                              size: 16,
                              color: dependency.highlight ??
                                  MixBuildPalette.muted),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(dependency.name,
                                  style: theme.textTheme.titleMedium)),
                          if (dependency.isOverride)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (dependency.highlight ??
                                        MixBuildPalette.primary)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('Override',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: dependency.highlight ??
                                          MixBuildPalette.primary)),
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
                            .map((branch) => DropdownMenuItem<String>(
                                  value: branch,
                                  child: Text(branch),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('构建场景配置',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: MixBuildPalette.muted)),
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
                  .map((item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
                      ))
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
              icon: Icon(scenario.status.controlsLocked
                  ? Icons.sync
                  : Icons.play_arrow),
              label: Text(scenario.status.triggerLabel),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: scenario.status.canStop ? onStop : null,
              style: OutlinedButton.styleFrom(
                  foregroundColor: MixBuildPalette.error),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('停止'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({
    required this.project,
    required this.scenario,
    required this.selected,
    required this.onTap,
    required this.onToggle,
  });

  final ProjectBuild project;
  final BuildScenario scenario;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final actionLabel = scenario.status.canStop
        ? '停止'
        : scenario.status.controlsLocked
            ? 'Loading…'
            : '开始';
    final actionIcon = scenario.status.canStop
        ? Icons.stop_circle_outlined
        : scenario.status.controlsLocked
            ? Icons.sync
            : Icons.rocket_launch_outlined;
    final actionColor = scenario.status.canStop
        ? MixBuildPalette.error
        : scenario.status.controlsLocked
            ? MixBuildPalette.muted
            : MixBuildPalette.primary;
    final actionEnabled = scenario.status.canStop || scenario.status.canTrigger;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? scenario.status.color.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? scenario.status.color : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScenarioSummary(scenario: scenario),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatusChip(status: scenario.status),
                      const Spacer(),
                      _ScenarioActionButton(
                        color: actionColor,
                        enabled: actionEnabled,
                        label: actionLabel,
                        icon: actionIcon,
                        onPressed: onToggle,
                      ),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: _ScenarioSummary(scenario: scenario)),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.center,
                    child: _StatusChip(status: scenario.status),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _ScenarioActionButton(
                      color: actionColor,
                      enabled: actionEnabled,
                      label: actionLabel,
                      icon: actionIcon,
                      onPressed: onToggle,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScenarioSummary extends StatelessWidget {
  const _ScenarioSummary({required this.scenario});

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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final BuildStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: status.color,
                ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioActionButton extends StatelessWidget {
  const _ScenarioActionButton({
    required this.color,
    required this.enabled,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Color color;
  final bool enabled;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 18),
      style: FilledButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.14),
      ),
      label: Text(label),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
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
                Text(scenario.status.description,
                    style: theme.textTheme.bodySmall),
                const Spacer(),
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
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                              _MacDot(color: MixBuildPalette.error),
                              const SizedBox(width: 6),
                              _MacDot(color: MixBuildPalette.warning),
                              const SizedBox(width: 6),
                              _MacDot(color: MixBuildPalette.primary),
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

class _FooterBar extends StatelessWidget {
  const _FooterBar({required this.metrics});

  final List<ResourceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: MixBuildPalette.surfaceLow.withValues(alpha: 0.54),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 10,
            children: [
              Text('© 2026 MixBuild Systems', style: theme.textTheme.bodySmall),
              for (final metric in metrics) _MetricBar(metric: metric),
              Row(
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
                  Text(
                    'Connected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: MixBuildPalette.primary,
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

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.metric});

  final ResourceMetric metric;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${metric.label}: ${metric.value}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: metric.color),
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

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label, required this.color});

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

class _MacDot extends StatelessWidget {
  const _MacDot({required this.color});

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

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

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

class _YamlEditorDialog extends StatefulWidget {
  const _YamlEditorDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_YamlEditorDialog> createState() => _YamlEditorDialogState();
}

class _YamlEditorDialogState extends State<_YamlEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
            decoration: MixBuildTheme.glassPanel(radius: 20),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.data_object_outlined,
                        color: MixBuildPalette.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'YAML Configuration Override',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 48,
                          padding: const EdgeInsets.only(top: 16, right: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            border: Border(
                              right: BorderSide(
                                color: Colors.white.withValues(alpha: 0.04),
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(
                              12,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${index + 1}',
                                  style: MixBuildTheme.monoTextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.28),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            keyboardType: TextInputType.multiline,
                            style: MixBuildTheme.monoTextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              height: 1.6,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_controller.text),
                        child: const Text('Save Configuration'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigCenterDialog extends StatefulWidget {
  const _ConfigCenterDialog({required this.config});

  final GlobalConfig config;

  @override
  State<_ConfigCenterDialog> createState() => _ConfigCenterDialogState();
}

class _ConfigCenterDialogState extends State<_ConfigCenterDialog> {
  late final TextEditingController _workspaceController;
  late final TextEditingController _projectNameController;
  late final List<TextEditingController> _bindingControllers;

  @override
  void initState() {
    super.initState();
    _workspaceController =
        TextEditingController(text: widget.config.workspaceRoot);
    _projectNameController =
        TextEditingController(text: widget.config.activeProjectName);
    _bindingControllers = widget.config.bindings
        .map((binding) => TextEditingController(text: binding.path))
        .toList();
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    _projectNameController.dispose();
    for (final controller in _bindingControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      child: Stack(
        children: [
          const _DashboardBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1200, maxHeight: 860),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: MixBuildTheme.glassPanel(radius: 28),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '工程配置中心',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                ),
                                SizedBox(
                                  width: 240,
                                  child: TextField(
                                      controller: _projectNameController),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(28),
                              children: [
                                Text(
                                  '工作区根路径',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(color: MixBuildPalette.muted),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                          controller: _workspaceController),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(
                                          Icons.folder_open_outlined),
                                      label: const Text('浏览...'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  '主工程绑定',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(color: MixBuildPalette.muted),
                                ),
                                const SizedBox(height: 16),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: widget.config.bindings.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 2.6,
                                  ),
                                  itemBuilder: (context, index) {
                                    final binding =
                                        widget.config.bindings[index];
                                    return Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.08),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            binding.projectName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 12),
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  _bindingControllers[index],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('取消'),
                                ),
                                const SizedBox(width: 12),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(
                                      widget.config.copyWith(
                                        workspaceRoot:
                                            _workspaceController.text,
                                        activeProjectName:
                                            _projectNameController.text,
                                        bindings: [
                                          for (var i = 0;
                                              i < widget.config.bindings.length;
                                              i++)
                                            WorkspaceBinding(
                                              projectName: widget.config
                                                  .bindings[i].projectName,
                                              path: _bindingControllers[i].text,
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: const Text('保存全局配置'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddScenarioDialog extends StatefulWidget {
  const _AddScenarioDialog({required this.baseDependencies});

  final List<DependencyBranch> baseDependencies;

  @override
  State<_AddScenarioDialog> createState() => _AddScenarioDialogState();
}

class _AddScenarioDialogState extends State<_AddScenarioDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _commandController;
  late final TextEditingController _outputController;
  late final TextEditingController _tagController;
  bool _autoTag = true;
  late Map<String, String> _branches;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Production_v1');
    _commandController =
        TextEditingController(text: './gradlew assembleRelease');
    _outputController = TextEditingController(text: 'output_dir/');
    _tagController = TextEditingController(text: 'release_');
    _branches = {
      for (final item in widget.baseDependencies) item.name: item.branch
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _outputController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
            decoration: MixBuildTheme.glassPanel(radius: 24),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_box_outlined,
                        color: MixBuildPalette.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '新增构建场景',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        '基本信息',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: MixBuildPalette.muted),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: '场景名称'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _commandController,
                        decoration: const InputDecoration(labelText: '构建命令'),
                        minLines: 3,
                        maxLines: 3,
                        style: MixBuildTheme.monoTextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '依赖分支覆盖',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: MixBuildPalette.muted),
                            ),
                          ),
                          Text(
                            '${widget.baseDependencies.length} Dependencies Detected',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final dependency in widget.baseDependencies)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  dependency.icon,
                                  color: dependency.highlight ??
                                      MixBuildPalette.muted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(dependency.name)),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _branches[dependency.name],
                                    dropdownColor:
                                        MixBuildPalette.surfaceHighest,
                                    items: <String>{
                                      dependency.branch,
                                      'master',
                                      'develop',
                                      'feature/v1',
                                      'release/2.4',
                                    }.map((item) {
                                      return DropdownMenuItem<String>(
                                        value: item,
                                        child: Text(item),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setState(() {
                                        _branches[dependency.name] = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        '高级选项',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: MixBuildPalette.muted),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _outputController,
                        decoration: const InputDecoration(labelText: '输出路径'),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              MixBuildPalette.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                MixBuildPalette.primary.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '自动打标签',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '构建成功后自动应用 Git Tag',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _autoTag,
                                  onChanged: (value) =>
                                      setState(() => _autoTag = value),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _tagController,
                              enabled: _autoTag,
                              decoration:
                                  const InputDecoration(labelText: '标签前缀'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            BuildScenario(
                              id: 'scenario-${DateTime.now().millisecondsSinceEpoch}',
                              name: _nameController.text.trim().isEmpty
                                  ? '新场景'
                                  : _nameController.text.trim(),
                              subtitle: '手动新增场景',
                              environment: 'custom',
                              mainBranch: 'develop',
                              command: _commandController.text.trim(),
                              status: BuildStatus.idle,
                              progress: 0,
                              logs: [
                                LogEntry(
                                  time: '19:22:10',
                                  level: 'INIT',
                                  message:
                                      'Scenario created and waiting for execution',
                                  accent: MixBuildPalette.primary,
                                ),
                              ],
                              dependencies: widget.baseDependencies.map((item) {
                                return DependencyBranch(
                                  name: item.name,
                                  branch: _branches[item.name] ?? item.branch,
                                  icon: item.icon,
                                  isOverride:
                                      (_branches[item.name] ?? item.branch) !=
                                          item.branch,
                                  highlight: item.highlight,
                                );
                              }).toList(),
                              outputPath: _outputController.text.trim(),
                              autoTag: _autoTag,
                              tagPrefix: _tagController.text.trim(),
                            ),
                          );
                        },
                        child: const Text('确认新增场景'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
