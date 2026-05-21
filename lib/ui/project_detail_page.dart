import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/state/dashboard_state.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';
import 'package:mixbuild_dashboard/ui/project_editor_page.dart';
import 'package:mixbuild_dashboard/ui/yaml_editor_page.dart';

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
  DashboardController get _controller => ref.read(dashboardControllerProvider.notifier);

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

  Future<void> _openYamlPage() async {
    final initialValue = _controller.readCurrentYaml();
    final result = await YamlEditorPage.show(
      context,
      initialValue: initialValue,
      title: '当前项目 YAML',
    );
    if (result == null) {
      return;
    }
    await _controller.saveCurrentYaml(result);
  }

  Future<void> _openProjectEditor(DashboardState dashboardState) async {
    final result = await ProjectEditorPage.show(
      context,
      config: dashboardState.globalConfig,
      scenarios: dashboardState.selectedProject.scenarios,
      baseDependencies: _controller.editorBaseDependencies(),
      title: '项目编辑',
      primaryActionLabel: '保存项目配置',
    );
    if (result == null) {
      return;
    }
    await _controller.updateProjectConfiguration(
      config: result.config,
      bindings: result.bindings,
      scenarios: result.scenarios,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardControllerProvider);
    final selectedProject = dashboardState.selectedProject;
    final selectedScenario = dashboardState.selectedScenario;
    final isWide = MediaQuery.sizeOf(context).width >= 1380;

    return Scaffold(
      body: Stack(
        children: [
          const DashboardBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: BuildStatus.values.map((status) {
                              return StatusChip(status: status);
                            }).toList(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _openYamlPage,
                          icon: const Icon(Icons.data_object_outlined),
                          label: const Text('编辑 YAML'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _openProjectEditor(dashboardState),
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('编辑项目'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      DashboardSideBar(
                        project: selectedProject,
                        scenario: selectedScenario,
                        cleanBeforeBuild: dashboardState.cleanBeforeBuild[
                                dashboardState.selectedScenarioId] ??
                            false,
                        branchOptions: _controller.branchOptions(selectedProject),
                        onBranchChanged: _controller.changeProjectBranch,
                        onScenarioChanged: _controller.changeScenario,
                        onDependencyBranchChanged: _controller.changeDependencyBranch,
                        dependencyBranchOptions: _controller.dependencyBranchOptions,
                        onCleanChanged: _controller.setCleanBeforeBuild,
                        onTrigger: _controller.triggerSelectedScenario,
                        onStop: _controller.stopSelectedScenario,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedProject.name,
                                            style: Theme.of(context).textTheme.headlineMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            selectedScenario.name,
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    TinyBadge(
                                      label: selectedScenario.status.description,
                                      color: selectedScenario.status.color,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: isWide
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 7,
                                            child: ScenarioInspectorPanel(
                                              project: selectedProject,
                                              scenario: selectedScenario,
                                              onOpenYaml: _openYamlPage,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            flex: 3,
                                            child: _DetailRightRail(
                                              project: selectedProject,
                                              scenario: selectedScenario,
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView(
                                        children: [
                                          SizedBox(
                                            height: 680,
                                            child: ScenarioInspectorPanel(
                                              project: selectedProject,
                                              scenario: selectedScenario,
                                              onOpenYaml: _openYamlPage,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          _DetailRightRail(
                                            project: selectedProject,
                                            scenario: selectedScenario,
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 12),
                              DashboardFooterBar(metrics: dashboardState.metrics),
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
    );
  }
}

class _DetailRightRail extends StatelessWidget {
  const _DetailRightRail({required this.project, required this.scenario});

  final ProjectBuild project;
  final BuildScenario scenario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('当前场景', style: theme.textTheme.labelLarge),
              const Spacer(),
              TinyBadge(
                label: scenario.status.label,
                color: scenario.status.color,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ScenarioSummary(scenario: scenario),
          const SizedBox(height: 20),
          Text('环境', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          TinyBadge(
            label: scenario.environment,
            color: MixBuildPalette.primary,
          ),
          const SizedBox(height: 20),
          Text('输出路径', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            scenario.outputPath,
            style: MixBuildTheme.monoTextStyle(
              fontSize: 12,
              color: MixBuildPalette.muted,
            ),
          ),
          const SizedBox(height: 20),
          Text('项目描述', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(project.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          Text('依赖分支', style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          for (final dependency in scenario.dependencies.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    dependency.icon,
                    size: 16,
                    color: dependency.highlight ?? MixBuildPalette.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dependency.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    dependency.branch,
                    style: MixBuildTheme.monoTextStyle(
                      fontSize: 11,
                      color: dependency.highlight ?? MixBuildPalette.primary,
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
