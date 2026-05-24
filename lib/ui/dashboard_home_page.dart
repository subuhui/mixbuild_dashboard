import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/responsive_layout.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';
import 'package:mixbuild_dashboard/ui/project_detail_page.dart';
import 'package:mixbuild_dashboard/ui/project_editor_page.dart';
import 'package:mixbuild_dashboard/ui/yaml_editor_page.dart';

class DashboardHomePage extends ConsumerWidget {
  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final responsive = ResponsiveLayout.of(context);

    Future<void> openYamlPage() async {
      final result = await YamlEditorPage.show(
        context,
        initialValue: controller.readCurrentYaml(),
        title: '当前项目 YAML',
      );
      if (result == null) {
        return;
      }
      await controller.saveCurrentYaml(result);
    }

    Future<void> openProjectEditor({
      required String title,
      ProjectBuild? targetProject,
    }) async {
      final project =
          targetProject ??
          ref.read(dashboardControllerProvider).selectedProject;
      final projectConfig = controller.configForProject(project);
      final projectGlobalConfig = GlobalConfig(
        workspaceRoot: projectConfig.workspace.rootPath,
        activeProjectName: projectConfig.workspace.name,
        mainProjectDefaultBranch: projectConfig.mainProject.defaultBranch,
        bindings: [
          WorkspaceBinding(
            projectName: projectConfig.mainProject.name,
            path: projectConfig.mainProject.path,
            type: projectConfig.mainProject.type,
            defaultBranch: projectConfig.mainProject.defaultBranch,
            restoreCommand: projectConfig.mainProject.restoreCommand,
          ),
          ...projectConfig.dependencies.map(
            (d) => WorkspaceBinding(
              projectName: d.name,
              path: d.path,
              type: d.type,
              defaultBranch: d.defaultBranch,
              restoreCommand: d.restoreCommand,
            ),
          ),
        ],
      );
      final result = await ProjectEditorPage.show(
        context,
        config: projectGlobalConfig,
        scenarios: project.scenarios,
        baseDependencies: controller.editorBaseDependencies(),
        title: title,
        primaryActionLabel: title == '新增项目' ? '创建项目' : '保存项目配置',
      );
      if (result == null) {
        return;
      }
      controller.selectProject(project);
      await controller.updateProjectConfiguration(
        config: result.config,
        bindings: result.bindings,
        scenarios: result.scenarios,
        targetConfigPath: project.id,
      );
    }

    Future<void> createNewProject() async {
      final emptyConfig = GlobalConfig(
        workspaceRoot: dashboardState.globalConfig.workspaceRoot,
        activeProjectName: '',
        bindings: const [],
      );
      final result = await ProjectEditorPage.show(
        context,
        config: emptyConfig,
        scenarios: const [],
        baseDependencies: const [],
        title: '新增项目',
        primaryActionLabel: '创建项目',
      );
      if (result == null) {
        return;
      }
      await controller.createProject(
        config: result.config,
        bindings: result.bindings,
        scenarios: result.scenarios,
      );
    }

