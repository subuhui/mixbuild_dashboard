import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/build_execution_history_store.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:mixbuild_dashboard/services/mixbuild_engine.dart';
import 'package:mixbuild_dashboard/services/system_resource_monitor.dart';
import 'package:mixbuild_dashboard/services/mixbuild_yaml_store.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/state/dashboard_state.dart';

void main() {
  group('DashboardController', () {
    late Directory tempDir;
    late MixbuildYamlStore store;
    late BuildExecutionHistoryStore historyStore;
    late ProviderContainer container;
    late _FakeSystemResourceMonitor resourceMonitor;

    setUp(() {
      tempDir = Directory.systemTemp
          .createTempSync('mixbuild-dashboard-controller-test');
      store = MixbuildYamlStore(configHomePath: tempDir.path);
      historyStore = BuildExecutionHistoryStore(configHomePath: tempDir.path);
      store.saveConfigSync(_seedConfig());
      resourceMonitor = _FakeSystemResourceMonitor(
        const SystemResourceSnapshot(
          cpuUsagePercent: 64,
          memoryUsedBytes: 24 * 1024 * 1024 * 1024,
          totalMemoryBytes: 64 * 1024 * 1024 * 1024,
        ),
      );
      container = ProviderContainer(
        overrides: [
          mixbuildYamlStoreProvider.overrideWithValue(store),
          buildExecutionHistoryStoreProvider.overrideWithValue(historyStore),
          systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
        ],
      );
      addTearDown(() {
        container.dispose();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    test('editorBaseDependencies reflects scenario override branch', () {
      final controller = container.read(dashboardControllerProvider.notifier);

      controller.changeDependencyBranch(
          'common_ui', 'feature/runtime-override');

      final dependency = controller.editorBaseDependencies().singleWhere(
            (item) => item.name == 'common_ui',
          );

      expect(dependency.branch, 'feature/runtime-override');
      expect(dependency.highlight, MixBuildPalette.primary);
    });

    test('updateProjectConfiguration persists scenario command', () async {
      final controller = container.read(dashboardControllerProvider.notifier);
      final currentState = container.read(dashboardControllerProvider);

      await controller.updateProjectConfiguration(
        config: currentState.globalConfig,
        bindings: const [
          ProjectBindingConfig(
            projectName: 'main_project',
            path: '.',
            type: MixbuildProjectType.flutter,
            restoreCommand: 'fvm flutter pub get',
            isMainProject: true,
          ),
          ProjectBindingConfig(
            projectName: 'common_ui',
            path: 'modules/common_ui',
            type: MixbuildProjectType.flutter,
            restoreCommand: 'fvm flutter pub get',
            isMainProject: false,
          ),
        ],
        scenarios: const [
          BuildScenario(
            id: 'release-build',
            name: 'Release Build',
            subtitle: '由 YAML 场景驱动',
            environment: 'workspace-demo',
            command: 'fvm flutter build macos --release',
            status: BuildStatus.idle,
            progress: 0,
            logs: <LogEntry>[],
            dependencies: <DependencyBranch>[
              DependencyBranch(
                name: 'common_ui',
                branch: 'main',
                icon: Icons.layers_outlined,
              ),
            ],
            outputPath: 'build/macos/Build/Products/Release',
            autoTag: true,
            tagPrefix: 'release_',
            mainBranch: 'develop',
          ),
        ],
      );

      final savedConfig = store.loadConfigSync(
        container.read(dashboardControllerProvider).config.filePath,
      );

      expect(savedConfig.buildScenarios, hasLength(1));
      expect(savedConfig.buildScenarios.single.command,
          'fvm flutter build macos --release');
    });

    test('metrics use dynamic hardware snapshot for CPU and MEM', () async {
      container.read(dashboardControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final metrics = container.read(dashboardControllerProvider).metrics;
      final cpu = metrics.firstWhere((item) => item.label == 'CPU');
      final memory = metrics.firstWhere((item) => item.label == 'MEM');

      expect(cpu.value, '64%');
      expect(cpu.progress, 0.64);
      expect(memory.value, '24.0/64GB');
      expect(memory.progress, 0.375);
    });

    test('triggerSelectedScenario stores execution history with task logs',
        () async {
      final fakeEngine = _FakeMixbuildEngine(
        onRunPipelineImpl: ({
          required config,
          required project,
          required scenario,
          required projectBranch,
          required cleanBeforeBuild,
          required dependencyOverrides,
          required onProgress,
          required onLog,
        }) async {
          onProgress(BuildStatus.building, 0.6);
          onLog(
            LogEntry(
              time: '11:20:00',
              level: 'INFO',
              message: 'Build started',
              accent: MixBuildPalette.primary,
            ),
          );
          onProgress(BuildStatus.success, 1.0);
          onLog(
            LogEntry(
              time: '11:20:10',
              level: 'INFO',
              message: 'Build completed',
              accent: MixBuildPalette.success,
            ),
          );
        },
      );
      final localContainer = ProviderContainer(
        overrides: [
          mixbuildYamlStoreProvider.overrideWithValue(store),
          buildExecutionHistoryStoreProvider.overrideWithValue(historyStore),
          systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
          mixbuildEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
      addTearDown(localContainer.dispose);

      final controller =
          localContainer.read(dashboardControllerProvider.notifier);
      await controller.triggerSelectedScenario();

      final history =
          localContainer.read(dashboardControllerProvider).executionHistory;
      expect(history, hasLength(1));
      expect(history.first.projectName, 'workspace-demo');
      expect(history.first.scenarioName, 'Release Build');
      expect(history.first.status, BuildStatus.success);
      expect(history.first.finishedAt, isNotNull);
      expect(
        history.first.logs.any((entry) => entry.message == 'Build completed'),
        isTrue,
      );
      expect(
        history.first.logs.any(
          (entry) => entry.message.contains('Queued pipeline for'),
        ),
        isTrue,
      );
      final persistedHistory = historyStore.loadHistorySync();
      expect(persistedHistory, hasLength(1));
      expect(persistedHistory.first.status, BuildStatus.success);
    });

    test('execution history is restored from local storage on startup', () {
      historyStore.saveHistorySync(
        <BuildExecutionRecord>[
          BuildExecutionRecord(
            id: 'persisted-task',
            projectId: 'seed.yaml',
            projectName: 'workspace-demo',
            scenarioId: 'release-build',
            scenarioName: 'Release Build',
            command: 'fvm flutter build macos --release',
            branch: 'develop',
            status: BuildStatus.failed,
            startedAt: DateTime(2026, 5, 23, 11, 30),
            finishedAt: DateTime(2026, 5, 23, 11, 31),
            logs: <LogEntry>[
              LogEntry(
                time: '11:30:00',
                level: 'ERROR',
                message: 'Persisted failure',
                accent: MixBuildPalette.error,
              ),
            ],
          ),
        ],
      );

      final restoredContainer = ProviderContainer(
        overrides: [
          mixbuildYamlStoreProvider.overrideWithValue(store),
          buildExecutionHistoryStoreProvider.overrideWithValue(historyStore),
          systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
        ],
      );
      addTearDown(restoredContainer.dispose);

      final restoredState = restoredContainer.read(dashboardControllerProvider);
      expect(restoredState.executionHistory, hasLength(1));
      expect(restoredState.executionHistory.first.id, 'persisted-task');
      expect(restoredState.executionHistory.first.logs.single.message,
          'Persisted failure');
    });

    test('triggerSelectedScenario batches log UI updates and history writes',
        () async {
      final historySpy = _SpyBuildExecutionHistoryStore(
        configHomePath: tempDir.path,
      );
      final fakeEngine = _FakeMixbuildEngine(
        onRunPipelineImpl: ({
          required config,
          required project,
          required scenario,
          required projectBranch,
          required cleanBeforeBuild,
          required dependencyOverrides,
          required onProgress,
          required onLog,
        }) async {
          onProgress(BuildStatus.building, 0.6);
          for (var i = 0; i < 40; i++) {
            onLog(
              LogEntry(
                time: '11:20:${i.toString().padLeft(2, '0')}',
                level: 'OUT',
                message: 'line-$i',
                accent: MixBuildPalette.muted,
              ),
            );
          }
          onProgress(BuildStatus.success, 1.0);
        },
      );
      final localContainer = ProviderContainer(
        overrides: [
          mixbuildYamlStoreProvider.overrideWithValue(store),
          buildExecutionHistoryStoreProvider.overrideWithValue(historySpy),
          systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
          mixbuildEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
      addTearDown(localContainer.dispose);

      var stateChanges = 0;
      final subscription = localContainer.listen<DashboardState>(
        dashboardControllerProvider,
        (_, _) => stateChanges++,
      );
      addTearDown(subscription.close);

      final controller =
          localContainer.read(dashboardControllerProvider.notifier);
      await controller.triggerSelectedScenario();
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final history =
          localContainer.read(dashboardControllerProvider).executionHistory;
      final lineLogs = history.first.logs
          .where((entry) => entry.message.startsWith('line-'))
          .toList(growable: false);

      expect(lineLogs, hasLength(40));
      expect(stateChanges, lessThan(18));
      expect(historySpy.saveCalls, lessThan(18));
    });

    test(
        'triggerBuildFromRequest matches scenario name and passes requested branch',
        () async {
      store.saveConfigSync(_triggerSeedConfig());
      String? capturedProjectBranch;
      String? capturedScenarioName;
      final fakeEngine = _FakeMixbuildEngine(
        onRunPipelineImpl: ({
          required config,
          required project,
          required scenario,
          required projectBranch,
          required cleanBeforeBuild,
          required dependencyOverrides,
          required onProgress,
          required onLog,
        }) async {
          capturedProjectBranch = projectBranch;
          capturedScenarioName = scenario.name;
          onProgress(BuildStatus.success, 1.0);
        },
      );
      final localContainer = ProviderContainer(
        overrides: [
          mixbuildYamlStoreProvider.overrideWithValue(store),
          buildExecutionHistoryStoreProvider.overrideWithValue(historyStore),
          systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
          mixbuildEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
      addTearDown(localContainer.dispose);

      final controller =
          localContainer.read(dashboardControllerProvider.notifier);
      final result = await controller.triggerBuildFromRequest(
        scenarioName: 'Release Build',
        branch: 'release/v1.2',
      );

      expect(result.accepted, isTrue);
      expect(result.scenarioName, 'Release Build');
      expect(result.branch, 'release/v1.2');
      expect(capturedScenarioName, 'Release Build');
      expect(capturedProjectBranch, 'release/v1.2');
    });

    test('triggerBuildFromRequest matches main project name and branch', () async {
      store.saveConfigSync(_triggerSeedConfig());
      String? capturedProjectBranch;
      String? capturedScenarioName;
      final fakeEngine = _FakeMixbuildEngine(
        onRunPipelineImpl: ({
          required config,
          required project,
          required scenario,
          required projectBranch,
          required cleanBeforeBuild,
          required dependencyOverrides,
          required onProgress,
          required onLog,
        }) async {
          capturedProjectBranch = projectBranch;
          capturedScenarioName = scenario.name;
          onProgress(BuildStatus.success, 1.0);
        },
      );
      final localContainer = ProviderContainer(
        overrides: [
          mixbuildYamlStoreProvider.overrideWithValue(store),
          buildExecutionHistoryStoreProvider.overrideWithValue(historyStore),
          systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
          mixbuildEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
      addTearDown(localContainer.dispose);

      final controller = localContainer.read(dashboardControllerProvider.notifier);
      final result = await controller.triggerBuildFromRequest(
        projectName: 'main_project',
        branch: 'develop',
      );

      expect(result.accepted, isTrue);
      expect(result.scenarioName, 'Debug Build');
      expect(result.branch, 'develop');
      expect(capturedScenarioName, 'Debug Build');
      expect(capturedProjectBranch, 'develop');
    });

    test('triggerBuildFromRequest matches dependency name and override branch', () async {
      store.saveConfigSync(_dependencyTriggerSeedConfig());
      String? capturedProjectBranch;
      String? capturedScenarioName;
      final fakeEngine = _FakeMixbuildEngine(
        onRunPipelineImpl: ({
          required config,
          required project,
          required scenario,
          required projectBranch,
          required cleanBeforeBuild,
          required dependencyOverrides,
          required onProgress,
          required onLog,
        }) async {
          capturedProjectBranch = projectBranch;
          capturedScenarioName = scenario.name;
          onProgress(BuildStatus.success, 1.0);
        },
      );
      final localContainer = ProviderContainer(
        overrides: [
          mixbuildYamlStoreProvider.overrideWithValue(store),
          buildExecutionHistoryStoreProvider.overrideWithValue(historyStore),
          systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
          mixbuildEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
      addTearDown(localContainer.dispose);

      final controller = localContainer.read(dashboardControllerProvider.notifier);
      final result = await controller.triggerBuildFromRequest(
        projectName: 'common_ui',
        branch: 'release/v1.0',
      );

      expect(result.accepted, isTrue);
      expect(result.scenarioName, 'Release Build');
      expect(result.branch, 'release/v1.0');
      expect(capturedScenarioName, 'Release Build');
      expect(capturedProjectBranch, 'release/v1.0');
    });

    test('triggerBuildFromRequest matches scenario name and dependency override branch', () async {
      store.saveConfigSync(_dependencyTriggerSeedConfig());
      String? capturedProjectBranch;
      String? capturedScenarioName;
      final fakeEngine = _FakeMixbuildEngine(
        onRunPipelineImpl: ({
          required config,
          required project,
          required scenario,
          required projectBranch,
          required cleanBeforeBuild,
          required dependencyOverrides,
          required onProgress,
          required onLog,
        }) async {
          capturedProjectBranch = projectBranch;
          capturedScenarioName = scenario.name;
          onProgress(BuildStatus.success, 1.0);
        },
      );
      final localContainer = ProviderContainer(
        overrides: [
          mixbuildYamlStoreProvider.overrideWithValue(store),
          buildExecutionHistoryStoreProvider.overrideWithValue(historyStore),
          systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
          mixbuildEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
      addTearDown(localContainer.dispose);

      final controller = localContainer.read(dashboardControllerProvider.notifier);
      final result = await controller.triggerBuildFromRequest(
        scenarioName: 'Release Build',
        branch: 'release/v1.0',
      );

      expect(result.accepted, isTrue);
      expect(result.scenarioName, 'Release Build');
      expect(result.branch, 'release/v1.0');
      expect(capturedScenarioName, 'Release Build');
      expect(capturedProjectBranch, 'release/v1.0');
    });

    test('triggerBuildFromRequest matches dependency name containing slashes by last segment', () async {
      store.saveConfigSync(_slashDependencyTriggerSeedConfig());
      String? capturedProjectBranch;
      String? capturedScenarioName;
      final fakeEngine = _FakeMixbuildEngine(
        onRunPipelineImpl: ({
          required config,
          required project,
          required scenario,
          required projectBranch,
          required cleanBeforeBuild,
          required dependencyOverrides,
          required onProgress,
          required onLog,
        }) async {
          capturedProjectBranch = projectBranch;
          capturedScenarioName = scenario.name;
          onProgress(BuildStatus.success, 1.0);
        },
      );
      final localContainer = ProviderContainer(
        overrides: [
          mixbuildYamlStoreProvider.overrideWithValue(store),
          buildExecutionHistoryStoreProvider.overrideWithValue(historyStore),
          systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
          mixbuildEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
      addTearDown(localContainer.dispose);

      final controller = localContainer.read(dashboardControllerProvider.notifier);
      final result = await controller.triggerBuildFromRequest(
        projectName: 'common_ui',
        branch: 'release/v1.0',
      );

      expect(result.accepted, isTrue);
      expect(result.scenarioName, 'Release Build');
      expect(result.branch, 'release/v1.0');
      expect(capturedScenarioName, 'Release Build');
      expect(capturedProjectBranch, 'release/v1.0');
    });
  });
}

MixbuildConfig _seedConfig() {
  return const MixbuildConfig(
    filePath: 'seed.yaml',
    workspace: MixbuildWorkspaceConfig(
      name: 'workspace-demo',
      rootPath: '/tmp/workspace-demo',
    ),
    mainProject: MixbuildRepoConfig(
      name: 'main_project',
      path: '.',
      type: MixbuildProjectType.flutter,
      restoreCommand: 'fvm flutter pub get',
    ),
    dependencies: <MixbuildRepoConfig>[
      MixbuildRepoConfig(
        name: 'common_ui',
        path: 'modules/common_ui',
        type: MixbuildProjectType.flutter,
        restoreCommand: 'fvm flutter pub get',
      ),
    ],
    buildScenarios: <MixbuildScenarioConfig>[
      MixbuildScenarioConfig(
        id: 'release-build',
        name: 'Release Build',
        mainBranch: 'develop',
        command: 'fvm flutter build macos --release',
        outputDir: 'build/macos/Build/Products/Release',
      ),
    ],
  );
}

MixbuildConfig _triggerSeedConfig() {
  return const MixbuildConfig(
    filePath: 'trigger-seed.yaml',
    workspace: MixbuildWorkspaceConfig(
      name: 'workspace-demo',
      rootPath: '/tmp/workspace-demo',
    ),
    mainProject: MixbuildRepoConfig(
      name: 'main_project',
      path: '.',
      type: MixbuildProjectType.flutter,
      restoreCommand: 'fvm flutter pub get',
    ),
    dependencies: <MixbuildRepoConfig>[],
    buildScenarios: <MixbuildScenarioConfig>[
      MixbuildScenarioConfig(
        id: 'debug-build',
        name: 'Debug Build',
        mainBranch: 'develop',
        command: 'fvm flutter build macos --debug',
      ),
      MixbuildScenarioConfig(
        id: 'release-build',
        name: 'Release Build',
        mainBranch: 'release/v1.2',
        command: 'fvm flutter build macos --release',
      ),
    ],
  );
}

MixbuildConfig _dependencyTriggerSeedConfig() {
  return const MixbuildConfig(
    filePath: 'dep-trigger-seed.yaml',
    workspace: MixbuildWorkspaceConfig(
      name: 'workspace-demo',
      rootPath: '/tmp/workspace-demo',
    ),
    mainProject: MixbuildRepoConfig(
      name: 'main_project',
      path: '.',
      type: MixbuildProjectType.flutter,
      restoreCommand: 'fvm flutter pub get',
    ),
    dependencies: <MixbuildRepoConfig>[
      MixbuildRepoConfig(
        name: 'common_ui',
        path: 'modules/common_ui',
        type: MixbuildProjectType.flutter,
        restoreCommand: 'fvm flutter pub get',
      ),
    ],
    buildScenarios: <MixbuildScenarioConfig>[
      MixbuildScenarioConfig(
        id: 'debug-build',
        name: 'Debug Build',
        mainBranch: 'develop',
        command: 'fvm flutter build macos --debug',
        dependencyOverrides: {'common_ui': 'feature/ui-new'},
      ),
      MixbuildScenarioConfig(
        id: 'release-build',
        name: 'Release Build',
        mainBranch: 'develop',
        command: 'fvm flutter build macos --release',
        dependencyOverrides: {'common_ui': 'release/v1.0'},
      ),
    ],
  );
}

class _FakeSystemResourceMonitor implements SystemResourceMonitor {
  const _FakeSystemResourceMonitor(this.snapshot);

  final SystemResourceSnapshot snapshot;

  @override
  Future<SystemResourceSnapshot> sample() async => snapshot;
}

class _SpyBuildExecutionHistoryStore extends BuildExecutionHistoryStore {
  _SpyBuildExecutionHistoryStore({required super.configHomePath});

  int saveCalls = 0;

  @override
  Future<void> saveHistory(List<BuildExecutionRecord> history) async {
    saveCalls++;
    await super.saveHistory(history);
  }
}

class _FakeMixbuildEngine extends MixbuildEngine {
  _FakeMixbuildEngine({required this.onRunPipelineImpl})
      : super(_NoopCommandRunner());

  final Future<void> Function({
    required MixbuildConfig config,
    required ProjectBuild project,
    required BuildScenario scenario,
    required String projectBranch,
    required bool cleanBeforeBuild,
    required Map<String, String> dependencyOverrides,
    required void Function(BuildStatus status, double progress) onProgress,
    required void Function(LogEntry entry) onLog,
  }) onRunPipelineImpl;

  @override
  Future<void> runPipeline({
    required MixbuildConfig config,
    required ProjectBuild project,
    required BuildScenario scenario,
    required String projectBranch,
    required bool cleanBeforeBuild,
    required Map<String, String> dependencyOverrides,
    required void Function(BuildStatus status, double progress) onProgress,
    required void Function(LogEntry entry) onLog,
  }) {
    return onRunPipelineImpl(
      config: config,
      project: project,
      scenario: scenario,
      projectBranch: projectBranch,
      cleanBeforeBuild: cleanBeforeBuild,
      dependencyOverrides: dependencyOverrides,
      onProgress: onProgress,
      onLog: onLog,
    );
  }
}

class _NoopCommandRunner implements MixbuildCommandRunner {
  @override
  bool killActive([ProcessSignal signal = ProcessSignal.sigkill]) => false;

  @override
  Future<void> openPath(String path) async {}

  @override
  Future<CommandRunResult> run(
    String command, {
    required String workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onStdout,
    void Function(String line)? onStderr,
  }) async {
    return CommandRunResult(
      command: command,
      workingDirectory: workingDirectory,
      exitCode: 0,
      stdout: '',
      stderr: '',
    );
  }

  @override
  Future<CommandRunResult> runProcess(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onStdout,
    void Function(String line)? onStderr,
  }) async {
    return CommandRunResult(
      command: [executable, ...arguments].join(' '),
      workingDirectory: workingDirectory,
      exitCode: 0,
      stdout: '',
      stderr: '',
    );
  }

  @override
  String? which(String command) => '/mock/bin/$command';
}

MixbuildConfig _slashDependencyTriggerSeedConfig() {
  return const MixbuildConfig(
    filePath: 'slash-dep-trigger-seed.yaml',
    workspace: MixbuildWorkspaceConfig(
      name: 'workspace-demo',
      rootPath: '/tmp/workspace-demo',
    ),
    mainProject: MixbuildRepoConfig(
      name: 'main_project',
      path: '.',
      type: MixbuildProjectType.flutter,
      restoreCommand: 'fvm flutter pub get',
    ),
    dependencies: <MixbuildRepoConfig>[
      MixbuildRepoConfig(
        name: 'code/common_ui',
        path: 'modules/common_ui',
        type: MixbuildProjectType.flutter,
        restoreCommand: 'fvm flutter pub get',
      ),
    ],
    buildScenarios: <MixbuildScenarioConfig>[
      MixbuildScenarioConfig(
        id: 'release-build',
        name: 'Release Build',
        mainBranch: 'develop',
        command: 'fvm flutter build macos --release',
        dependencyOverrides: {'code/common_ui': 'release/v1.0'},
      ),
    ],
  );
}
