import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/app/mixbuild_app.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/mixbuild_yaml_store.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/ui/project_detail_page.dart';
import 'package:mixbuild_dashboard/ui/project_editor_page.dart';

void main() {
  group('Responsive layout', () {
    testWidgets('dashboard home renders without overflow on compact width', (
      tester,
    ) async {
      _setSurfaceSize(tester, const Size(780, 1100));

      await tester.pumpWidget(const MixBuildApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('project detail renders without overflow on medium width', (
      tester,
    ) async {
      _setSurfaceSize(tester, const Size(920, 1100));

      final tempDir = Directory.systemTemp.createTempSync(
        'mixbuild-responsive-detail',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final store = MixbuildYamlStore(configHomePath: tempDir.path);
      store.saveConfigSync(_seedConfig());
      final container = ProviderContainer(
        overrides: [mixbuildYamlStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final state = container.read(dashboardControllerProvider);
      final project = state.projects.first;
      final scenario = project.scenarios.first;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ProjectDetailPage(
              projectId: project.id,
              scenarioId: scenario.id,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('project detail header renders without overflow on narrow width', (
      tester,
    ) async {
      _setSurfaceSize(tester, const Size(780, 1100));

      final tempDir = Directory.systemTemp.createTempSync(
        'mixbuild-responsive-detail-header',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final store = MixbuildYamlStore(configHomePath: tempDir.path);
      store.saveConfigSync(_seedConfig());
      final container = ProviderContainer(
        overrides: [mixbuildYamlStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final state = container.read(dashboardControllerProvider);
      final project = state.projects.first;
      final scenario = project.scenarios.first;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ProjectDetailPage(
              projectId: project.id,
              scenarioId: scenario.id,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('project editor renders without overflow on medium width', (
      tester,
    ) async {
      _setSurfaceSize(tester, const Size(860, 1100));

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectEditorPage(
            config: const GlobalConfig(
              workspaceRoot: '/tmp/workspace-demo',
              activeProjectName: 'Runner Actions',
              bindings: <WorkspaceBinding>[
                WorkspaceBinding(
                  projectName: 'main_project',
                  path: '.',
                  type: MixbuildProjectType.flutter,
                  defaultBranch: 'main',
                  restoreCommand: 'fvm flutter pub get',
                ),
                WorkspaceBinding(
                  projectName: 'common_ui',
                  path: 'modules/common_ui',
                  type: MixbuildProjectType.flutter,
                  defaultBranch: 'develop',
                  restoreCommand: 'fvm flutter pub get',
                ),
              ],
            ),
            scenarios: const <BuildScenario>[
              BuildScenario(
                id: 'release-build',
                name: 'Release Build',
                subtitle: '由 YAML 场景驱动',
                environment: 'workspace-demo',
                mainBranch: 'main',
                command: 'fvm flutter build macos --release',
                status: BuildStatus.idle,
                progress: 0,
                logs: <LogEntry>[],
                dependencies: <DependencyBranch>[
                  DependencyBranch(
                    name: 'common_ui',
                    branch: 'develop',
                    icon: Icons.layers_outlined,
                  ),
                ],
                outputPath: 'build/macos/Build/Products/Release',
                autoTag: true,
                tagPrefix: 'release_',
              ),
            ],
            baseDependencies: const <DependencyBranch>[
              DependencyBranch(
                name: 'common_ui',
                branch: 'develop',
                icon: Icons.layers_outlined,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });
}

void _setSurfaceSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
