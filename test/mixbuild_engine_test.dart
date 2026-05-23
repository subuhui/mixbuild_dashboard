import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:mixbuild_dashboard/services/mixbuild_engine.dart';
import 'package:path/path.dart' as p;

void main() {
  test('classifies tagged stderr warnings as WARN during build output',
      () async {
    final workspaceRoot = await Directory.systemTemp.createTemp(
      'mixbuild-engine-test_',
    );
    addTearDown(() async {
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    });

    final mainProjectDirectory = Directory(p.join(workspaceRoot.path, 'app'));
    await Directory(p.join(mainProjectDirectory.path, '.git')).create(
      recursive: true,
    );

    const warningLine =
        '[WARN] Not checking for version mismatch as --force flag is set.';
    final engine = MixbuildEngine(
      _FakeCommandRunner(
        buildCommand: 'fvm flutter build macos --release',
        buildStderrLine: warningLine,
      ),
    );
    final logs = <LogEntry>[];

    await engine.runPipeline(
      config: MixbuildConfig(
        filePath: p.join(workspaceRoot.path, 'workspace.yaml'),
        workspace: MixbuildWorkspaceConfig(
          name: 'workspace-demo',
          rootPath: workspaceRoot.path,
        ),
        mainProject: const MixbuildRepoConfig(
          name: 'app',
          path: 'app',
          type: MixbuildProjectType.flutter,
          defaultBranch: 'main',
        ),
        dependencies: const <MixbuildRepoConfig>[],
        buildScenarios: const <MixbuildScenarioConfig>[
          MixbuildScenarioConfig(
            id: 'release-build',
            name: 'Release Build',
            mainBranch: 'main',
            command: 'fvm flutter build macos --release',
          ),
        ],
      ),
      project: const ProjectBuild(
        id: 'workspace-demo',
        emoji: '🚀',
        name: 'app',
        description: 'demo',
        branch: 'main',
        scenarios: <BuildScenario>[],
      ),
      scenario: const BuildScenario(
        id: 'release-build',
        name: 'Release Build',
        subtitle: 'demo',
        environment: 'test',
        mainBranch: 'main',
        command: 'fvm flutter build macos --release',
        status: BuildStatus.idle,
        progress: 0,
        logs: <LogEntry>[],
        dependencies: <DependencyBranch>[],
        outputPath: '',
        autoTag: false,
        tagPrefix: '',
      ),
      cleanBeforeBuild: false,
      dependencyOverrides: const <String, String>{},
      onProgress: (_, progress) {},
      onLog: logs.add,
    );

    final warningLog = logs.firstWhere((entry) => entry.message == warningLine);
    expect(warningLog.level, 'WARN');
    expect(warningLog.accent, MixBuildPalette.warning);
  });

  test('tracks remote branch when requested branch exists only on origin',
      () async {
    final workspaceRoot = await Directory.systemTemp.createTemp(
      'mixbuild-engine-branch-test_',
    );
    addTearDown(() async {
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    });

    final mainProjectDirectory = Directory(p.join(workspaceRoot.path, 'app'));
    await Directory(p.join(mainProjectDirectory.path, '.git')).create(
      recursive: true,
    );

    const targetBranch = 'release_26_05V2';
    final runner = _RemoteOnlyBranchRunner(targetBranch: targetBranch);
    final engine = MixbuildEngine(runner);
    final logs = <LogEntry>[];

    await engine.runPipeline(
      config: MixbuildConfig(
        filePath: p.join(workspaceRoot.path, 'workspace.yaml'),
        workspace: MixbuildWorkspaceConfig(
          name: 'workspace-demo',
          rootPath: workspaceRoot.path,
        ),
        mainProject: const MixbuildRepoConfig(
          name: 'app',
          path: 'app',
          type: MixbuildProjectType.flutter,
          defaultBranch: 'master',
        ),
        dependencies: const <MixbuildRepoConfig>[],
        buildScenarios: const <MixbuildScenarioConfig>[
          MixbuildScenarioConfig(
            id: 'release-build',
            name: 'Release Build',
            mainBranch: targetBranch,
            command: 'fvm flutter build macos --release',
          ),
        ],
      ),
      project: const ProjectBuild(
        id: 'workspace-demo',
        emoji: '🚀',
        name: 'app',
        description: 'demo',
        branch: 'master',
        scenarios: <BuildScenario>[],
      ),
      scenario: const BuildScenario(
        id: 'release-build',
        name: 'Release Build',
        subtitle: 'demo',
        environment: 'test',
        mainBranch: targetBranch,
        command: 'fvm flutter build macos --release',
        status: BuildStatus.idle,
        progress: 0,
        logs: <LogEntry>[],
        dependencies: <DependencyBranch>[],
        outputPath: '',
        autoTag: false,
        tagPrefix: '',
      ),
      cleanBeforeBuild: false,
      dependencyOverrides: const <String, String>{},
      onProgress: (_, progress) {},
      onLog: logs.add,
    );

    expect(
      runner.checkoutArguments,
      <String>['checkout', '--track', 'origin/$targetBranch'],
    );
    expect(
      runner.pullArguments,
      <String>['pull', '--ff-only'],
    );
    expect(
      logs.any(
          (entry) => entry.message == 'app aligned to branch $targetBranch'),
      isTrue,
    );
    expect(
      logs.any(
          (entry) => entry.message.contains('missing branch $targetBranch')),
      isFalse,
    );
  });
}

