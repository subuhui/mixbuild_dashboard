import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:mixbuild_dashboard/services/mixbuild_engine.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'classifies tagged stderr warnings as WARN during build output',
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
      await Directory(
        p.join(mainProjectDirectory.path, '.git'),
      ).create(recursive: true);

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
          type: MixbuildProjectType.flutter,
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

      final warningLog = logs.firstWhere(
        (entry) => entry.message == warningLine,
      );
      expect(warningLog.level, 'WARN');
      expect(warningLog.accent, MixBuildPalette.warning);
    },
  );

  test('expands config field templates in restore and build commands', () async {
    final workspaceRoot = await Directory.systemTemp.createTemp(
      'mixbuild-engine-template-test_',
    );
    addTearDown(() async {
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    });

    final mainProjectDirectory = Directory(p.join(workspaceRoot.path, 'app'));
    final dependencyDirectory = Directory(
      p.join(workspaceRoot.path, 'shared_ui'),
    );
    await Directory(
      p.join(mainProjectDirectory.path, '.git'),
    ).create(recursive: true);
    await Directory(
      p.join(dependencyDirectory.path, '.git'),
    ).create(recursive: true);

    final runner = _TemplateCommandRunner(
      remoteBranches: const <String>{'release/main', 'feature/shared'},
    );
    final engine = MixbuildEngine(runner);

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
        ),
        dependencies: const <MixbuildRepoConfig>[
          MixbuildRepoConfig(
            name: 'shared_ui',
            path: 'shared_ui',
            type: MixbuildProjectType.flutter,
            restoreCommand:
                r'echo {{dependency.name}} ${workspace.root_path} ${main_project.name} ${dependency.branch}',
          ),
        ],
        buildScenarios: const <MixbuildScenarioConfig>[
          MixbuildScenarioConfig(
            id: 'release-build',
            name: 'Release Build',
            mainBranch: 'release/main',
            command:
                r'echo ${workspace.name} {{main_project.absolute_path}} ${scenario.main_branch} ${dependencies.shared_ui.branch}',
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
        type: MixbuildProjectType.flutter,
      ),
      scenario: BuildScenario(
        id: 'release-build',
        name: 'Release Build',
        subtitle: 'demo',
        environment: 'test',
        mainBranch: 'release/main',
        command:
            r'echo ${workspace.name} {{main_project.absolute_path}} ${scenario.main_branch} ${dependencies.shared_ui.branch}',
        status: BuildStatus.idle,
        progress: 0,
        logs: const <LogEntry>[],
        dependencies: const <DependencyBranch>[],
        outputPath: '',
        autoTag: false,
        tagPrefix: '',
      ),
      cleanBeforeBuild: false,
      dependencyOverrides: const <String, String>{
        'shared_ui': 'feature/shared',
      },
      onProgress: (_, progress) {},
      onLog: (_) {},
    );

    expect(
      runner.shellCommands,
      contains('echo shared_ui ${workspaceRoot.path} app feature/shared'),
    );
    expect(
      runner.shellCommands,
      contains(
        'echo workspace-demo ${p.join(workspaceRoot.path, 'app')} release/main feature/shared',
      ),
    );
  });

  test(
    'throws when command template references an unknown config field',
    () async {
      final workspaceRoot = await Directory.systemTemp.createTemp(
        'mixbuild-engine-template-error-test_',
      );
      addTearDown(() async {
        if (await workspaceRoot.exists()) {
          await workspaceRoot.delete(recursive: true);
        }
      });

      final mainProjectDirectory = Directory(p.join(workspaceRoot.path, 'app'));
      await Directory(
        p.join(mainProjectDirectory.path, '.git'),
      ).create(recursive: true);

      final engine = MixbuildEngine(
        _FakeCommandRunner(
          buildCommand: r'echo ${workspace.missing}',
          buildStderrLine: '',
        ),
      );

      await expectLater(
        () => engine.runPipeline(
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
            ),
            dependencies: const <MixbuildRepoConfig>[],
            buildScenarios: const <MixbuildScenarioConfig>[
              MixbuildScenarioConfig(
                id: 'release-build',
                name: 'Release Build',
                mainBranch: 'main',
                command: r'echo ${workspace.missing}',
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
            type: MixbuildProjectType.flutter,
          ),
          scenario: const BuildScenario(
            id: 'release-build',
            name: 'Release Build',
            subtitle: 'demo',
            environment: 'test',
            mainBranch: 'main',
            command: r'echo ${workspace.missing}',
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
          onLog: (_) {},
        ),
        throwsA(
          isA<MixbuildEngineException>().having(
            (error) => error.message,
            'message',
            'Unknown command template field: workspace.missing',
          ),
        ),
      );
    },
  );

  test(
    'tracks remote branch when requested branch exists only on origin',
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
      await Directory(
        p.join(mainProjectDirectory.path, '.git'),
      ).create(recursive: true);

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
          type: MixbuildProjectType.flutter,
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

      expect(runner.checkoutArguments, <String>[
        'checkout',
        '-B',
        targetBranch,
        'origin/$targetBranch',
      ]);
      expect(runner.setUpstreamArguments, <String>[
        'branch',
        '--set-upstream-to',
        'origin/$targetBranch',
        targetBranch,
      ]);
      expect(runner.pullArguments, <String>['pull', '--ff-only']);
      expect(
        logs.any(
          (entry) => entry.message == 'app aligned to branch $targetBranch',
        ),
        isTrue,
      );
      expect(
        logs.any(
          (entry) => entry.message.contains('missing branch $targetBranch'),
        ),
        isFalse,
      );
    },
  );

  test(
    'prefers remote branch even when a local branch with the same name exists',
    () async {
      final workspaceRoot = await Directory.systemTemp.createTemp(
        'mixbuild-engine-remote-first-test_',
      );
      addTearDown(() async {
        if (await workspaceRoot.exists()) {
          await workspaceRoot.delete(recursive: true);
        }
      });

      final mainProjectDirectory = Directory(p.join(workspaceRoot.path, 'app'));
      await Directory(
        p.join(mainProjectDirectory.path, '.git'),
      ).create(recursive: true);

      const targetBranch = 'release_26_05V2';
      final runner = _BranchSyncRunner(
        branches: <String, _BranchAvailability>{
          targetBranch: const _BranchAvailability(
            localExists: true,
            remoteExists: true,
          ),
        },
        currentBranch: 'master',
      );
      final engine = MixbuildEngine(runner);

      await _runBranchPipeline(
        engine: engine,
        workspaceRoot: workspaceRoot.path,
        targetBranch: targetBranch,
        cleanBeforeBuild: false,
      );

      expect(runner.checkoutArguments, <String>[
        'checkout',
        '-B',
        targetBranch,
        'origin/$targetBranch',
      ]);
      expect(runner.setUpstreamArguments, <String>[
        'branch',
        '--set-upstream-to',
        'origin/$targetBranch',
        targetBranch,
      ]);
    },
  );

  test(
    'throws when requested remote branch is missing instead of falling back',
    () async {
      final workspaceRoot = await Directory.systemTemp.createTemp(
        'mixbuild-engine-no-fallback-test_',
      );
      addTearDown(() async {
        if (await workspaceRoot.exists()) {
          await workspaceRoot.delete(recursive: true);
        }
      });

      final mainProjectDirectory = Directory(p.join(workspaceRoot.path, 'app'));
      await Directory(
        p.join(mainProjectDirectory.path, '.git'),
      ).create(recursive: true);

      const targetBranch = 'release_26_05V2';
      final runner = _BranchSyncRunner(
        branches: const <String, _BranchAvailability>{
          targetBranch: _BranchAvailability(
            localExists: false,
            remoteExists: false,
          ),
          'master': _BranchAvailability(localExists: true, remoteExists: true),
        },
        currentBranch: 'master',
      );
      final engine = MixbuildEngine(runner);

      await expectLater(
        () => _runBranchPipeline(
          engine: engine,
          workspaceRoot: workspaceRoot.path,
          targetBranch: targetBranch,
          cleanBeforeBuild: false,
        ),
        throwsA(
          isA<MixbuildEngineException>().having(
            (error) => error.message,
            'message',
            contains('Remote branch origin/$targetBranch not found'),
          ),
        ),
      );
    },
  );

  test(
    'deletes local branch before remote checkout when cleanBeforeBuild is enabled',
    () async {
      final workspaceRoot = await Directory.systemTemp.createTemp(
        'mixbuild-engine-clean-branch-test_',
      );
      addTearDown(() async {
        if (await workspaceRoot.exists()) {
          await workspaceRoot.delete(recursive: true);
        }
      });

      final mainProjectDirectory = Directory(p.join(workspaceRoot.path, 'app'));
      await Directory(
        p.join(mainProjectDirectory.path, '.git'),
      ).create(recursive: true);

      const targetBranch = 'release_26_05V2';
      final runner = _BranchSyncRunner(
        branches: <String, _BranchAvailability>{
          targetBranch: const _BranchAvailability(
            localExists: true,
            remoteExists: true,
          ),
        },
        currentBranch: targetBranch,
      );
      final engine = MixbuildEngine(runner);

      await _runBranchPipeline(
        engine: engine,
        workspaceRoot: workspaceRoot.path,
        targetBranch: targetBranch,
        cleanBeforeBuild: true,
      );

      expect(runner.didDetachHeadBeforeDelete, isTrue);
      expect(runner.deletedBranches, <String>[targetBranch]);
      expect(runner.checkoutArguments, <String>[
        'checkout',
        '-B',
        targetBranch,
        'origin/$targetBranch',
      ]);
    },
  );
}

