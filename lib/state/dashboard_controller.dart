import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:mixbuild_dashboard/services/mixbuild_engine.dart';
import 'package:mixbuild_dashboard/services/mixbuild_yaml_store.dart';
import 'package:mixbuild_dashboard/state/dashboard_state.dart';

/// 进程执行器 provider，注入 [ProcessRunCommandRunner] 实例。
final mixbuildCommandRunnerProvider = Provider<MixbuildCommandRunner>((ref) {
  return ProcessRunCommandRunner();
});

/// 构建引擎 provider，依赖 [mixbuildCommandRunnerProvider]。
final mixbuildEngineProvider = Provider<MixbuildEngine>((ref) {
  return MixbuildEngine(ref.watch(mixbuildCommandRunnerProvider));
});

/// YAML 持久化服务 provider。
final mixbuildYamlStoreProvider = Provider<MixbuildYamlStore>((ref) {
  return const MixbuildYamlStore();
});

/// 主状态控制器 provider，驱动整个仪表盘的业务逻辑。
final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
        DashboardController.new);

/// 仪表盘核心业务控制器，职责包括：
///
/// - 启动时发现并加载所有工作区 YAML 配置
/// - 监听 YAML 文件变更并防抖重载
/// - 管理项目/场景选择状态
/// - 触发/终止构建流水线（委托给 [MixbuildEngine]）
/// - 持久化配置变更（委托给 [MixbuildYamlStore]）
class DashboardController extends Notifier<DashboardState> {
  bool _stopRequested = false;
  StreamSubscription<FileSystemEvent>? _yamlWatchSubscription;
  Timer? _watchDebounce;

  @override
  DashboardState build() {
    ref.onDispose(() {
      _watchDebounce?.cancel();
      _yamlWatchSubscription?.cancel();
    });
    final store = ref.read(mixbuildYamlStoreProvider);
    final yamlFiles = store.discoverWorkspaceYamlFilesSync();
    final configs = <MixbuildConfig>[];
    for (final file in yamlFiles) {
      try {
        configs.add(MixbuildConfig.fromFileSync(file.path));
      } catch (_) {}
    }
    if (configs.isEmpty) {
      final config = store.loadInitialConfigSync();
      configs.add(config);
    }
    final activeConfig = configs.first;
    _startWatching(activeConfig.filePath);
    return _stateFromConfigs(configs, activeConfig);
  }

  List<String> branchOptions(ProjectBuild project) {
    return <String>{
      project.branch,
      state.config.mainProject.defaultBranch,
      'master',
      'develop',
      'release/v3.1',
      'hotfix/v3.1.1',
    }.toList();
  }

  List<String> dependencyBranchOptions(DependencyBranch dependency) {
    final configDependency =
        state.config.dependencies.where((item) => item.name == dependency.name);
    return <String>{
      dependency.branch,
      if (configDependency.isNotEmpty) configDependency.first.defaultBranch,
      'master',
      'develop',
      'main',
      'release/3.1',
      'feature/v18-support',
    }.toList();
  }

  List<DependencyBranch> editorBaseDependencies() {
    final selectedByName = <String, DependencyBranch>{
      for (final dependency in state.selectedScenario.dependencies)
        dependency.name: dependency,
    };
    final matchingScenarios = state.config.buildScenarios
        .where((s) => s.id == state.selectedScenarioId);
    final scenarioOverrides = matchingScenarios.isNotEmpty
        ? matchingScenarios.first.dependencyOverrides
        : const <String, String>{};
    return state.config.dependencies.map((dependency) {
      final selected = selectedByName[dependency.name];
      final overrideBranch = scenarioOverrides[dependency.name];
      return DependencyBranch(
        name: dependency.name,
        branch: selected?.branch ?? overrideBranch ?? dependency.defaultBranch,
        icon:
            selected?.icon ?? _dependencyIcon(dependency.type, dependency.name),
        highlight: selected?.highlight,
      );
    }).toList(growable: false);
  }

/// 从磁盘重新加载当前工作区 YAML 配置并刷新 UI 状态。
  Future<void> reloadTopology() async {
    try {
      final config = ref
          .read(mixbuildYamlStoreProvider)
          .loadConfigSync(state.config.filePath);
      _applyConfig(config, preserveError: false);
    } catch (error) {
      state = state.copyWith(lastError: '$error');
    }
  }

