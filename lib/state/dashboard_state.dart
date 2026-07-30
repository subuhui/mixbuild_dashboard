import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';

/// 仪表盘不可变状态，聚合了当前配置、项目列表、全局配置和 UI 选择状态。
///
/// 通过 [copyWith] 产生新实例，由 [DashboardController] 管理。
class DashboardState {
  const DashboardState({
    required this.config,
    required this.projects,
    required this.globalConfig,
    required this.metrics,
    required this.executionHistory,
    required this.availableWorkspaceNames,
    required this.selectedProjectId,
    required this.selectedScenarioId,
    required this.cleanBeforeBuild,
    this.lastError,
  });

  final MixbuildConfig config;
  final List<ProjectBuild> projects;
  final GlobalConfig globalConfig;
  final List<ResourceMetric> metrics;
  final List<BuildExecutionRecord> executionHistory;
  final List<String> availableWorkspaceNames;
  final String selectedProjectId;
  final String selectedScenarioId;
  final Map<String, bool> cleanBeforeBuild;
  final String? lastError;

  ProjectBuild get selectedProject =>
      projects.firstWhere((item) => item.id == selectedProjectId);

  BuildScenario get selectedScenario => selectedProject.scenarios
      .firstWhere((item) => item.id == selectedScenarioId);

  int get runningCount => projects
      .expand((project) => project.scenarios)
      .where((scenario) => scenario.status.isPipelineActive)
      .length;

  DashboardState copyWith({
    MixbuildConfig? config,
    List<ProjectBuild>? projects,
    GlobalConfig? globalConfig,
    List<ResourceMetric>? metrics,
    List<BuildExecutionRecord>? executionHistory,
    List<String>? availableWorkspaceNames,
    String? selectedProjectId,
    String? selectedScenarioId,
    Map<String, bool>? cleanBeforeBuild,
    Object? lastError = _sentinel,
  }) {
    return DashboardState(
      config: config ?? this.config,
      projects: projects ?? this.projects,
      globalConfig: globalConfig ?? this.globalConfig,
      metrics: metrics ?? this.metrics,
      executionHistory: executionHistory ?? this.executionHistory,
      availableWorkspaceNames:
          availableWorkspaceNames ?? this.availableWorkspaceNames,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
      selectedScenarioId: selectedScenarioId ?? this.selectedScenarioId,
      cleanBeforeBuild: cleanBeforeBuild ?? this.cleanBeforeBuild,
      lastError: lastError == _sentinel ? this.lastError : lastError as String?,
    );
  }
}

const Object _sentinel = Object();
