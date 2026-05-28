import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/responsive_layout.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/state/dashboard_state.dart';
import 'package:mixbuild_dashboard/ui/build_logs_page.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';
import 'package:mixbuild_dashboard/ui/log_viewport.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/ui/project_editor_page.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.scenarioId,
  });

  final String projectId;
  final String scenarioId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  DashboardController get _controller =>
      ref.read(dashboardControllerProvider.notifier);
  final TextEditingController _logSearchController = TextEditingController();
  String _logSearchQuery = '';
  int _visibleTerminalLogCount = kProjectDetailLogPageSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(dashboardControllerProvider);
      final project = state.projects.firstWhere(
        (item) => item.id == widget.projectId,
        orElse: () => state.selectedProject,
      );
      final scenario = project.scenarios.firstWhere(
        (item) => item.id == widget.scenarioId,
        orElse: () => project.scenarios.first,
      );
      _controller.selectScenario(project, scenario);
    });
  }

  @override
  void dispose() {
    _logSearchController.dispose();
    super.dispose();
  }

  Future<void> _saveScenarioLogs(
    ProjectBuild project,
    BuildScenario scenario,
  ) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName =
        '${_sanitizeFileName(project.name)}-${_sanitizeFileName(scenario.name)}-$timestamp.log';
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) {
      return;
    }
    final lines = scenario.logs.reversed.map((log) {
      return '[${log.time}] [${log.level}] ${log.message}';
    }).join('\n');
    await File(location.path).writeAsString('$lines\n');
    if (!mounted) {
      return;
    }
    final strings = AppStrings.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.logSaved(location.path))));
  }

  String _sanitizeFileName(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.trim().codeUnits) {
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isUpperAlpha = codeUnit >= 65 && codeUnit <= 90;
      final isLowerAlpha = codeUnit >= 97 && codeUnit <= 122;
      final isSafeSymbol = codeUnit == 45 || codeUnit == 46 || codeUnit == 95;
      buffer.write(
        isDigit || isUpperAlpha || isLowerAlpha || isSafeSymbol
            ? String.fromCharCode(codeUnit)
            : '_',
      );
    }
    final sanitized = buffer.toString();
    return sanitized.isEmpty ? 'mixbuild' : sanitized;
  }

  Future<void> _openProjectEditor(DashboardState dashboardState) async {
    final strings = AppStrings.of(context);
    final result = await ProjectEditorPage.show(
      context,
      config: dashboardState.globalConfig,
      scenarios: dashboardState.selectedProject.scenarios,
      baseDependencies: _controller.editorBaseDependencies(),
      title: strings.projectEditTitle,
      primaryActionLabel: strings.projectSaveConfig,
    );
    if (result == null) return;
    await _controller.updateProjectConfiguration(
      config: result.config,
      bindings: result.bindings,
      scenarios: result.scenarios,
    );
  }

  Future<void> _openBuildLogsPage(
    DashboardState dashboardState,
    ProjectBuild project,
    BuildScenario scenario,
  ) async {
    String? latestRecordId;
    for (final record in dashboardState.executionHistory) {
      if (record.projectId == project.id && record.scenarioId == scenario.id) {
        latestRecordId = record.id;
        break;
      }
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BuildLogsPage(
          initialExecutionId: latestRecordId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final selectedProject = dashboardState.selectedProject;
    final selectedScenario = dashboardState.selectedScenario;
    final responsive = ResponsiveLayout.of(context);
    final logViewport = buildLogViewport(
      logs: selectedScenario.logs,
      query: _logSearchQuery,
      visibleCount: _visibleTerminalLogCount,
    );

    final sidebarPanel = _SidebarPanel(
      project: selectedProject,
      scenario: selectedScenario,
      branchOptions: _controller.branchOptions(selectedProject),
      onBranchChanged: _controller.changeProjectBranch,
      onScenarioChanged: _controller.changeScenario,
      onDependencyBranchChanged: _controller.changeDependencyBranch,
      dependencyBranchOptions: _controller.dependencyBranchOptions,
      cleanBeforeBuild:
          dashboardState.cleanBeforeBuild[dashboardState.selectedScenarioId] ??
              false,
      onCleanChanged: _controller.setCleanBeforeBuild,
      onTrigger: _controller.triggerSelectedScenario,
      onStop: _controller.stopSelectedScenario,
      onOpenSettings: () => _openProjectEditor(dashboardState),
      onBack: () => Navigator.of(context).pop(),
      stacked: !responsive.isWide,
      width: responsive.detailSidebarWidth,
    );

    final terminalSection = Column(
      children: [
        _PipelineHeader(
          scenario: selectedScenario,
          onOpenHistory: () => _openBuildLogsPage(
            dashboardState,
            selectedProject,
            selectedScenario,
          ),
        ),
        Expanded(
          child: Padding(
            padding: responsive.shellPadding,
            child: _TerminalPanel(
              project: selectedProject,
              scenario: selectedScenario,
              visibleLogs: logViewport.visibleLogs,
              hiddenLogCount: logViewport.hiddenCount,
              searchController: _logSearchController,
              searchQuery: _logSearchQuery,
              onSearchChanged: (value) {
                setState(() {
                  _logSearchQuery = value;
                  _visibleTerminalLogCount = kProjectDetailLogPageSize;
                });
              },
              onLoadOlderLogs: logViewport.canLoadOlder
                  ? () {
                      setState(() {
                        _visibleTerminalLogCount += kProjectDetailLogPageSize;
                      });
                    }
                  : null,
              onSaveLogs: () => _saveScenarioLogs(
                selectedProject,
                selectedScenario,
              ),
            ),
          ),
        ),
        if (!responsive.isWide || responsive.isCompact)
          Padding(
            padding: EdgeInsets.fromLTRB(
              responsive.shellPadding.left,
              0,
              responsive.shellPadding.right,
              responsive.shellPadding.bottom,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _HudOverlay(metrics: dashboardState.metrics),
            ),
          ),
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          const DashboardBackground(),
          SafeArea(
            child: responsive.isWide
                ? Row(
                    children: [
                      sidebarPanel,
                      Expanded(
                        child: Stack(
                          children: [
                            terminalSection,
                            Positioned(
                              bottom: 36,
                              right: 36,
                              child: _HudOverlay(
                                metrics: dashboardState.metrics,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          responsive.shellPadding.left,
                          responsive.shellPadding.top,
                          responsive.shellPadding.right,
                          0,
                        ),
                        child: sidebarPanel,
                      ),
                      Expanded(child: terminalSection),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({
    required this.project,
    required this.scenario,
    required this.branchOptions,
    required this.onBranchChanged,
    required this.onScenarioChanged,
    required this.onDependencyBranchChanged,
    required this.dependencyBranchOptions,
    required this.cleanBeforeBuild,
    required this.onCleanChanged,
    required this.onTrigger,
    required this.onStop,
    required this.onOpenSettings,
    required this.onBack,
    required this.stacked,
    required this.width,
  });

  final ProjectBuild project;
  final BuildScenario scenario;
  final List<String> branchOptions;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<String> onScenarioChanged;
  final void Function(String dependencyName, String branch)
      onDependencyBranchChanged;
  final List<String> Function(DependencyBranch dependency)
      dependencyBranchOptions;
  final bool cleanBeforeBuild;
  final ValueChanged<bool> onCleanChanged;
  final VoidCallback onTrigger;
  final VoidCallback onStop;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;
  final bool stacked;
  final double width;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarSectionLabel(label: strings.projectWorkspace),
          const SizedBox(height: 8),
          _WorkspaceChip(project: project),
          const SizedBox(height: 20),
          _SidebarSectionLabel(label: strings.projectScenarios),
          const SizedBox(height: 8),
          _ScenarioCard(
            project: project,
            scenario: scenario,
            onScenarioChanged: onScenarioChanged,
          ),
          const SizedBox(height: 20),
          _SidebarSectionLabel(label: strings.mainProjectBranch),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: MixBuildPalette.foreground.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MixBuildPalette.foreground.withValues(alpha: 0.06),
              ),
            ),
            child: Text(
              scenario.mainBranch,
              style: MixBuildTheme.monoTextStyle(
                fontSize: 13,
                color: MixBuildPalette.foreground,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SidebarSectionLabel(
            label: strings.dependencyTopologyMatrix,
            trailing: '${scenario.dependencies.length} NODES',
          ),
          const SizedBox(height: 8),
          _DependencyTree(
            project: project,
            scenario: scenario,
            onDependencyBranchChanged: onDependencyBranchChanged,
            dependencyBranchOptions: dependencyBranchOptions,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );

    return Container(
      width: stacked ? double.infinity : width,
      decoration: BoxDecoration(
        color: MixBuildPalette.surfaceLow,
        border: Border(
          right: stacked
              ? BorderSide.none
              : BorderSide(
                  color: MixBuildPalette.foreground.withValues(alpha: 0.1),
                ),
        ),
      ),
      child: Column(
        children: [
          _SidebarHeader(onBack: onBack, onOpenSettings: onOpenSettings),
          if (stacked)
            content
          else
            Expanded(child: SingleChildScrollView(child: content)),
          _SidebarFooter(
            scenario: scenario,
            cleanBeforeBuild: cleanBeforeBuild,
            onCleanChanged: onCleanChanged,
            onTrigger: onTrigger,
            onStop: onStop,
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.onBack, required this.onOpenSettings});

  final VoidCallback onBack;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: MixBuildPalette.foreground.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MixBuildPalette.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: MixBuildPalette.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              Icons.terminal,
              color: MixBuildPalette.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.appTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  strings.appVersion,
                  style: MixBuildTheme.monoTextStyle(
                    fontSize: 10,
                    color: MixBuildPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpenSettings,
            icon: Icon(
              Icons.settings_outlined,
              size: 20,
              color: MixBuildPalette.muted,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: strings.projectEditTooltip,
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MixBuildPalette.muted,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing!,
            style: MixBuildTheme.monoTextStyle(
              fontSize: 10,
              color: MixBuildPalette.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({required this.project});

  final ProjectBuild project;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MixBuildPalette.foreground.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MixBuildPalette.foreground.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_outlined,
            color: MixBuildPalette.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              project.name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: MixBuildPalette.success,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.project,
    required this.scenario,
    required this.onScenarioChanged,
  });

  final ProjectBuild project;
  final BuildScenario scenario;
  final ValueChanged<String> onScenarioChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MixBuildPalette.foreground.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MixBuildPalette.foreground.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MixBuildPalette.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.rocket_launch_outlined,
                  color: MixBuildPalette.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target: ${scenario.environment} • ${scenario.subtitle}',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (project.scenarios.length > 1) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: scenario.id,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              onChanged: scenario.status.controlsLocked
                  ? null
                  : (v) {
                      if (v != null) onScenarioChanged(v);
                    },
              items: project.scenarios
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.name),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DependencyTree extends StatelessWidget {
  const _DependencyTree({
    required this.project,
    required this.scenario,
    required this.onDependencyBranchChanged,
    required this.dependencyBranchOptions,
  });

  final ProjectBuild project;
  final BuildScenario scenario;
  final void Function(String dependencyName, String branch)
      onDependencyBranchChanged;
  final List<String> Function(DependencyBranch dependency)
      dependencyBranchOptions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MixBuildPalette.foreground.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MixBuildPalette.foreground.withValues(alpha: 0.06),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Root node
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.hub_outlined,
                  color: MixBuildPalette.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.name,
                    overflow: TextOverflow.ellipsis,
                    style: MixBuildTheme.monoTextStyle(
                      fontSize: 12,
                      color: MixBuildPalette.foreground,
                    ),
                  ),
                ),
                Text(
                  project.branch,
                  style: MixBuildTheme.monoTextStyle(
                    fontSize: 10,
                    color: MixBuildPalette.muted,
                  ),
                ),
              ],
            ),
          ),
          // Children with tree lines
          if (scenario.dependencies.isNotEmpty)
            Stack(
              children: [
                Positioned(
                  left: 15,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: MixBuildPalette.foreground.withValues(alpha: 0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    children: scenario.dependencies
                        .map(
                          (dep) => _DependencyTreeNode(
                            dependency: dep,
                            isLocked: scenario.status.controlsLocked,
                            options: dependencyBranchOptions(dep),
                            onBranchChanged: (b) =>
                                onDependencyBranchChanged(dep.name, b),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DependencyTreeNode extends StatelessWidget {
  const _DependencyTreeNode({
    required this.dependency,
    required this.isLocked,
    required this.options,
    required this.onBranchChanged,
  });

  final DependencyBranch dependency;
  final bool isLocked;
  final List<String> options;
  final ValueChanged<String> onBranchChanged;

  Color get _nodeColor => dependency.isOverride
      ? MixBuildPalette.primary
      : MixBuildPalette.foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Stack(
      children: [
        Positioned(
          left: -5,
          top: 18,
          child: Container(
            width: 10,
            height: 1,
            color: MixBuildPalette.foreground.withValues(alpha: 0.1),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: dependency.isOverride
              ? BoxDecoration(
                  color: MixBuildPalette.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MixBuildPalette.error.withValues(alpha: 0.1),
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(dependency.icon, size: 14, color: _nodeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dependency.name,
                      overflow: TextOverflow.ellipsis,
                      style: MixBuildTheme.monoTextStyle(
                        fontSize: 12,
                        color: _nodeColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _nodeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _nodeColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      dependency.isOverride
                          ? strings.dependencyOverride
                          : strings.dependencyDefault,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _nodeColor,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: MixBuildPalette.foreground.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MixBuildPalette.foreground.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  dependency.branch,
                  style: MixBuildTheme.monoTextStyle(
                    fontSize: 12,
                    color: _nodeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.scenario,
    required this.cleanBeforeBuild,
    required this.onCleanChanged,
    required this.onTrigger,
    required this.onStop,
  });

  final BuildScenario scenario;
  final bool cleanBeforeBuild;
  final ValueChanged<bool> onCleanChanged;
  final VoidCallback onTrigger;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MixBuildPalette.foreground.withValues(alpha: 0.02),
        border: Border(
          top: BorderSide(
            color: MixBuildPalette.foreground.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(strings.currentStatus, style: theme.textTheme.bodySmall),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: scenario.status.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                scenario.status.labelWithContext(context),
                style: MixBuildTheme.monoTextStyle(
                  fontSize: 11,
                  color: scenario.status.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: cleanBeforeBuild,
                onChanged: scenario.status.controlsLocked
                    ? null
                    : (v) => onCleanChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  strings.scenarioCleanBeforeShort,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: scenario.status.canTrigger ? onTrigger : null,
              icon: Icon(
                scenario.status.controlsLocked ? Icons.sync : Icons.play_arrow,
              ),
              label: Text(scenario.status.triggerLabelWithContext(context)),
              style: FilledButton.styleFrom(
                backgroundColor: MixBuildPalette.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (scenario.status.canStop) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(strings.btnStop),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MixBuildPalette.error,
                  side: BorderSide(
                    color: MixBuildPalette.error.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right Panel – Pipeline Header
// ─────────────────────────────────────────────────────────────────────────────

class _PipelineHeader extends StatelessWidget {
  const _PipelineHeader({
    required this.scenario,
    required this.onOpenHistory,
  });

  final BuildScenario scenario;
  final VoidCallback onOpenHistory;

  static const _steps = [
    BuildStatus.idle,
    BuildStatus.validating,
    BuildStatus.syncing,
    BuildStatus.building,
    BuildStatus.postHook,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final chipStrip = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MixBuildPalette.foreground.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MixBuildPalette.foreground.withValues(alpha: 0.1),
        ),
      ),
      child:
          Row(mainAxisSize: MainAxisSize.min, children: _buildChips(context)),
    );

    final statusSummary = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule_outlined,
          size: 16,
          color: MixBuildPalette.muted.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 6),
        Text(
          scenario.status.descriptionWithContext(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    final historyButton = OutlinedButton(
      onPressed: onOpenHistory,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 36),
      ),
      child: Text(strings.navBuildLogs),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1180;
        final alignedSummary = Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [statusSummary, historyButton],
          ),
        );
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            compact ? 14 : 0,
            24,
            compact ? 14 : 0,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: MixBuildPalette.foreground.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: chipStrip,
                    ),
                    const SizedBox(height: 12),
                    alignedSummary,
                  ],
                )
              : SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      Flexible(child: chipStrip),
                      const SizedBox(width: 16),
                      Expanded(child: alignedSummary),
                    ],
                  ),
                ),
        );
      },
    );
  }

  List<Widget> _buildChips(BuildContext context) {
    final currentIndex =
        _steps.contains(scenario.status) ? _steps.indexOf(scenario.status) : -1;
    final result = <Widget>[];
    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      final active = step == scenario.status;
      final dimmed = currentIndex >= 0 && i > currentIndex;
      result.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? MixBuildPalette.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            step.labelWithContext(context),
            style: MixBuildTheme.monoTextStyle(
              fontSize: 11,
              color: active
                  ? MixBuildPalette.primary
                  : MixBuildPalette.muted.withValues(
                      alpha: dimmed ? 0.45 : 1.0,
                    ),
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      if (i < _steps.length - 1) {
        result.add(
          Icon(
            Icons.chevron_right,
            size: 14,
            color: MixBuildPalette.foreground.withValues(alpha: 0.2),
          ),
        );
      }
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right Panel – Terminal
// ─────────────────────────────────────────────────────────────────────────────

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({
    required this.project,
    required this.scenario,
    required this.visibleLogs,
    required this.hiddenLogCount,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onLoadOlderLogs,
    required this.onSaveLogs,
  });

  final ProjectBuild project;
  final BuildScenario scenario;
  final List<LogEntry> visibleLogs;
  final int hiddenLogCount;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onLoadOlderLogs;
  final VoidCallback onSaveLogs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Container(
      decoration: BoxDecoration(
        color: MixBuildPalette.surfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MixBuildPalette.foreground.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          // Title bar
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: MixBuildPalette.surfaceHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: MixBuildPalette.foreground.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                MacDot(color: MixBuildPalette.error),
                const SizedBox(width: 6),
                MacDot(color: MixBuildPalette.warning),
                const SizedBox(width: 6),
                MacDot(color: MixBuildPalette.primary),
                const SizedBox(width: 16),
                Icon(Icons.terminal, size: 14, color: MixBuildPalette.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    strings.terminalTitle(scenario.command, project.name),
                    overflow: TextOverflow.ellipsis,
                    style: MixBuildTheme.monoTextStyle(
                      fontSize: 11,
                      color: MixBuildPalette.muted,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: scenario.logs.isEmpty ? null : onSaveLogs,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  color: MixBuildPalette.muted,
                  disabledColor: MixBuildPalette.muted.withValues(alpha: 0.28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: strings.btnSave,
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
                color: MixBuildPalette.foreground,
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
          // Log output
          Expanded(
            child: scenario.logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.terminal,
                          size: 32,
                          color: MixBuildPalette.muted.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.readyForCommand(project.name),
                          style: MixBuildTheme.monoTextStyle(
                            fontSize: 12,
                            color: MixBuildPalette.muted.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : visibleLogs.isEmpty
                    ? Center(
                        child: Text(
                          strings.noLogMatch(searchQuery),
                          style: MixBuildTheme.monoTextStyle(
                            fontSize: 12,
                            color:
                                MixBuildPalette.muted.withValues(alpha: 0.55),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount:
                            visibleLogs.length + (hiddenLogCount > 0 ? 1 : 0),
                        separatorBuilder: (_, r) => const SizedBox(height: 6),
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
                                  overflow: TextOverflow.clip,
                                  style: MixBuildTheme.monoTextStyle(
                                    fontSize: 12,
                                    color: MixBuildPalette.muted
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  '[${log.level}]',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
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
                                    color: MixBuildPalette.foreground,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          // Progress footer
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      scenario.outputPath,
                      style: MixBuildTheme.monoTextStyle(
                        fontSize: 11,
                        color: MixBuildPalette.muted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(scenario.progress * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scenario.status.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: scenario.status == BuildStatus.idle
                      ? 0.0
                      : scenario.progress,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor:
                      MixBuildPalette.foreground.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    scenario.status.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD Overlay (bottom-right of terminal area)
// ─────────────────────────────────────────────────────────────────────────────

class _HudOverlay extends StatelessWidget {
  const _HudOverlay({required this.metrics});

  final List<ResourceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: MixBuildTheme.surfacePanel(
        radius: 14,
        color: MixBuildPalette.surfaceHigh,
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final metric in metrics) _HudMetric(metric: metric),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_done_outlined,
                size: 18,
                color: MixBuildPalette.primary,
              ),
              const SizedBox(width: 8),
              Text(
                strings.connectedStatus,
                style: MixBuildTheme.monoTextStyle(
                  fontSize: 10,
                  color: MixBuildPalette.foreground,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudMetric extends StatelessWidget {
  const _HudMetric({required this.metric});

  final ResourceMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label.toUpperCase(),
          style: MixBuildTheme.monoTextStyle(
            fontSize: 9,
            color: MixBuildPalette.muted,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(
                      color: MixBuildPalette.foreground.withValues(alpha: 0.1),
                    ),
                    FractionallySizedBox(
                      widthFactor: metric.progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: metric.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              metric.value,
              style: MixBuildTheme.monoTextStyle(
                fontSize: 10,
                color: MixBuildPalette.foreground,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}
