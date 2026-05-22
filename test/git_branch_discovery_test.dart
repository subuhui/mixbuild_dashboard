import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/services/git_branch_discovery.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';

void main() {
  test('returns fallback branches and warning when runner throws exception',
      () async {
    final repoRoot =
        await Directory.systemTemp.createTemp('mixbuild_git_branch_test_');
    addTearDown(() async {
      if (await repoRoot.exists()) {
        await repoRoot.delete(recursive: true);
      }
    });
    await Directory('${repoRoot.path}/.git').create(recursive: true);

    final discovery = GitBranchDiscovery(
      runner: _ThrowingCommandRunner(),
    );

    final result = await discovery.discoverBranches(
      repoRoot.path,
      preferredBranch: 'release/custom',
    );

    expect(result.branches,
        <String>['release/custom', 'develop', 'main', 'master']);
    expect(result.warningMessage, isNotNull);
    expect(result.warningMessage, contains('没有访问仓库目录的权限'));
  });

  test('runs git commands via git -C instead of repo working directory',
      () async {
    final repoRoot =
        await Directory.systemTemp.createTemp('mixbuild_git_branch_cmd_test_');
    addTearDown(() async {
      if (await repoRoot.exists()) {
        await repoRoot.delete(recursive: true);
      }
    });
    await Directory('${repoRoot.path}/.git').create(recursive: true);

    final runner = _RecordingCommandRunner();
    final discovery = GitBranchDiscovery(runner: runner);

    final result = await discovery.discoverBranches(repoRoot.path);

    expect(result.branches, contains('main'));
    expect(runner.commands, hasLength(3));
    expect(runner.commands.first.command, contains('git -C '));
    expect(runner.commands.first.command, contains(repoRoot.path));
    expect(runner.commands.first.workingDirectory, Directory.current.path);
  });
}

class _ThrowingCommandRunner implements MixbuildCommandRunner {
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
  }) {
    throw const ProcessException(
      '/opt/homebrew/bin/git',
      <String>['fetch', '--all', '--prune'],
      'Operation not permitted',
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
  }) {
    throw const ProcessException(
      '/opt/homebrew/bin/git',
      <String>['fetch', '--all', '--prune'],
      'Operation not permitted',
    );
  }

  @override
  String? which(String command) => '/opt/homebrew/bin/$command';
}

class _RecordingCommandRunner implements MixbuildCommandRunner {
  final List<CommandRunResult> commands = <CommandRunResult>[];

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
    final result = switch (commands.length) {
      0 => CommandRunResult(
          command: command,
          workingDirectory: workingDirectory,
          exitCode: 0,
          stdout: '',
          stderr: '',
        ),
      1 => CommandRunResult(
          command: command,
          workingDirectory: workingDirectory,
          exitCode: 0,
          stdout: 'main',
          stderr: '',
        ),
      _ => CommandRunResult(
          command: command,
          workingDirectory: workingDirectory,
          exitCode: 0,
          stdout: 'main\norigin/main',
          stderr: '',
        ),
    };
    commands.add(result);
    return result;
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
    final command = [executable, ...arguments].join(' ');
    final result = switch (commands.length) {
      0 => CommandRunResult(
          command: command,
          workingDirectory: workingDirectory,
          exitCode: 0,
          stdout: '',
          stderr: '',
        ),
      1 => CommandRunResult(
          command: command,
          workingDirectory: workingDirectory,
          exitCode: 0,
          stdout: 'main',
          stderr: '',
        ),
      _ => CommandRunResult(
          command: command,
          workingDirectory: workingDirectory,
          exitCode: 0,
          stdout: 'main\norigin/main',
          stderr: '',
        ),
    };
    commands.add(result);
    return result;
  }

  @override
  String? which(String command) => '/opt/homebrew/bin/$command';
}
