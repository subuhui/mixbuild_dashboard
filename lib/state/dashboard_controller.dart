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

final mixbuildCommandRunnerProvider = Provider<MixbuildCommandRunner>((ref) {
  return ProcessRunCommandRunner();
});

final mixbuildEngineProvider = Provider<MixbuildEngine>((ref) {
  return MixbuildEngine(ref.watch(mixbuildCommandRunnerProvider));
});

final mixbuildYamlStoreProvider = Provider<MixbuildYamlStore>((ref) {
  return const MixbuildYamlStore();
});

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(DashboardController.new);

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
    final config = store.loadInitialConfigSync();
    _startWatching(config.filePath);
    return _stateFromConfig(config);
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
    final configDependency = state.config.dependencies.where((item) => item.name == dependency.name);
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
      for (final dependency in state.selectedScenario.dependencies) dependency.name: dependency,
    };
    return state.config.dependencies.map((dependency) {
      final selected = selectedByName[dependency.name];
      return DependencyBranch(
        name: dependency.name,
        branch: dependency.defaultBranch,
        icon: selected?.icon ?? _dependencyIcon(dependency.type, dependency.name),
        highlight: selected?.highlight,
      );
    }).toList(growable: false);
  }

  Future<void> reloadTopology() async {
    try {
      final config = ref.read(mixbuildYamlStoreProvider).loadConfigSync(state.config.filePath);
      _applyConfig(config, preserveError: false);
    } catch (error) {
      state = state.copyWith(lastError: '$error');
    }
  }

  Future<void> openYamlInEditor() async {
    await ref.read(mixbuildCommandRunnerProvider).openPath(state.config.filePath);
  }

  String readCurrentYaml() {
    return ref.read(mixbuildYamlStoreProvider).readYamlSync(state.config.filePath);
  }

  Future<void> saveCurrentYaml(String content) async {
    final savedConfig = ref.read(mixbuildYamlStoreProvider).saveRawYamlSync(
          content,
          currentFilePath: state.config.filePath,
        );
    _applyConfig(savedConfig, preserveError: false);
  }

  void selectScenario(ProjectBuild project, BuildScenario scenario) {
    state = state.copyWith(
      selectedProjectId: project.id,
      selectedScenarioId: scenario.id,
      lastError: null,
    );
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
    state = state.copyWith(
      projects: state.projects.map((project) {
        if (project.id != state.selectedProjectId) {
          return project;
        }
        return project.copyWith(
          scenarios: project.scenarios.map((scenario) {
            return scenario.copyWith(
              dependencies: scenario.dependencies.map((dependency) {
                if (dependency.name != dependencyName) {
                  return dependency;
                }
                return dependency.copyWith(
                  branch: branch,
                  isOverride: true,
                  highlight: dependency.highlight ?? MixBuildPalette.primary,
                );
              }).toList(growable: false),
            );
          }).toList(growable: false),
        );
      }).toList(growable: false),
      lastError: null,
    );
  }

  void setCleanBeforeBuild(bool value) {
    final nextValues = Map<String, bool>.from(state.cleanBeforeBuild)
      ..[state.selectedScenarioId] = value;
    state = state.copyWith(cleanBeforeBuild: nextValues, lastError: null);
  }

  Future<void> updateGlobalConfig(GlobalConfig config) async {
    final updatedDependencies = state.config.dependencies.map((dependency) {
      final binding = config.bindings.where((item) => item.projectName == dependency.name);
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
    final savedConfig = ref.read(mixbuildYamlStoreProvider).saveConfigSync(updatedConfig);
    _applyConfig(savedConfig, overrideGlobalConfig: config, preserveError: false);
  }

  Future<void> updateProjectConfiguration({
    required GlobalConfig config,
    required List<ProjectBindingConfig> bindings,
    required List<BuildScenario> scenarios,
  }) async {
    final mainBinding = bindings.firstWhere(
      (binding) => binding.isMainProject,
      orElse: () => ProjectBindingConfig(
        projectName: state.config.mainProject.name,
        path: state.config.mainProject.path,
        type: state.config.mainProject.type,
        defaultBranch: state.config.mainProject.defaultBranch,
        restoreCommand: state.config.mainProject.restoreCommand,
        isMainProject: true,
      ),
    );

    final updatedDependencies = bindings
        .where((binding) => !binding.isMainProject)
        .map((binding) {
          return MixbuildRepoConfig(
            name: binding.projectName,
            path: binding.path,
            type: binding.type,
            defaultBranch: binding.defaultBranch,
            restoreCommand: binding.restoreCommand,
          );
        })
        .toList(growable: false);

    final updatedScenarios = scenarios.map((scenario) {
      return MixbuildScenarioConfig(
        id: scenario.id,
        name: scenario.name,
        mainBranch: scenario.mainBranch.trim().isEmpty
            ? mainBinding.defaultBranch
            : scenario.mainBranch.trim(),
        command: scenario.command,
        outputDir: scenario.outputPath.trim().isEmpty ? null : scenario.outputPath.trim(),
        autoTag: scenario.autoTag,
        tagPrefix: scenario.tagPrefix,
      );
    }).toList(growable: false);

    final updatedConfig = state.config.copyWith(
      workspace: state.config.workspace.copyWith(
        name: config.activeProjectName,
        rootPath: config.workspaceRoot,
      ),
      mainProject: state.config.mainProject.copyWith(
        name: mainBinding.projectName,
        path: mainBinding.path,
        type: mainBinding.type,
        defaultBranch: mainBinding.defaultBranch,
        restoreCommand: mainBinding.restoreCommand,
      ),
      dependencies: updatedDependencies,
      buildScenarios: updatedScenarios,
    );

    final savedConfig = ref.read(mixbuildYamlStoreProvider).saveConfigSync(updatedConfig);
    _applyConfig(savedConfig, overrideGlobalConfig: config, preserveError: false);
  }

  Future<void> switchWorkspace(String workspaceName) async {
    final store = ref.read(mixbuildYamlStoreProvider);
    File matchedFile = File(state.config.filePath);
    for (final file in store.discoverWorkspaceYamlFilesSync().whereType<File>()) {
      if (MixbuildConfig.fromFileSync(file.path).workspace.name == workspaceName) {
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
        ].take(8).toList(growable: false),
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
            transform: (current) => current.copyWith(status: status, progress: progress),
          );
        },
        onLog: (entry) {
          _updateScenario(
            projectId: project.id,
            scenarioId: scenario.id,
            transform: (current) => current.copyWith(
              logs: [entry, ...current.logs].take(12).toList(growable: false),
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
          logs: [
            _log(
              level: 'ERROR',
              message: '$error',
              accent: MixBuildPalette.error,
            ),
            ...current.logs,
          ].take(12).toList(growable: false),
        ),
      );
      state = state.copyWith(lastError: '$error');
    }
  }

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
            message: 'Safe Kill dispatched. All child processes and Gradle daemons were terminated.',
            accent: MixBuildPalette.error,
          ),
          ...current.logs,
        ].take(12).toList(growable: false),
      ),
    );
  }

  DashboardState _stateFromConfig(MixbuildConfig config) {
    final project = _projectFromConfig(config);
    final cleanFlags = <String, bool>{
      for (final scenario in project.scenarios) scenario.id: false,
    };
    return DashboardState(
      config: config,
      projects: [project],
      globalConfig: GlobalConfig(
        workspaceRoot: config.workspace.rootPath,
        activeProjectName: config.workspace.name,
        bindings: [
          WorkspaceBinding(projectName: config.mainProject.name, path: config.mainProject.path),
          ...config.dependencies.map(
            (dependency) => WorkspaceBinding(
              projectName: dependency.name,
              path: dependency.path,
            ),
          ),
        ],
      ),
      metrics: _buildMetrics(project.scenarios),
      availableWorkspaceNames: _workspaceNames(),
      selectedProjectId: project.id,
      selectedScenarioId: project.scenarios.first.id,
      cleanBeforeBuild: cleanFlags,
    );
  }

  ProjectBuild _projectFromConfig(MixbuildConfig config) {
    return ProjectBuild(
      id: 'workspace-main',
      emoji: '🚚',
      name: '项目 A：${config.workspace.name}',
      description: 'YAML Engine / ${config.mainProject.type.name}',
      branch: config.mainProject.defaultBranch,
      scenarios: config.buildScenarios.map((scenarioConfig) {
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
            return DependencyBranch(
              name: dependency.name,
              branch: dependency.defaultBranch,
              icon: _dependencyIcon(dependency.type, dependency.name),
            );
          }).toList(growable: false),
          logs: [
            _log(
              level: 'INIT',
              message: 'Ready to receive build command for project: ${config.workspace.name}',
              accent: MixBuildPalette.primary,
            ),
            _log(
              level: 'INFO',
              message: 'Topology loaded from ${config.filePath}',
              accent: MixBuildPalette.success,
            ),
          ],
        );
      }).toList(growable: false),
    );
  }

  List<ResourceMetric> _buildMetrics(List<BuildScenario> scenarios) {
    final running = scenarios.where((item) => item.status.isPipelineActive).length;
    final failed = scenarios.where((item) => item.status == BuildStatus.failed).length;
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
        updatedProjects.expand((project) => project.scenarios).toList(growable: false),
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
      time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      level: level,
      message: message,
      accent: accent,
    );
  }

  String _scenarioOverrideTemplate(
    MixbuildConfig config,
    MixbuildScenarioConfig scenarioConfig,
  ) {
    final dependencyLines = config.dependencies
        .map((dependency) => '  ${dependency.name}:\n    branch: ${dependency.defaultBranch}')
        .join('\n');
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
  }) {
    final nextState = _stateFromConfig(config);
    state = nextState.copyWith(
      globalConfig: overrideGlobalConfig ?? nextState.globalConfig,
      lastError: preserveError ? state.lastError : null,
    );
    _startWatching(config.filePath);
  }

  List<String> _workspaceNames() {
    final store = ref.read(mixbuildYamlStoreProvider);
    return store
        .discoverWorkspaceYamlFilesSync()
        .whereType<File>()
        .map((file) {
          try {
            return MixbuildConfig.fromFileSync(file.path).workspace.name;
          } catch (_) {
            return file.uri.pathSegments.last;
          }
        })
        .toList(growable: false);
  }

  void _startWatching(String filePath) {
    _yamlWatchSubscription?.cancel();
    _yamlWatchSubscription = ref.read(mixbuildYamlStoreProvider).watch(filePath).listen((_) {
      _watchDebounce?.cancel();
      _watchDebounce = Timer(const Duration(milliseconds: 180), () {
        reloadTopology();
      });
    });
  }
}