  Future<void> openYamlInEditor() async {
    await ref
        .read(mixbuildCommandRunnerProvider)
        .openPath(state.config.filePath);
  }

  String readCurrentYaml() {
    return ref
        .read(mixbuildYamlStoreProvider)
        .readYamlSync(state.config.filePath);
  }

/// 保存原始 YAML 文本内容，重新解析并更新工作区配置。
  Future<void> saveCurrentYaml(String content) async {
    final savedConfig = ref.read(mixbuildYamlStoreProvider).saveRawYamlSync(
          content,
          currentFilePath: state.config.filePath,
        );
    _applyConfig(savedConfig,
        preserveError: false, previousFilePath: state.config.filePath);
  }

  void selectScenario(ProjectBuild project, BuildScenario scenario) {
    _ensureActiveConfig(project);
    state = state.copyWith(
      selectedProjectId: project.id,
      selectedScenarioId: scenario.id,
      lastError: null,
    );
  }

  void selectProject(ProjectBuild project) {
    _ensureActiveConfig(project);
    state = state.copyWith(
      selectedProjectId: project.id,
      selectedScenarioId: project.scenarios.first.id,
      lastError: null,
    );
  }

  void _ensureActiveConfig(ProjectBuild project) {
    if (project.id == state.config.filePath) return;
    final config = configForProject(project);
    _startWatching(config.filePath);
    state = state.copyWith(
      config: config,
      globalConfig: GlobalConfig(
        workspaceRoot: config.workspace.rootPath,
        activeProjectName: config.workspace.name,
        mainProjectDefaultBranch: config.mainProject.defaultBranch,
        bindings: [
          WorkspaceBinding(
            projectName: config.mainProject.name,
            path: config.mainProject.path,
            type: config.mainProject.type,
            defaultBranch: config.mainProject.defaultBranch,
            restoreCommand: config.mainProject.restoreCommand,
          ),
          ...config.dependencies.map(
            (d) => WorkspaceBinding(
              projectName: d.name,
              path: d.path,
              type: d.type,
              defaultBranch: d.defaultBranch,
              restoreCommand: d.restoreCommand,
            ),
          ),
        ],
      ),
    );
  }

  MixbuildConfig configForProject(ProjectBuild project) {
    if (project.id == state.config.filePath) return state.config;
    final store = ref.read(mixbuildYamlStoreProvider);
    return store.loadConfigSync(project.id);
  }

  void changeProjectBranch(String branch) {
    if (state.selectedScenario.status.controlsLocked) {
      return;
    }
    final updatedProjects = state.projects.map((project) {
      if (project.id != state.selectedProjectId) {
        return project;
      }
      return project.copyWith(branch: branch);
    }).toList(growable: false);
    state = state.copyWith(projects: updatedProjects, lastError: null);
  }

  void changeScenario(String scenarioId) {
    if (state.selectedScenario.status.controlsLocked) {
      return;
    }
    state = state.copyWith(selectedScenarioId: scenarioId, lastError: null);
  }

  void changeDependencyBranch(String dependencyName, String branch) {
    if (state.selectedScenario.status.controlsLocked) {
      return;
    }
    final currentScenarioId = state.selectedScenarioId;
    final updatedScenarios = state.config.buildScenarios.map((scenarioConfig) {
      if (scenarioConfig.id != currentScenarioId) {
        return scenarioConfig;
      }
      final overrides =
          Map<String, String>.from(scenarioConfig.dependencyOverrides)
            ..[dependencyName] = branch;
      return scenarioConfig.copyWith(dependencyOverrides: overrides);
    }).toList(growable: false);
    final updatedConfig =
        state.config.copyWith(buildScenarios: updatedScenarios);
    final savedConfig =
        ref.read(mixbuildYamlStoreProvider).saveConfigSync(updatedConfig);
    _applyConfig(
      savedConfig,
      preserveError: false,
      preserveSelectedProjectId: state.selectedProjectId,
      preserveSelectedScenarioId: state.selectedScenarioId,
    );
  }

  void setCleanBeforeBuild(bool value) {
    final nextValues = Map<String, bool>.from(state.cleanBeforeBuild)
      ..[state.selectedScenarioId] = value;
    state = state.copyWith(cleanBeforeBuild: nextValues, lastError: null);
  }