Future<void> _runBranchPipeline({
  required MixbuildEngine engine,
  required String workspaceRoot,
  required String targetBranch,
  required bool cleanBeforeBuild,
}) {
  return engine.runPipeline(
    config: MixbuildConfig(
      filePath: p.join(workspaceRoot, 'workspace.yaml'),
      workspace: MixbuildWorkspaceConfig(
        name: 'workspace-demo',
        rootPath: workspaceRoot,
      ),
      mainProject: const MixbuildRepoConfig(
        name: 'app',
        path: 'app',
        type: MixbuildProjectType.flutter,
      ),
      dependencies: const <MixbuildRepoConfig>[],
      buildScenarios: <MixbuildScenarioConfig>[
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
      type: MixbuildProjectType.flutter,
    ),
    scenario: BuildScenario(
      id: 'release-build',
      name: 'Release Build',
      subtitle: 'demo',
      environment: 'test',
      mainBranch: targetBranch,
      command: 'fvm flutter build macos --release',
      status: BuildStatus.idle,
      progress: 0,
      logs: const <LogEntry>[],
      dependencies: const <DependencyBranch>[],
      outputPath: '',
      autoTag: false,
      tagPrefix: '',
    ),
    cleanBeforeBuild: cleanBeforeBuild,
    dependencyOverrides: const <String, String>{},
    onProgress: (_, progress) {},
    onLog: (_) {},
  );
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
    if (arguments.length >= 6 &&
        arguments[2] == 'branch' &&
        arguments[3] == '-r' &&
        arguments[4] == '--list') {
      final branchName = arguments[5].replaceFirst('*/', '');
      return CommandRunResult(
        command: [executable, ...arguments].join(' '),
        workingDirectory: workingDirectory,
        exitCode: 0,
        stdout: '  origin/$branchName\n',
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

class _TemplateCommandRunner implements MixbuildCommandRunner {
  _TemplateCommandRunner({required Set<String> remoteBranches})
    : _remoteBranches = Set<String>.from(remoteBranches);

  final Set<String> _remoteBranches;
  final List<String> shellCommands = <String>[];

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
    shellCommands.add(command);
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
        arguments[2] == 'branch' &&
        arguments[3] == '-r' &&
        arguments[4] == '--list') {
      final branchName = arguments[5].replaceFirst('*/', '');
      return CommandRunResult(
        command: [executable, ...arguments].join(' '),
        workingDirectory: workingDirectory,
        exitCode: 0,
        stdout: _remoteBranches.contains(branchName)
            ? '  origin/$branchName\n'
            : '',
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

class _RemoteOnlyBranchRunner implements MixbuildCommandRunner {
  _RemoteOnlyBranchRunner({required this.targetBranch});

  final String targetBranch;
  List<String>? checkoutArguments;
  List<String>? setUpstreamArguments;
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
    if (arguments.length >= 6 &&
        arguments[2] == 'checkout' &&
        arguments[3] == '-B') {
      checkoutArguments = arguments.sublist(2);
      return CommandRunResult(
        command: [executable, ...arguments].join(' '),
        workingDirectory: workingDirectory,
        exitCode: 0,
        stdout: "Reset branch '$targetBranch'",
        stderr: '',
      );
    }
    if (arguments.length >= 6 &&
        arguments[2] == 'branch' &&
        arguments[3] == '--set-upstream-to') {
      setUpstreamArguments = arguments.sublist(2);
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

class _BranchSyncRunner implements MixbuildCommandRunner {
  _BranchSyncRunner({
    required Map<String, _BranchAvailability> branches,
    required this.currentBranch,
  }) : _branches = Map<String, _BranchAvailability>.from(branches);

  final Map<String, _BranchAvailability> _branches;
  String? currentBranch;
  List<String>? checkoutArguments;
  List<String>? setUpstreamArguments;
  final List<String> deletedBranches = <String>[];
  bool didDetachHeadBeforeDelete = false;

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
        arguments.last.startsWith('refs/heads/')) {
      final branchName = arguments.last.replaceFirst('refs/heads/', '');
      final exists = _branches[branchName]?.localExists ?? false;
      return _result(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        exitCode: exists ? 0 : 1,
      );
    }
    if (arguments.length >= 6 &&
        arguments[2] == 'branch' &&
        arguments[3] == '-r' &&
        arguments[4] == '--list') {
      final branchName = arguments[5].replaceFirst('*/', '');
      final exists = _branches[branchName]?.remoteExists ?? false;
      return _result(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        stdout: exists ? '  origin/$branchName\n' : '',
      );
    }
    if (arguments.length >= 6 &&
        arguments[2] == 'symbolic-ref' &&
        arguments[3] == '--quiet' &&
        arguments[4] == '--short' &&
        arguments[5] == 'HEAD') {
      return _result(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        exitCode: currentBranch == null ? 1 : 0,
        stdout: currentBranch == null ? '' : '$currentBranch\n',
      );
    }
    if (arguments.length >= 4 &&
        arguments[2] == 'checkout' &&
        arguments[3] == '--detach') {
      didDetachHeadBeforeDelete = true;
      currentBranch = null;
      return _result(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
      );
    }
    if (arguments.length >= 5 &&
        arguments[2] == 'branch' &&
        arguments[3] == '-D') {
      final branchName = arguments[4];
      deletedBranches.add(branchName);
      final current = _branches[branchName] ?? const _BranchAvailability();
      _branches[branchName] = current.copyWith(localExists: false);
      return _result(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
      );
    }
    if (arguments.length >= 6 &&
        arguments[2] == 'checkout' &&
        arguments[3] == '-B') {
      final branchName = arguments[4];
      checkoutArguments = arguments.sublist(2);
      currentBranch = branchName;
      final current = _branches[branchName] ?? const _BranchAvailability();
      _branches[branchName] = current.copyWith(localExists: true);
      return _result(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
      );
    }
    if (arguments.length >= 6 &&
        arguments[2] == 'branch' &&
        arguments[3] == '--set-upstream-to') {
      setUpstreamArguments = arguments.sublist(2);
      return _result(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
      );
    }
    if (arguments.length >= 4 &&
        arguments[2] == 'pull' &&
        arguments[3] == '--ff-only') {
      return _result(
        executable: executable,
        arguments: arguments,
        workingDirectory: workingDirectory,
        stdout: 'Already up to date.',
      );
    }
    return _result(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
    );
  }

  CommandRunResult _result({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
  }) {
    return CommandRunResult(
      command: [executable, ...arguments].join(' '),
      workingDirectory: workingDirectory,
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
    );
  }

  @override
  String? which(String command) => '/mock/bin/$command';
}

class _BranchAvailability {
  const _BranchAvailability({
    this.localExists = false,
    this.remoteExists = false,
  });

  final bool localExists;
  final bool remoteExists;

  _BranchAvailability copyWith({bool? localExists, bool? remoteExists}) {
    return _BranchAvailability(
      localExists: localExists ?? this.localExists,
      remoteExists: remoteExists ?? this.remoteExists,
    );
  }
}
