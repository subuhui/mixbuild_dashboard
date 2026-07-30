import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/ui/project_editor_page.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('initial workspace scan shows discovered git projects',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final workspaceRoot =
        await Directory.systemTemp.createTemp('mixbuild_project_editor_');
    addTearDown(() async {
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    });

    await Directory(p.join(workspaceRoot.path, 'android-driver', '.git'))
        .create(recursive: true);
    await Directory(p.join(workspaceRoot.path, 'driver-v2', '.git'))
        .create(recursive: true);

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectEditorPage(
          config: GlobalConfig(
            workspaceRoot: workspaceRoot.path,
            activeProjectName: 'Runner Actions',
            bindings: const <WorkspaceBinding>[
              WorkspaceBinding(
                  projectName: 'main_project', path: 'main_project'),
            ],
          ),
          scenarios: const <BuildScenario>[],
          baseDependencies: const <DependencyBranch>[],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('android-driver'), findsOneWidget);
    expect(find.text('driver-v2'), findsOneWidget);
    expect(find.text('可选 2'), findsOneWidget);
  });

  testWidgets('keeps dependency restore command after workspace scan',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final workspaceRoot =
        await Directory.systemTemp.createTemp('mixbuild_project_editor_');
    addTearDown(() async {
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    });

    await Directory(p.join(workspaceRoot.path, 'app-main', '.git'))
        .create(recursive: true);
    await Directory(p.join(workspaceRoot.path, 'android-lib', '.git'))
        .create(recursive: true);

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectEditorPage(
          config: GlobalConfig(
            workspaceRoot: workspaceRoot.path,
            activeProjectName: 'Runner Actions',
            bindings: const <WorkspaceBinding>[
              WorkspaceBinding(
                projectName: 'app-main',
                path: 'app-main',
                type: MixbuildProjectType.android,
                defaultBranch: 'main',
              ),
              WorkspaceBinding(
                projectName: 'android-lib',
                path: 'android-lib',
                type: MixbuildProjectType.android,
                defaultBranch: 'develop',
                restoreCommand: './gradlew :lib:publishToMavenLocal',
              ),
            ],
          ),
          scenarios: const <BuildScenario>[],
          baseDependencies: const <DependencyBranch>[],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('./gradlew :lib:publishToMavenLocal'), findsOneWidget);
    expect(find.text('./gradlew assembleRelease'), findsNothing);
  });
}
