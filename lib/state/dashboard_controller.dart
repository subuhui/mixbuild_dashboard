import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/build_execution_history_store.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:mixbuild_dashboard/services/mixbuild_engine.dart';
import 'package:mixbuild_dashboard/services/system_resource_monitor.dart';
import 'package:mixbuild_dashboard/services/mixbuild_yaml_store.dart';
import 'package:mixbuild_dashboard/state/dashboard_state.dart';

final mixbuildCommandRunnerProvider = Provider<MixbuildCommandRunner>((ref) {
  return ProcessRunCommandRunner();
});

/// Build engine provider.
final mixbuildEngineProvider = Provider<MixbuildEngine>((ref) {
  return MixbuildEngine(ref.watch(mixbuildCommandRunnerProvider));
});

final systemResourceMonitorProvider = Provider<SystemResourceMonitor>((ref) {
  return ProcessSystemResourceMonitor(ref.watch(mixbuildCommandRunnerProvider));
});

/// YAML persistence provider.
final mixbuildYamlStoreProvider = Provider<MixbuildYamlStore>((ref) {
  return const MixbuildYamlStore();
});

final buildExecutionHistoryStoreProvider =
    Provider<BuildExecutionHistoryStore>((ref) {
  return const BuildExecutionHistoryStore();
});

/// Main state controller provider for dashboard business logic.
final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
        DashboardController.new);

/// Core dashboard business controller responsibilities:
///
/// - Discover and load workspace YAML configs on startup
/// - Watch YAML changes and debounce reloads
/// - Manage project and scenario selection state
/// - Trigger and stop build pipelines through [MixbuildEngine]
/// - Persist config changes through [MixbuildYamlStore]
class DashboardController extends Notifier<DashboardState> {
  static const Duration _historyPersistDebounceDelay =
      Duration(milliseconds: 320);
  static const Duration _logFlushInterval = Duration(milliseconds: 120);
  static const int _maxScenarioLogEntries = 320;

  bool _stopRequested = false;
  bool _isDisposed = false;
  StreamSubscription<FileSystemEvent>? _yamlWatchSubscription;
  Timer? _watchDebounce;
  Timer? _resourceRefreshTimer;
  Timer? _historyPersistDebounce;
  SystemResourceSnapshot? _latestResourceSnapshot;
  bool _historyPersistDirty = false;
  bool _historyPersistInFlight = false;
  Future<void>? _historyPersistTask;
  final Map<String, _ActiveExecutionContext> _activeExecutions =
      <String, _ActiveExecutionContext>{};