  Future<void> updateGlobalConfig(GlobalConfig config) async {
    final updatedDependencies = state.config.dependencies.map((dependency) {
      final binding =
          config.bindings.where((item) => item.projectName == dependency.name);
      if (binding.isEmpty) {
        return dependency;
      }
      return dependency.copyWith(path: binding.first.path);
    }).toList(growable: false);

    final updatedConfig = state.config.copyWith(
      workspace: state.config.workspace.copyWith(
        name: config.activeProjectName,
        rootPath: config.workspaceRoot,
      ),
      dependencies: updatedDependencies,
    );
    final savedConfig =
        ref.read(mixbuildYamlStoreProvider).saveConfigSync(updatedConfig);
    _applyConfig(savedConfig,
        overrideGlobalConfig: config,
        preserveError: false,
        previousFilePath: state.config.filePath);
  }

  Future<void> updateProjectConfiguration({
    required GlobalConfig config,
    required List<ProjectBindingConfig> bindings,
    required List<BuildScenario> scenarios,
    String? targetConfigPath,
  }) async {
    final baseConfig = targetConfigPath != null
        ? ref.read(mixbuildYamlStoreProvider).loadConfigSync(targetConfigPath)
        : state.config;

    final mainBinding = bindings.firstWhere(
      (binding) => binding.isMainProject,
      orElse: () => ProjectBindingConfig(
        projectName: baseConfig.mainProject.name,
        path: baseConfig.mainProject.path,
        type: baseConfig.mainProject.type,
        defaultBranch: baseConfig.mainProject.defaultBranch,
        restoreCommand: baseConfig.mainProject.restoreCommand,
        isMainProject: true,
      ),
    );

    final updatedDependencies =
        bindings.where((binding) => !binding.isMainProject).map((binding) {
      return MixbuildRepoConfig(
        name: binding.projectName,
        path: binding.path,
        type: binding.type,
        defaultBranch: binding.defaultBranch,
        restoreCommand: binding.restoreCommand,
      );
    }).toList(growable: false);

    final updatedScenarios = scenarios.map((scenario) {
      final baseScenarioMatches =
          baseConfig.buildScenarios.where((s) => s.id == scenario.id);
      final baseScenario =
          baseScenarioMatches.isNotEmpty ? baseScenarioMatches.first : null;
      final overrides = <String, String>{
        if (baseScenario != null) ...baseScenario.dependencyOverrides,
        for (final dep in scenario.dependencies) dep.name: dep.branch,
      };
      return MixbuildScenarioConfig(
        id: scenario.id,
        name: scenario.name,
        mainBranch: scenario.mainBranch.trim().isEmpty
            ? mainBinding.defaultBranch
            : scenario.mainBranch.trim(),
        command: scenario.command,
        outputDir: scenario.outputPath.trim().isEmpty
            ? null
            : scenario.outputPath.trim(),
        autoTag: scenario.autoTag,
        tagPrefix: scenario.tagPrefix,
        dependencyOverrides: overrides,
      );
    }).toList(growable: false);

    final updatedConfig = baseConfig.copyWith(
      workspace: baseConfig.workspace.copyWith(
        name: config.activeProjectName,
        rootPath: config.workspaceRoot,
      ),
      mainProject: baseConfig.mainProject.copyWith(
        name: mainBinding.projectName,
        path: mainBinding.path,
        type: mainBinding.type,
        defaultBranch: mainBinding.defaultBranch,
        restoreCommand: mainBinding.restoreCommand,
      ),
      dependencies: updatedDependencies,
      buildScenarios: updatedScenarios,
    );

    final savedConfig =
        ref.read(mixbuildYamlStoreProvider).saveConfigSync(updatedConfig);
    _applyConfig(savedConfig,
        overrideGlobalConfig: config,
        preserveError: false,
        previousFilePath: baseConfig.filePath);
  }

/// 创建新工作区项目，将配置写入 YAML 文件并切换到新项目。
  Future<void> createProject({
    required GlobalConfig config,
    required List<ProjectBindingConfig> bindings,
    required List<BuildScenario> scenarios,
  }) async {
    final store = ref.read(mixbuildYamlStoreProvider);

    final mainBinding = bindings.firstWhere(
      (binding) => binding.isMainProject,
      orElse: () => ProjectBindingConfig(
        projectName: 'new_project',
        path: '.',
        type: MixbuildProjectType.flutter,
        defaultBranch: 'main',
        restoreCommand: null,
        isMainProject: true,
      ),
    );

    final newDependencies =
        bindings.where((binding) => !binding.isMainProject).map((binding) {
      return MixbuildRepoConfig(
        name: binding.projectName,
        path: binding.path,
        type: binding.type,
        defaultBranch: binding.defaultBranch,
        restoreCommand: binding.restoreCommand,
      );
    }).toList(growable: false);

    final newScenarios = scenarios.map((scenario) {
      return MixbuildScenarioConfig(
        id: scenario.id,
        name: scenario.name,
        mainBranch: scenario.mainBranch.trim().isEmpty
            ? mainBinding.defaultBranch
            : scenario.mainBranch.trim(),
        command: scenario.command,
        outputDir: scenario.outputPath.trim().isEmpty
            ? null
            : scenario.outputPath.trim(),
        autoTag: scenario.autoTag,
        tagPrefix: scenario.tagPrefix,
        dependencyOverrides: {
          for (final dep in scenario.dependencies) dep.name: dep.branch,
        },
      );
    }).toList(growable: false);

    var workspaceName = config.activeProjectName.trim();
    if (workspaceName.isEmpty) {
      workspaceName = 'workspace';
    }

    final newConfig = MixbuildConfig(
      filePath: '',
      workspace: MixbuildWorkspaceConfig(
        name: workspaceName,
        rootPath: config.workspaceRoot,
      ),
      mainProject: MixbuildRepoConfig(
        name: mainBinding.projectName,
        path: mainBinding.path,
        type: mainBinding.type,
        defaultBranch: mainBinding.defaultBranch,
        restoreCommand: mainBinding.restoreCommand,
      ),
      dependencies: newDependencies,
      buildScenarios: newScenarios,
    );

    final savedConfig = store.saveNewConfigSync(newConfig);
    _applyConfig(savedConfig,
        overrideGlobalConfig: config, preserveError: false);
  }

/// 切换到指定名称的工作区，重新加载对应的 YAML 配置文件。
  Future<void> switchWorkspace(String workspaceName) async {
    final store = ref.read(mixbuildYamlStoreProvider);
    File matchedFile = File(state.config.filePath);
    for (final file
        in store.discoverWorkspaceYamlFilesSync().whereType<File>()) {
      if (MixbuildConfig.fromFileSync(file.path).workspace.name ==
          workspaceName) {
        matchedFile = file;
        break;
      }
    }
    final config = store.loadConfigSync(matchedFile.path);
    _applyConfig(config, preserveError: false);
  }

