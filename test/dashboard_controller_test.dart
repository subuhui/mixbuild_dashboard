import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/system_resource_monitor.dart';
import 'package:mixbuild_dashboard/services/mixbuild_yaml_store.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';

void main() {
  group('DashboardController', () {
    late Directory tempDir;
    late MixbuildYamlStore store;
    late ProviderContainer container;
    late _FakeSystemResourceMonitor resourceMonitor;

    setUp(() {
      tempDir = Directory.systemTemp
          .createTempSync('mixbuild-dashboard-controller-test');
      store = MixbuildYamlStore(configHomePath: tempDir.path);
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

    test('updateProjectConfiguration persists scenario main branch', () async {
      final controller = container.read(dashboardControllerProvider.notifier);
      final currentState = container.read(dashboardControllerProvider);

      await controller.updateProjectConfiguration(
        config: currentState.globalConfig,
        bindings: const [
          ProjectBindingConfig(
            projectName: 'main_project',
            path: '.',
            type: MixbuildProjectType.flutter,
            defaultBranch: 'develop',
            restoreCommand: 'fvm flutter pub get',
            isMainProject: true,
          ),
          ProjectBindingConfig(
            projectName: 'common_ui',
            path: 'modules/common_ui',
            type: MixbuildProjectType.flutter,
            defaultBranch: 'main',
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
            mainBranch: 'release/main-project',
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
          ),
        ],
      );

      final savedConfig = store.loadConfigSync(
        container.read(dashboardControllerProvider).config.filePath,
      );

      expect(savedConfig.mainProject.defaultBranch, 'develop');
      expect(savedConfig.buildScenarios, hasLength(1));
      expect(
          savedConfig.buildScenarios.single.mainBranch, 'release/main-project');
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
      defaultBranch: 'develop',
      restoreCommand: 'fvm flutter pub get',
    ),
    dependencies: <MixbuildRepoConfig>[
      MixbuildRepoConfig(
        name: 'common_ui',
        path: 'modules/common_ui',
        type: MixbuildProjectType.flutter,
        defaultBranch: 'main',
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

class _FakeSystemResourceMonitor implements SystemResourceMonitor {
  const _FakeSystemResourceMonitor(this.snapshot);

  final SystemResourceSnapshot snapshot;

  @override
  Future<SystemResourceSnapshot> sample() async => snapshot;
}
