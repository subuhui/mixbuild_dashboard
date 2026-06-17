import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/services/git_branch_discovery.dart';
import 'package:mixbuild_dashboard/services/git_project_discovery.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:mixbuild_dashboard/ui/project_editor_page.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('initial workspace scan shows discovered git projects',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final workspaceRoot =
        Directory.systemTemp.createTempSync('mixbuild_project_editor_');
    addTearDown(() async {
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    });

    Directory(p.join(workspaceRoot.path, 'android-driver', '.git'))
        .createSync(recursive: true);
    Directory(p.join(workspaceRoot.path, 'driver-v2', '.git'))
        .createSync(recursive: true);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
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
          gitBranchDiscovery: GitBranchDiscovery(runner: _FastFailRunner()),
          gitProjectDiscovery: _FakeGitProjectDiscovery(
            <DiscoveredGitProject>[
              DiscoveredGitProject(
                name: 'android-driver',
                absolutePath: p.join(workspaceRoot.path, 'android-driver'),
                relativePath: 'android-driver',
              ),
              DiscoveredGitProject(
                name: 'driver-v2',
                absolutePath: p.join(workspaceRoot.path, 'driver-v2'),
                relativePath: 'driver-v2',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('android-driver'), findsWidgets);
    expect(find.text('driver-v2'), findsWidgets);
    expect(find.text('可选 2'), findsOneWidget);
  });

  testWidgets('keeps dependency restore command after workspace scan',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final workspaceRoot =
        Directory.systemTemp.createTempSync('mixbuild_project_editor_');
    addTearDown(() async {
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    });

    Directory(p.join(workspaceRoot.path, 'app-main', '.git'))
        .createSync(recursive: true);
    Directory(p.join(workspaceRoot.path, 'android-lib', '.git'))
        .createSync(recursive: true);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
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
          gitBranchDiscovery: GitBranchDiscovery(runner: _FastFailRunner()),
          gitProjectDiscovery: _FakeGitProjectDiscovery(
            <DiscoveredGitProject>[
              DiscoveredGitProject(
                name: 'app-main',
                absolutePath: p.join(workspaceRoot.path, 'app-main'),
                relativePath: 'app-main',
              ),
              DiscoveredGitProject(
                name: 'android-lib',
                absolutePath: p.join(workspaceRoot.path, 'android-lib'),
                relativePath: 'android-lib',
              ),
            ],
          ),
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

class _FakeGitProjectDiscovery extends GitProjectDiscovery {
  const _FakeGitProjectDiscovery(this.projects);

  final List<DiscoveredGitProject> projects;

  @override
  Future<List<DiscoveredGitProject>> discover(String workspaceRoot) async {
    return projects;
  }
}

class _FastFailRunner implements MixbuildCommandRunner {
  const _FastFailRunner();

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
      exitCode: 1,
      stdout: '',
      stderr: 'disabled in test',
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
      exitCode: 1,
      stdout: '',
      stderr: 'disabled in test',
    );
  }

  @override
  String? which(String command) => null;
}