  void updateScenarioYamlOverride(String scenarioId, String yamlOverride) {
    state = state.copyWith(
      projects: state.projects.map((project) {
        if (project.id != state.selectedProjectId) {
          return project;
        }
        return project.copyWith(
          scenarios: project.scenarios.map((scenario) {
            if (scenario.id != scenarioId) {
              return scenario;
            }
            return scenario.copyWith(yamlOverride: yamlOverride);
          }).toList(growable: false),
        );
      }).toList(growable: false),
      lastError: null,
    );
  }

  void addScenario(BuildScenario scenario) {
    final updatedProjects = state.projects.map((project) {
      if (project.id != state.selectedProjectId) {
        return project;
      }
      return project.copyWith(scenarios: [...project.scenarios, scenario]);
    }).toList(growable: false);
    final nextCleanValues = Map<String, bool>.from(state.cleanBeforeBuild)
      ..[scenario.id] = false;
    state = state.copyWith(
      projects: updatedProjects,
      selectedScenarioId: scenario.id,
      cleanBeforeBuild: nextCleanValues,
      lastError: null,
    );
  }

/// 触发当前选中场景的构建流水线。
  ///
  /// 若场景已在运行则转为停止操作；构建过程中实时更新状态和日志。
  Future<void> triggerSelectedScenario() async {
    final project = state.selectedProject;
    final scenario = state.selectedScenario;
    if (scenario.status.canStop) {
      stopSelectedScenario();
      return;
    }
    if (!scenario.status.canTrigger) {
      return;
    }

    _stopRequested = false;
    _updateScenario(
      projectId: project.id,
      scenarioId: scenario.id,
      transform: (current) => current.copyWith(
        status: BuildStatus.validating,
        progress: 0.05,
        logs: [
          _log(
            level: 'INFO',
            message: 'Queued pipeline for ${project.name} / ${scenario.name}',
            accent: MixBuildPalette.warning,
          ),
          if (state.cleanBeforeBuild[scenario.id] ?? false)
            _log(
              level: 'INFO',
              message: 'Clean flag enabled. Build command will append --clean.',
              accent: MixBuildPalette.tertiary,
            ),
          ...current.logs,
        ].toList(growable: false),
      ),
    );

    try {
      await ref.read(mixbuildEngineProvider).runPipeline(
            config: state.config,
            project: state.selectedProject,
            scenario: state.selectedScenario,
            cleanBeforeBuild: state.cleanBeforeBuild[scenario.id] ?? false,
            dependencyOverrides: {
              for (final dependency in state.selectedScenario.dependencies)
                if (dependency.isOverride) dependency.name: dependency.branch,
            },
            onProgress: (status, progress) {
              _updateScenario(
                projectId: project.id,
                scenarioId: scenario.id,
                transform: (current) =>
                    current.copyWith(status: status, progress: progress),
              );
            },
            onLog: (entry) {
              _updateScenario(
                projectId: project.id,
                scenarioId: scenario.id,
                transform: (current) => current.copyWith(
                  logs: [entry, ...current.logs].toList(growable: false),
                ),
              );
            },
          );
    } catch (error) {
      if (_stopRequested) {
        return;
      }
      _updateScenario(
        projectId: project.id,
        scenarioId: scenario.id,
        transform: (current) => current.copyWith(
          status: BuildStatus.failed,
          progress: 0,
          mainBranch: project.branch,
          logs: [
            _log(
              level: 'ERROR',
              message: '$error',
              accent: MixBuildPalette.error,
            ),
            ...current.logs,
          ].toList(growable: false),
        ),
      );
      state = state.copyWith(lastError: '$error');
    }
  }

/// 终止当前正在运行的构建流水线，发送 SIGKILL 到所有子进程。
  void stopSelectedScenario() {
    _stopRequested = true;
    ref.read(mixbuildEngineProvider).killActive();
    final project = state.selectedProject;
    final scenario = state.selectedScenario;
    _updateScenario(
      projectId: project.id,
      scenarioId: scenario.id,
      transform: (current) => current.copyWith(
        status: BuildStatus.interrupted,
        progress: 0,
        logs: [
          _log(
            level: 'WARN',
            message:
                'Safe Kill dispatched. All child processes and Gradle daemons were terminated.',
            accent: MixBuildPalette.error,
          ),
          ...current.logs,
        ].toList(growable: false),
      ),
    );
  }