class _FakeCommandRunner implements MixbuildCommandRunner {
  _FakeCommandRunner({
    required this.buildCommand,
    required this.buildStderrLine,
  });

  final String buildCommand;
  final String buildStderrLine;

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
    if (command == buildCommand) {
      onStderr?.call(buildStderrLine);
    }
    return CommandRunResult(
      command: command,
      workingDirectory: workingDirectory,
      exitCode: 0,
      stdout: '',
      stderr: command == buildCommand ? '$buildStderrLine\n' : '',
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

class _RemoteOnlyBranchRunner implements MixbuildCommandRunner {
  _RemoteOnlyBranchRunner({required this.targetBranch});

  final String targetBranch;
  List<String>? checkoutArguments;
  List<String>? pullArguments;

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
    if (arguments.length >= 6 &&
        arguments[2] == 'show-ref' &&
        arguments.last == 'refs/heads/$targetBranch') {
      return CommandRunResult(
        command: [executable, ...arguments].join(' '),
        workingDirectory: workingDirectory,
        exitCode: 1,
        stdout: '',
        stderr: '',
      );
    }
    if (arguments.length >= 6 &&
        arguments[2] == 'branch' &&
        arguments[3] == '-r' &&
        arguments[4] == '--list' &&
        arguments[5] == '*/$targetBranch') {
      return CommandRunResult(
        command: [executable, ...arguments].join(' '),
        workingDirectory: workingDirectory,
        exitCode: 0,
        stdout: '  origin/$targetBranch\n',
        stderr: '',
      );
    }
    if (arguments.length >= 5 &&
        arguments[2] == 'checkout' &&
        arguments[3] == '--track') {
      checkoutArguments = arguments.sublist(2);
      return CommandRunResult(
        command: [executable, ...arguments].join(' '),
        workingDirectory: workingDirectory,
        exitCode: 0,
        stdout:
            "branch '$targetBranch' set up to track 'origin/$targetBranch'.",
        stderr: '',
      );
    }
    if (arguments.length >= 4 &&
        arguments[2] == 'pull' &&
        arguments[3] == '--ff-only') {
      pullArguments = arguments.sublist(2);
      return CommandRunResult(
        command: [executable, ...arguments].join(' '),
        workingDirectory: workingDirectory,
        exitCode: 0,
        stdout: 'Already up to date.',
        stderr: '',
      );
    }
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