    void openDetail(ProjectBuild project, BuildScenario scenario) {
      controller.selectScenario(project, scenario);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) =>
              ProjectDetailPage(projectId: project.id, scenarioId: scenario.id),
        ),
      );
    }

    Widget buildMainContent({Widget? leading}) {
      return Padding(
        padding: responsive.isCompact
            ? responsive.shellPadding
            : const EdgeInsets.fromLTRB(0, 0, 18, 14),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1360),
            child: Column(
              children: [
                DashboardTopBar(
                  leading: leading,
                  currentWorkspaceName: dashboardState.config.workspace.name,
                  availableWorkspaceNames:
                      dashboardState.availableWorkspaceNames,
                  runningCount: dashboardState.runningCount,
                  onWorkspaceChanged: controller.switchWorkspace,
                  onReloadTopology: controller.reloadTopology,
                  onOpenYaml: openYamlPage,
                  onOpenConfig: () => openProjectEditor(title: '项目编辑'),
                ),
                Expanded(
                  child: Padding(
                    padding: responsive.contentPadding,
                    child: ListView.separated(
                      itemCount: dashboardState.projects.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final project = dashboardState.projects[index];
                        return ProjectOverviewCard(
                          project: project,
                          selectedScenarioId: dashboardState.selectedScenarioId,
                          onEdit: () => openProjectEditor(
                            title: '项目编辑',
                            targetProject: project,
                          ),
                          onOpenScenario: (scenario) =>
                              openDetail(project, scenario),
                          onOpenYaml: () async {
                            controller.selectScenario(
                              project,
                              project.scenarios.first,
                            );
                            await openYamlPage();
                          },
                        );
                      },
                    ),
                  ),
                ),
                DashboardFooterBar(
                  metrics: dashboardState.metrics,
                  projects: dashboardState.projects,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final drawer = responsive.isCompact
        ? Drawer(
            backgroundColor: MixBuildPalette.surface,
            child: SafeArea(
              child: _DashboardNavRail(
                onCreateProject: createNewProject,
                compact: true,
              ),
            ),
          )
        : null;

    return Scaffold(
      drawer: drawer,
      body: Stack(
        children: [
          const DashboardBackground(),
          SafeArea(
            child: responsive.isCompact
                ? Builder(
                    builder: (innerContext) => buildMainContent(
                      leading: IconButton(
                        onPressed: Scaffold.of(innerContext).openDrawer,
                        icon: const Icon(Icons.menu_rounded),
                        tooltip: 'Open navigation',
                      ),
                    ),
                  )
                : Row(
                    children: [
                      _DashboardNavRail(onCreateProject: createNewProject),
                      Expanded(child: buildMainContent()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DashboardNavRail extends StatelessWidget {
  const _DashboardNavRail({
    required this.onCreateProject,
    this.compact = false,
  });

  final VoidCallback onCreateProject;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: compact ? 280 : 252,
      margin: compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: MixBuildPalette.surfaceLow.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(compact ? 0 : 28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(8, 0),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MixBuild',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: MixBuildPalette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v3.1.0-stable',
                  style: theme.textTheme.bodySmall?.copyWith(
                    letterSpacing: 1.1,
                    color: MixBuildPalette.muted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            active: true,
          ),
          const _NavItem(icon: Icons.folder_copy_outlined, label: 'Projects'),
          const _NavItem(
            icon: Icons.receipt_long_outlined,
            label: 'Build Logs',
          ),
          const _NavItem(icon: Icons.settings_outlined, label: 'Settings'),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add),
            label: const Text('New Project'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: theme.textTheme.labelLarge,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 16,
                        color: MixBuildPalette.muted,
                      ),
                      const SizedBox(width: 10),
                      Text('Support', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: MixBuildPalette.muted,
                      ),
                      const SizedBox(width: 10),
                      Text('Docs', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('© 2026', style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: active
            ? MixBuildPalette.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: active
            ? Border.all(color: MixBuildPalette.primary.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? MixBuildPalette.primary : MixBuildPalette.muted,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: active ? Colors.white : MixBuildPalette.muted,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectOverviewCard extends StatelessWidget {
  const ProjectOverviewCard({
    super.key,
    required this.project,
    required this.selectedScenarioId,
    required this.onEdit,
    required this.onOpenScenario,
    required this.onOpenYaml,
  });

  final ProjectBuild project;
  final String selectedScenarioId;
  final VoidCallback onEdit;
  final ValueChanged<BuildScenario> onOpenScenario;
  final VoidCallback onOpenYaml;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: MixBuildTheme.glassPanel(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final actions = [
                  IconButton(
                    onPressed: onOpenYaml,
                    icon: const Icon(Icons.data_object_outlined, size: 18),
                    color: MixBuildPalette.muted,
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('编辑'),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: MixBuildPalette.primary.withValues(
                        alpha: 0.14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.name,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                project.description,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (!compact) ...actions,
                      ],
                    ),
                    if (compact) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: actions),
                    ],
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final scenario in project.scenarios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ScenarioPreviewTile(
                      scenario: scenario,
                      selected: scenario.id == selectedScenarioId,
                      onTap: () => onOpenScenario(scenario),
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

class _ScenarioPreviewTile extends StatelessWidget {
  const _ScenarioPreviewTile({
    required this.scenario,
    required this.selected,
    required this.onTap,
  });

  final BuildScenario scenario;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = scenario.status.isPipelineActive;
    final canStop = scenario.status.canStop;
    final actionLabel = canStop ? '停止' : '查看';
    final actionColor = canStop
        ? MixBuildPalette.error
        : MixBuildPalette.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? scenario.status.color.withValues(alpha: 0.05)
              : selected
              ? scenario.status.color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? scenario.status.color.withValues(alpha: 0.32)
                : selected
                ? scenario.status.color.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.06),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final actionButton = ScenarioActionButton(
              color: actionColor,
              enabled: true,
              label: actionLabel,
              icon: canStop
                  ? Icons.stop_circle_outlined
                  : Icons.rocket_launch_outlined,
              filled: canStop,
              onPressed: onTap,
            );

            return Column(
              children: [
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scenario.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scenario.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isActive
                              ? scenario.status.color.withValues(alpha: 0.6)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(status: scenario.status),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: actionButton,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scenario.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scenario.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isActive
                                    ? scenario.status.color.withValues(
                                        alpha: 0.6,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: StatusChip(status: scenario.status),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actionButton,
                      ),
                    ],
                  ),
                // Active scenario: terminal log panel + progress bar
                if (isActive) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final log in scenario.logs.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 68,
                                  child: Text(
                                    log.time,
                                    style: MixBuildTheme.monoTextStyle(
                                      fontSize: 11,
                                      color: scenario.status.color,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '[${log.level}] ${log.message}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MixBuildTheme.monoTextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.76,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Stack(
                            children: [
                              LinearProgressIndicator(
                                value: scenario.progress,
                                minHeight: 3,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  scenario.status.color,
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: scenario.status.color.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: -1,
                                      ),
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
              ],
            );
          },
        ),
      ),
    );
  }
}