  DashboardState _stateFromConfigs(
    List<MixbuildConfig> configs,
    MixbuildConfig activeConfig,
  ) {
    final projects = configs.map(_projectFromConfig).toList(growable: false);
    final allScenarios =
        projects.expand((p) => p.scenarios).toList(growable: false);
    final activeProject = projects.firstWhere(
      (p) => p.id == activeConfig.filePath,
      orElse: () => projects.first,
    );
    final cleanFlags = <String, bool>{
      for (final scenario in allScenarios) scenario.id: false,
    };
    return DashboardState(
      config: activeConfig,
      projects: projects,
      globalConfig: GlobalConfig(
        workspaceRoot: activeConfig.workspace.rootPath,
        activeProjectName: activeConfig.workspace.name,
        mainProjectDefaultBranch: activeConfig.mainProject.defaultBranch,
        bindings: [
          WorkspaceBinding(
            projectName: activeConfig.mainProject.name,
            path: activeConfig.mainProject.path,
            type: activeConfig.mainProject.type,
            defaultBranch: activeConfig.mainProject.defaultBranch,
            restoreCommand: activeConfig.mainProject.restoreCommand,
          ),
          ...activeConfig.dependencies.map(
            (d) => WorkspaceBinding(
              projectName: d.name,
              path: d.path,
              type: d.type,
              defaultBranch: d.defaultBranch,
              restoreCommand: d.restoreCommand,
            ),
          ),
        ],
      ),
      metrics: _buildMetrics(allScenarios),
      availableWorkspaceNames: _workspaceNames(),
      selectedProjectId: activeProject.id,
      selectedScenarioId: activeProject.scenarios.first.id,
      cleanBeforeBuild: cleanFlags,
    );
  }