  @override
  DashboardState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _watchDebounce?.cancel();
      _yamlWatchSubscription?.cancel();
      _resourceRefreshTimer?.cancel();
      _historyPersistDebounce?.cancel();
      for (final context in _activeExecutions.values) {
        context.flushTimer?.cancel();
      }
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
    final stateSnapshot = _stateFromConfigs(
      configs,
      activeConfig,
      executionHistory:
          ref.read(buildExecutionHistoryStoreProvider).loadHistorySync(),
    );
    _startResourceMonitoring();
    return stateSnapshot;
  }

  List<String> branchOptions(ProjectBuild project) {
    return <String>{
      project.branch,
      state.config.mainProject.defaultBranch,
      'master',
      'develop',
      'release/v1.0',
      'hotfix/v1.0.1',
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
      'release/1.0',
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

  /// Reloads the current workspace YAML config from disk and refreshes UI state.
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

  /// Saves raw YAML text, reparses it, and updates workspace config.
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

  /// Creates a new workspace project, writes its YAML config, and switches to it.
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

  /// Switches to a workspace by name and reloads its YAML config.
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

  /// Triggers the build pipeline for the selected scenario.
  ///
  /// If the scenario is already running, this stops it; otherwise it streams status and logs.
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
    if (state.runningCount > 0) {
      state = state.copyWith(
        lastError:
            'A build is already running. Stop it before starting another task.',
      );
      return;
    }

    _stopRequested = false;
    _startExecution(project, scenario);
    final queuedLogs = <LogEntry>[
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
    ];
    _recordImmediateExecutionLogs(
      projectId: project.id,
      scenarioId: scenario.id,
      logs: queuedLogs,
    );
    _updateScenario(
      projectId: project.id,
      scenarioId: scenario.id,
      transform: (current) => current.copyWith(
        status: BuildStatus.validating,
        progress: 0.05,
        logs: [
          ...queuedLogs,
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
              _enqueueExecutionLog(
                projectId: project.id,
                scenarioId: scenario.id,
                entry: entry,
              );
            },
          );
      _flushExecutionLogs(project.id, scenario.id);
    } catch (error) {
      if (_stopRequested) {
        return;
      }
      _flushExecutionLogs(project.id, scenario.id);
      final errorLog = _log(
        level: 'ERROR',
        message: '$error',
        accent: MixBuildPalette.error,
      );
      _recordImmediateExecutionLogs(
        projectId: project.id,
        scenarioId: scenario.id,
        logs: <LogEntry>[errorLog],
      );
      _updateScenario(
        projectId: project.id,
        scenarioId: scenario.id,
        transform: (current) => current.copyWith(
          status: BuildStatus.failed,
          progress: 0,
          mainBranch: project.branch,
          logs: [
            errorLog,
            ...current.logs,
          ].toList(growable: false),
        ),
      );
      await _finalizeExecution(
        projectId: project.id,
        scenarioId: scenario.id,
        status: BuildStatus.failed,
      );
      state = state.copyWith(lastError: '$error');
      return;
    }
    await _finalizeExecution(
      projectId: project.id,
      scenarioId: scenario.id,
      status: BuildStatus.success,
    );
  }

  /// Stops the active build pipeline and sends SIGKILL to child processes.
  void stopSelectedScenario() {
    _stopRequested = true;
    final project = state.selectedProject;
    String? workingDirectory;
    try {
      final config = ref.read(mixbuildYamlStoreProvider).loadConfigSync(project.id);
      workingDirectory = config.mainProject.absolutePath(config.workspace.rootPath);
    } catch (_) {
      // Ignore config loading errors in stop flow
    }

    ref.read(mixbuildEngineProvider).killActive(
          projectType: project.type,
          workingDirectory: workingDirectory,
        );

    final scenario = state.selectedScenario;
    _flushExecutionLogs(project.id, scenario.id);

    final interruptionLog = _log(
      level: 'WARN',
      message:
          'Stop signal dispatched to the active build process tree. Background children may need a short moment to exit.',
      accent: MixBuildPalette.error,
    );

    final isAndroid = project.type == MixbuildProjectType.android;
    final gradleLog = isAndroid
        ? _log(
            level: 'INFO',
            message:
                'Android project detected. Triggering gradle daemon stop command in background.',
            accent: MixBuildPalette.warning,
          )
        : null;

    final logsToRecord = <LogEntry>[
      interruptionLog,
      ?gradleLog,
    ];

    _recordImmediateExecutionLogs(
      projectId: project.id,
      scenarioId: scenario.id,
      logs: logsToRecord,
    );

    _updateScenario(
      projectId: project.id,
      scenarioId: scenario.id,
      transform: (current) => current.copyWith(
        status: BuildStatus.interrupted,
        progress: 0,
        logs: [
          ...logsToRecord,
          ...current.logs,
        ].toList(growable: false),
      ),
    );
    unawaited(_finalizeExecution(
      projectId: project.id,
      scenarioId: scenario.id,
      status: BuildStatus.interrupted,
    ));
  }

  DashboardState _stateFromConfigs(
      List<MixbuildConfig> configs, MixbuildConfig activeConfig,
      {List<BuildExecutionRecord> executionHistory =
          const <BuildExecutionRecord>[]}) {
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
      executionHistory: executionHistory,
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
              subtitle: 'No build scenario is defined in YAML',
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
                  message: 'This YAML does not define build_scenarios. Add one in the editor.',
                  accent: MixBuildPalette.warning,
                ),
              ],
            ),
          ]
        : scenarioConfigs.map((scenarioConfig) {
            return BuildScenario(
              id: scenarioConfig.id,
              name: scenarioConfig.name,
              subtitle: 'Driven by YAML scenario',
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
      type: config.mainProject.type,
      scenarios: scenarios,
    );
  }

  List<ResourceMetric> _buildMetrics(List<BuildScenario> scenarios) {
    final running =
        scenarios.where((item) => item.status.isPipelineActive).length;
    final failed =
        scenarios.where((item) => item.status == BuildStatus.failed).length;
    final coverage = scenarios.isEmpty ? 0.0 : running / scenarios.length;
    final hardwareSnapshot =
        _latestResourceSnapshot ?? SystemResourceSnapshot.fallback();
    return [
      ResourceMetric(
        label: 'CPU',
        value: hardwareSnapshot.cpuLabel,
        progress: hardwareSnapshot.cpuProgress,
        color: MixBuildPalette.tertiary,
      ),
      ResourceMetric(
        label: 'MEM',
        value: hardwareSnapshot.memoryLabel,
        progress: hardwareSnapshot.memoryProgress,
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
    BuildScenario? updatedScenario;
    final updatedProjects = state.projects.map((project) {
      if (project.id != projectId) {
        return project;
      }
      return project.copyWith(
        scenarios: project.scenarios.map((scenario) {
          if (scenario.id != scenarioId) {
            return scenario;
          }
          final transformed = transform(scenario);
          updatedScenario = transformed;
          return transformed;
        }).toList(growable: false),
      );
    }).toList(growable: false);
    final updatedExecutionHistory = updatedScenario == null
        ? state.executionHistory
        : _syncExecutionHistory(
            history: state.executionHistory,
            projectId: projectId,
            scenarioId: scenarioId,
            scenario: updatedScenario!,
          );
    state = state.copyWith(
      projects: updatedProjects,
      metrics: _buildMetrics(
        updatedProjects
            .expand((project) => project.scenarios)
            .toList(growable: false),
      ),
      executionHistory: updatedExecutionHistory,
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
      MixbuildProjectType.ios => Icons.phone_iphone,
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
      executionHistory: state.executionHistory,
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

  void _startExecution(ProjectBuild project, BuildScenario scenario) {
    final taskId =
        '${DateTime.now().microsecondsSinceEpoch}-${project.id.hashCode}-${scenario.id}';
    final executionKey = _executionKey(project.id, scenario.id);
    _activeExecutions[executionKey] = _ActiveExecutionContext(
      executionId: taskId,
    );
    state = state.copyWith(
      executionHistory: <BuildExecutionRecord>[
        BuildExecutionRecord(
          id: taskId,
          projectId: project.id,
          projectName: project.name,
          scenarioId: scenario.id,
          scenarioName: scenario.name,
          command: scenario.command,
          branch: scenario.mainBranch.trim().isEmpty
              ? project.branch
              : scenario.mainBranch,
          status: BuildStatus.validating,
          startedAt: DateTime.now(),
        ),
        ...state.executionHistory,
      ],
    );
    _scheduleHistoryPersist(immediate: false);
  }

  Future<void> _finalizeExecution({
    required String projectId,
    required String scenarioId,
    required BuildStatus status,
  }) async {
    _flushExecutionLogs(projectId, scenarioId);
    final executionKey = _executionKey(projectId, scenarioId);
    final context = _activeExecutions[executionKey];
    if (context == null) {
      return;
    }
    final scenario =
        _findScenario(projectId: projectId, scenarioId: scenarioId);
    if (scenario == null) {
      _activeExecutions.remove(executionKey);
      return;
    }
    final syncedHistory = _syncExecutionHistory(
      history: state.executionHistory,
      projectId: projectId,
      scenarioId: scenarioId,
      scenario: scenario,
    ).map((record) {
      if (record.id != context.executionId) {
        return record;
      }
      return record.copyWith(status: status, finishedAt: DateTime.now());
    }).toList(growable: false);
    context.flushTimer?.cancel();
    _activeExecutions.remove(executionKey);
    state = state.copyWith(executionHistory: syncedHistory);
    await _persistExecutionHistoryNow();
  }

  void _scheduleHistoryPersist({required bool immediate}) {
    _historyPersistDirty = true;
    _historyPersistDebounce?.cancel();
    if (immediate) {
      unawaited(_persistExecutionHistoryIfNeeded());
      return;
    }
    _historyPersistDebounce = Timer(
      _historyPersistDebounceDelay,
      () => unawaited(_persistExecutionHistoryIfNeeded()),
    );
  }

  Future<void> _persistExecutionHistoryIfNeeded() async {
    if (_historyPersistInFlight || !_historyPersistDirty) {
      return;
    }
    _historyPersistDirty = false;
    _historyPersistInFlight = true;
    final snapshot = List<BuildExecutionRecord>.from(state.executionHistory);
    try {
      _historyPersistTask =
          ref.read(buildExecutionHistoryStoreProvider).saveHistory(snapshot);
      await _historyPersistTask;
    } finally {
      _historyPersistTask = null;
      _historyPersistInFlight = false;
      if (_historyPersistDirty) {
        unawaited(_persistExecutionHistoryIfNeeded());
      }
    }
  }

  Future<void> _persistExecutionHistoryNow() async {
    _historyPersistDirty = true;
    _historyPersistDebounce?.cancel();
    while (_historyPersistInFlight) {
      await _historyPersistTask;
    }
    await _persistExecutionHistoryIfNeeded();
    while (_historyPersistInFlight) {
      await _historyPersistTask;
    }
  }

  String _executionKey(String projectId, String scenarioId) {
    return '$projectId::$scenarioId';
  }

  BuildScenario? _findScenario({
    required String projectId,
    required String scenarioId,
  }) {
    for (final project in state.projects) {
      if (project.id != projectId) {
        continue;
      }
      for (final scenario in project.scenarios) {
        if (scenario.id == scenarioId) {
          return scenario;
        }
      }
    }
    return null;
  }

  List<BuildExecutionRecord> _syncExecutionHistory({
    required List<BuildExecutionRecord> history,
    required String projectId,
    required String scenarioId,
    required BuildScenario scenario,
  }) {
    final context = _activeExecutions[_executionKey(projectId, scenarioId)];
    if (context == null) {
      return history;
    }
    return history.map((record) {
      if (record.id != context.executionId) {
        return record;
      }
      return record.copyWith(
        status: scenario.status,
        branch: scenario.mainBranch,
        logs: List<LogEntry>.from(context.executionLogs, growable: false),
      );
    }).toList(growable: false);
  }

  void _recordImmediateExecutionLogs({
    required String projectId,
    required String scenarioId,
    required List<LogEntry> logs,
  }) {
    if (logs.isEmpty) {
      return;
    }
    final context = _activeExecutions[_executionKey(projectId, scenarioId)];
    if (context != null) {
      context.executionLogs.insertAll(0, logs);
    }
    _scheduleHistoryPersist(immediate: false);
  }

  void _enqueueExecutionLog({
    required String projectId,
    required String scenarioId,
    required LogEntry entry,
  }) {
    final context = _activeExecutions[_executionKey(projectId, scenarioId)];
    if (context == null) {
      _updateScenario(
        projectId: projectId,
        scenarioId: scenarioId,
        transform: (current) => current.copyWith(
          logs: [entry, ...current.logs].toList(growable: false),
        ),
      );
      return;
    }
    context.pendingLogs.add(entry);
    context.flushTimer ??= Timer(_logFlushInterval, () {
      context.flushTimer = null;
      _flushExecutionLogs(projectId, scenarioId);
    });
  }

  void _flushExecutionLogs(String projectId, String scenarioId) {
    final context = _activeExecutions[_executionKey(projectId, scenarioId)];
    if (context == null || context.pendingLogs.isEmpty) {
      return;
    }
    context.flushTimer?.cancel();
    context.flushTimer = null;
    final batch = List<LogEntry>.from(context.pendingLogs, growable: false);
    context.pendingLogs.clear();
    final newestFirstBatch = batch.reversed.toList(growable: false);
    context.executionLogs.insertAll(0, newestFirstBatch);
    _updateScenario(
      projectId: projectId,
      scenarioId: scenarioId,
      transform: (current) => current.copyWith(
        logs: <LogEntry>[
          ...newestFirstBatch,
          ...current.logs,
        ].take(_maxScenarioLogEntries).toList(growable: false),
      ),
    );
    _scheduleHistoryPersist(immediate: false);
  }

  void _startResourceMonitoring() {
    _resourceRefreshTimer?.cancel();
    Timer.run(_refreshResourceMetrics);
    _resourceRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshResourceMetrics(),
    );
  }

  Future<void> _refreshResourceMetrics() async {
    if (_isDisposed) {
      return;
    }
    final snapshot = await ref.read(systemResourceMonitorProvider).sample();
    if (_isDisposed) {
      return;
    }
    _latestResourceSnapshot = snapshot;
    state = state.copyWith(
      metrics: _buildMetrics(
        state.projects
            .expand((project) => project.scenarios)
            .toList(growable: false),
      ),
    );
  }

  /// Exports all workspace configs as a ZIP file through the system file picker.
  Future<int> exportConfigToZip() async {
    final store = ref.read(mixbuildYamlStoreProvider);
    final zipBytes = store.exportAllToZipBytes();
    final workspaceCount = store.discoverWorkspaceYamlFilesSync().length;

    final saveLocation = await getSaveLocation(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'ZIP', extensions: ['zip']),
      ],
      suggestedName: 'mixbuild_config.zip',
    );
    if (saveLocation == null) {
      return 0; // User cancelled.
    }

    File(saveLocation.path).writeAsBytesSync(zipBytes);
    return workspaceCount;
  }

  /// Imports workspace configs from a ZIP selected through the system file picker.
  Future<int> importConfigFromZip() async {
    final typeGroup = XTypeGroup(
      label: 'ZIP',
      extensions: ['zip'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) {
      return 0; // User cancelled.
    }

    final zipBytes = File(file.path).readAsBytesSync();
    final store = ref.read(mixbuildYamlStoreProvider);
    final importedConfigs = store.importFromZipBytes(zipBytes);

    if (importedConfigs.isNotEmpty) {
      // Reload all configs.
      final yamlFiles = store.discoverWorkspaceYamlFilesSync();
      final configs = <MixbuildConfig>[];
      for (final yamlFile in yamlFiles) {
        try {
          configs.add(MixbuildConfig.fromFileSync(yamlFile.path));
        } catch (_) {}
      }
      if (configs.isNotEmpty) {
        final activeConfig = configs.last;
        _applyConfig(activeConfig, preserveError: false);
      }
    }

    return importedConfigs.length;
  }

  /// Clears all historical build logs.
  Future<int> clearAllExecutionLogs() async {
    final store = ref.read(buildExecutionHistoryStoreProvider);
    final count = await store.clearAllLogs();
    state = state.copyWith(executionHistory: []);
    return count;
  }
}

class _ActiveExecutionContext {
  _ActiveExecutionContext({required this.executionId});

  final String executionId;
  final List<LogEntry> executionLogs = <LogEntry>[];
  final List<LogEntry> pendingLogs = <LogEntry>[];
  Timer? flushTimer;
}
