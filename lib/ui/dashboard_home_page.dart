import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/responsive_layout.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/state/app_info_provider.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/ui/build_logs_page.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';
import 'package:mixbuild_dashboard/ui/project_detail_page.dart';
import 'package:mixbuild_dashboard/ui/project_editor_page.dart';
import 'package:mixbuild_dashboard/ui/settings_page.dart';
import 'package:mixbuild_dashboard/ui/yaml_editor_page.dart';

class DashboardHomePage extends ConsumerWidget {
  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final responsive = ResponsiveLayout.of(context);
    final strings = AppStrings.of(context);
    final appVersion = ref.watch(appVersionProvider).value ?? '';

    Future<void> openYamlPage() async {
      final result = await YamlEditorPage.show(
        context,
        initialValue: controller.readCurrentYaml(),
        title: strings.projectYamlTitle,
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
      final project = targetProject ??
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
        primaryActionLabel: title == strings.projectNewTitle
            ? strings.projectNewAction
            : strings.projectSaveConfig,
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
        title: strings.projectNewTitle,
        primaryActionLabel: strings.projectNewAction,
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

    Future<void> openBuildLogsPage({String? initialExecutionId}) async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => BuildLogsPage(
            initialExecutionId: initialExecutionId,
          ),
        ),
      );
    }

    Future<void> openSettingsPage() async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => const SettingsPage(),
        ),
      );
    }

    Future<void> handleNavigationSelection(
      int index, {
      bool closeDrawer = false,
    }) async {
      if (closeDrawer) {
        Navigator.of(context).pop();
      }
      switch (index) {
        case 1:
          await openBuildLogsPage();
          break;
        case 2:
          await openSettingsPage();
          break;
        case 0:
        default:
          break;
      }
    }

    Future<void> handleCreateProject({bool closeDrawer = false}) async {
      if (closeDrawer) {
        Navigator.of(context).pop();
      }
      await createNewProject();
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
                  runningCount: dashboardState.runningCount,
                  onReloadTopology: controller.reloadTopology,
                  version: appVersion,
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
                            title: strings.projectEditTitle,
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
                  version: appVersion,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final drawer = responsive.isCompact
        ? Drawer(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            child: SafeArea(
              child: _DashboardNavigationMenu(
                onCreateProject: () => handleCreateProject(closeDrawer: true),
                onDestinationSelected: (index) => handleNavigationSelection(
                  index,
                  closeDrawer: true,
                ),
                compact: true,
                version: appVersion,
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
                        tooltip: strings.navOpenMenu,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      _DashboardNavigationMenu(
                        onCreateProject: handleCreateProject,
                        onDestinationSelected: handleNavigationSelection,
                        version: appVersion,
                      ),
                      Expanded(child: buildMainContent()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DashboardNavigationMenu extends StatelessWidget {
  const _DashboardNavigationMenu({
    required this.onCreateProject,
    required this.onDestinationSelected,
    this.compact = false,
    required this.version,
  });

  final VoidCallback onCreateProject;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;
  final String version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(strings.navDashboard),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: Text(strings.navBuildLogs),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(strings.navSettings),
      ),
    ];

    final drawerDestinations = <Widget>[
      NavigationDrawerDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(strings.navDashboard),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: Text(strings.navBuildLogs),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(strings.navSettings),
      ),
    ];

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.appBrand,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.appVersionWith(version),
            style: theme.textTheme.bodySmall?.copyWith(
              letterSpacing: 1.1,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    final footer = Column(
      children: [
        Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
        ListTile(
          dense: true,
          leading: const Icon(Icons.help_outline, size: 18),
          title: Text(strings.navSupport, style: theme.textTheme.bodySmall),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.description_outlined, size: 18),
          title: Text(strings.navDocs, style: theme.textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(strings.copyright, style: theme.textTheme.bodySmall),
        ),
      ],
    );

    if (compact) {
      return NavigationDrawer(
        selectedIndex: 0,
        onDestinationSelected: onDestinationSelected,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: onCreateProject,
              icon: const Icon(Icons.add),
              label: Text(strings.navNewProject),
            ),
          ),
          ...drawerDestinations,
          const SizedBox(height: 12),
          footer,
        ],
      );
    }

    return Container(
      width: 300,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: MixBuildTheme.surfacePanel(
        context,
        radius: 28,
        color: colorScheme.surfaceContainerLow,
      ),
      child: Column(
        children: [
          header,
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreateProject,
                icon: const Icon(Icons.add),
                label: Text(strings.navNewProject),
              ),
            ),
          ),
          Expanded(
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: 0,
              extended: true,
              minExtendedWidth: 220,
              destinations: destinations,
              onDestinationSelected: onDestinationSelected,
              useIndicator: true,
              groupAlignment: -1,
            ),
          ),
          footer,
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
    final strings = AppStrings.of(context);
    return Container(
      decoration: MixBuildTheme.surfacePanel(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: MixBuildPalette.surfaceHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: MixBuildPalette.foreground.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Column(
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OverflowBar(
                      spacing: 8,
                      children: [
                        IconButton(
                          onPressed: onOpenYaml,
                          icon:
                              const Icon(Icons.data_object_outlined, size: 18),
                          color: MixBuildPalette.muted,
                          tooltip: strings.yamlOverride,
                        ),
                        IconButton.filledTonal(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: strings.btnEdit,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
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
    final strings = AppStrings.of(context);
    final isActive = scenario.status.isPipelineActive;
    final canStop = scenario.status.canStop;
    final actionLabel = canStop ? strings.btnStop : strings.btnView;
    final actionColor =
        canStop ? MixBuildPalette.error : MixBuildPalette.primary;

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
                  : MixBuildPalette.surfaceHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? scenario.status.color.withValues(alpha: 0.32)
                : selected
                    ? scenario.status.color.withValues(alpha: 0.24)
                    : MixBuildTheme.surfacePanelBorderColor(context),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Column(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                Flexible(
                  child: Align(
                    alignment: Alignment.center,
                    child: StatusChip(status: scenario.status),
                  ),
                ),
                const SizedBox(width: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ScenarioActionButton(
                    color: actionColor,
                    enabled: true,
                    label: actionLabel,
                    icon: canStop
                        ? Icons.stop_circle_outlined
                        : Icons.rocket_launch_outlined,
                    filled: canStop,
                    onPressed: onTap,
                  ),
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
                  color: MixBuildPalette.foreground.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (final log in scenario.logs.take(3))
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
                                  color: MixBuildPalette.foreground.withValues(
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
                      child: LinearProgressIndicator(
                        value: scenario.progress,
                        minHeight: 3,
                        backgroundColor: MixBuildPalette.foreground.withValues(
                          alpha: 0.08,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          scenario.status.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