  ProjectBuild _projectFromConfig(MixbuildConfig config) {
    final scenarioConfigs = config.buildScenarios;
    final scenarios = scenarioConfigs.isEmpty
        ? [
            BuildScenario(
              id: '${config.filePath}#default',
              name: 'Default Build',
              subtitle: 'YAML 中未定义构建场景',
              environment: config.workspace.name,
              mainBranch: config.mainProject.defaultBranch,
              command: '',
              status: BuildStatus.idle,
              progress: 0,
              outputPath: '',
              autoTag: false,
              tagPrefix: '',
              yamlOverride: '',
              dependencies: const [],
              logs: [
                _log(
                  level: 'WARN',
                  message: '该 YAML 未定义 build_scenarios，请在编辑器中添加。',
                  accent: MixBuildPalette.warning,
                ),
              ],
            ),
          ]
        : scenarioConfigs.map((scenarioConfig) {
            return BuildScenario(
              id: scenarioConfig.id,
              name: scenarioConfig.name,
              subtitle: '由 YAML 场景驱动',
              environment: config.workspace.name,
              mainBranch: scenarioConfig.mainBranch,
              command: scenarioConfig.command,
              status: BuildStatus.idle,
              progress: 0,
              outputPath: scenarioConfig.outputDir ?? '',
              autoTag: scenarioConfig.autoTag,
              tagPrefix: scenarioConfig.tagPrefix,
              yamlOverride: _scenarioOverrideTemplate(config, scenarioConfig),
              dependencies: config.dependencies.map((dependency) {
                final overrideBranch =
                    scenarioConfig.dependencyOverrides[dependency.name];
                final isOverride = overrideBranch != null;
                return DependencyBranch(
                  name: dependency.name,
                  branch: overrideBranch ?? dependency.defaultBranch,
                  icon: _dependencyIcon(dependency.type, dependency.name),
                  isOverride: isOverride,
                  highlight: isOverride ? MixBuildPalette.primary : null,
                );
              }).toList(growable: false),
              logs: [
                _log(
                  level: 'INIT',
                  message:
                      'Ready to receive build command for project: ${config.workspace.name}',
                  accent: MixBuildPalette.primary,
                ),
                _log(
                  level: 'INFO',
                  message: 'Topology loaded from ${config.filePath}',
                  accent: MixBuildPalette.success,
                ),
              ],
            );
          }).toList(growable: false);

    return ProjectBuild(
      id: config.filePath,
      emoji: '📦',
      name: config.workspace.name,
      description:
          '${config.mainProject.type.name} / ${config.mainProject.defaultBranch}',
      branch: config.mainProject.defaultBranch,
      scenarios: scenarios,
    );
  }

  List<ResourceMetric> _buildMetrics(List<BuildScenario> scenarios) {
    final running =
        scenarios.where((item) => item.status.isPipelineActive).length;
    final failed =
        scenarios.where((item) => item.status == BuildStatus.failed).length;
    final coverage = scenarios.isEmpty ? 0.0 : running / scenarios.length;
    return [
      ResourceMetric(
        label: 'CPU',
        value: '${12 + running * 8}%',
        progress: min(1, 0.12 + running * 0.1),
        color: MixBuildPalette.tertiary,
      ),
      ResourceMetric(
        label: 'MEM',
        value: '${(3.6 + running * 0.7).toStringAsFixed(1)}GB',
        progress: min(1, 0.28 + running * 0.12),
        color: MixBuildPalette.warning,
      ),
      ResourceMetric(
        label: 'Queue',
        value: '${running + failed} Jobs',
        progress: coverage,
        color: MixBuildPalette.primary,
      ),
    ];
  }

  void _updateScenario({
    required String projectId,
    required String scenarioId,
    required BuildScenario Function(BuildScenario scenario) transform,
  }) {
    final updatedProjects = state.projects.map((project) {
      if (project.id != projectId) {
        return project;
      }
      return project.copyWith(
        scenarios: project.scenarios.map((scenario) {
          if (scenario.id != scenarioId) {
            return scenario;
          }
          return transform(scenario);
        }).toList(growable: false),
      );
    }).toList(growable: false);
    state = state.copyWith(
      projects: updatedProjects,
      metrics: _buildMetrics(
        updatedProjects
            .expand((project) => project.scenarios)
            .toList(growable: false),
      ),
    );
  }

  LogEntry _log({
    required String level,
    required String message,
    required Color accent,
  }) {
    final now = DateTime.now();
    return LogEntry(
      time:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      level: level,
      message: message,
      accent: accent,
    );
  }

  String _scenarioOverrideTemplate(
    MixbuildConfig config,
    MixbuildScenarioConfig scenarioConfig,
  ) {
    final dependencyLines = config.dependencies.map((dependency) {
      final overrideBranch =
          scenarioConfig.dependencyOverrides[dependency.name];
      final branch = overrideBranch ?? dependency.defaultBranch;
      return '  ${dependency.name}:\n    branch: $branch';
    }).join('\n');
    return 'workspace:\n  root_path: ${config.workspace.rootPath}\nscenario:\n  name: ${scenarioConfig.name}\n  main_branch: ${scenarioConfig.mainBranch}\ndependencies:\n$dependencyLines\n';
  }

  IconData _dependencyIcon(MixbuildProjectType type, String dependencyName) {
    if (dependencyName.contains('analytics')) {
      return Icons.analytics_outlined;
    }
    if (dependencyName.contains('bridge')) {
      return Icons.hub_outlined;
    }
    return switch (type) {
      MixbuildProjectType.flutter => Icons.layers_outlined,
      MixbuildProjectType.android => Icons.android_outlined,
    };
  }

  void _applyConfig(
    MixbuildConfig config, {
    GlobalConfig? overrideGlobalConfig,
    required bool preserveError,
    String? previousFilePath,
    String? preserveSelectedProjectId,
    String? preserveSelectedScenarioId,
  }) {
    final updatedProject = _projectFromConfig(config);
    final existingProjects = state.projects;
    final removePath = previousFilePath ?? config.filePath;
    final merged = existingProjects
        .where((p) => p.id != removePath)
        .toList(growable: true);
    final insertIndex = merged.indexWhere((p) => p.id == config.filePath);
    if (insertIndex >= 0) {
      merged[insertIndex] = updatedProject;
    } else {
      merged.add(updatedProject);
    }

    final allScenarios =
        merged.expand((p) => p.scenarios).toList(growable: false);
    final cleanFlags = <String, bool>{
      for (final scenario in allScenarios) scenario.id: false,
    };

    final selectedProjectId = preserveSelectedProjectId ?? config.filePath;
    final selectedScenarioId =
        preserveSelectedScenarioId ?? updatedProject.scenarios.first.id;

    state = DashboardState(
      config: config,
      projects: merged,
      globalConfig: overrideGlobalConfig ??
          GlobalConfig(
            workspaceRoot: config.workspace.rootPath,
            activeProjectName: config.workspace.name,
            mainProjectDefaultBranch: config.mainProject.defaultBranch,
            bindings: [
              WorkspaceBinding(
                projectName: config.mainProject.name,
                path: config.mainProject.path,
                type: config.mainProject.type,
                defaultBranch: config.mainProject.defaultBranch,
                restoreCommand: config.mainProject.restoreCommand,
              ),
              ...config.dependencies.map(
                (d) => WorkspaceBinding(
                  projectName: d.name,
                  path: d.path,
                  type: d.type,
                  defaultBranch: d.defaultBranch,
                  restoreCommand: d.restoreCommand,
                ),
              ),
            ],
          ),
      metrics: _buildMetrics(allScenarios),
      availableWorkspaceNames: _workspaceNames(),
      selectedProjectId: selectedProjectId,
      selectedScenarioId: selectedScenarioId,
      cleanBeforeBuild: cleanFlags,
      lastError: preserveError ? state.lastError : null,
    );
    _startWatching(config.filePath);
  }

  List<String> _workspaceNames() {
    final store = ref.read(mixbuildYamlStoreProvider);
    return store.discoverWorkspaceYamlFilesSync().whereType<File>().map((file) {
      try {
        return MixbuildConfig.fromFileSync(file.path).workspace.name;
      } catch (_) {
        return file.uri.pathSegments.last;
      }
    }).toList(growable: false);
  }

  void _startWatching(String filePath) {
    _yamlWatchSubscription?.cancel();
    _yamlWatchSubscription =
        ref.read(mixbuildYamlStoreProvider).watch(filePath).listen((_) {
      _watchDebounce?.cancel();
      _watchDebounce = Timer(const Duration(milliseconds: 180), () {
        reloadTopology();
      });
    });
  }
}
