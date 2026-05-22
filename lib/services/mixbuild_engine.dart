import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart' show stringToArguments;
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';

class MixbuildEngineException implements Exception {
  const MixbuildEngineException(this.message, {this.level = 'ERROR'});

  final String message;
  final String level;

  @override
  String toString() => message;
}

class MixbuildEngine {
  MixbuildEngine(this._runner);

  final MixbuildCommandRunner _runner;

  bool killActive() => _runner.killActive();

  Future<void> runPipeline({
    required MixbuildConfig config,
    required ProjectBuild project,
    required BuildScenario scenario,
    required bool cleanBeforeBuild,
    required Map<String, String> dependencyOverrides,
    required void Function(BuildStatus status, double progress) onProgress,
    required void Function(LogEntry entry) onLog,
  }) async {
    await _transition(
      status: BuildStatus.validating,
      progress: 0.08,
      message: 'Pre-flight check started for ${project.name}',
      accent: MixBuildPalette.warning,
      onLog: onLog,
      onProgress: onProgress,
    );
    await _runPreflight(
      config: config,
      scenario: scenario,
      onLog: onLog,
    );

    await _transition(
      status: BuildStatus.syncing,
      progress: 0.24,
      message: 'Workspace is clean. Entering SYNCING phase.',
      accent: MixBuildPalette.tertiary,
      onLog: onLog,
      onProgress: onProgress,
    );
    await _runSync(
      config: config,
      projectBranch: scenario.mainBranch.trim().isEmpty
          ? project.branch
          : scenario.mainBranch,
      dependencyOverrides: dependencyOverrides,
      onLog: onLog,
    );

    await _transition(
      status: BuildStatus.restoring,
      progress: 0.52,
      message: 'Git sync completed. Restore queue is now running serially.',
      accent: MixBuildPalette.warning,
      onLog: onLog,
      onProgress: onProgress,
    );
    await _runRestore(config: config, onLog: onLog);

    await _transition(
      status: BuildStatus.building,
      progress: 0.78,
      message: 'Restore phase completed. Triggering build command.',
      accent: MixBuildPalette.primary,
      onLog: onLog,
      onProgress: onProgress,
    );
    await _runBuild(
      config: config,
      scenario: scenario,
      cleanBeforeBuild: cleanBeforeBuild,
      onLog: onLog,
    );

    await _transition(
      status: BuildStatus.postHook,
      progress: 0.92,
      message: 'Build exited with code 0. Running post-build hooks.',
      accent: MixBuildPalette.success,
      onLog: onLog,
      onProgress: onProgress,
    );
    await _runPostHooks(config: config, scenario: scenario, onLog: onLog);

    onProgress(BuildStatus.success, 1.0);
    onLog(
      _entry(
        level: 'INFO',
        message: 'Pipeline completed successfully.',
        accent: MixBuildPalette.success,
      ),
    );
  }

  Future<void> _runPreflight({
    required MixbuildConfig config,
    required BuildScenario scenario,
    required void Function(LogEntry entry) onLog,
  }) async {
    final rootDirectory = Directory(config.workspace.rootPath);
    if (!rootDirectory.existsSync()) {
      throw MixbuildEngineException(
        'Workspace root does not exist: ${config.workspace.rootPath}',
      );
    }
    final mainProjectPath =
        config.mainProject.absolutePath(config.workspace.rootPath);
    _ensureDirectory(mainProjectPath, 'main_project.path');
    _ensureGitRepo(mainProjectPath, 'main_project.path');

    for (final dependency in config.dependencies) {
      final dependencyPath = dependency.absolutePath(config.workspace.rootPath);
      _ensureDirectory(dependencyPath, 'dependency ${dependency.name} path');
      _ensureGitRepo(dependencyPath, 'dependency ${dependency.name} path');
    }

    final toolNames = <String>{'git'};
    for (final dependency in config.dependencies) {
      if (dependency.restoreCommand != null) {
        toolNames.add(_resolveExecutableName(
          dependency.restoreCommand!,
          dependency.absolutePath(config.workspace.rootPath),
        ));
      }
    }
    toolNames.add(_resolveExecutableName(
      scenario.command,
      config.mainProject.absolutePath(config.workspace.rootPath),
    ));

    for (final toolName in toolNames) {
      if (toolName.contains(Platform.pathSeparator) ||
          toolName.startsWith('.')) {
        final absoluteToolPath = p.isAbsolute(toolName)
            ? toolName
            : p.normalize(
                p.join(
                  config.mainProject.absolutePath(config.workspace.rootPath),
                  toolName,
                ),
              );
        if (!File(absoluteToolPath).existsSync()) {
          throw MixbuildEngineException(
              'Required executable not found: $absoluteToolPath');
        }
        continue;
      }
      if (_runner.which(toolName) == null) {
        throw MixbuildEngineException(
            'Required tool `$toolName` was not found in PATH');
      }
      onLog(
        _entry(
          level: 'INFO',
          message: 'Validated host tool in PATH: $toolName',
          accent: MixBuildPalette.warning,
        ),
      );
    }
  }

  Future<void> _runSync({
    required MixbuildConfig config,
    required String projectBranch,
    required Map<String, String> dependencyOverrides,
    required void Function(LogEntry entry) onLog,
  }) async {
    final mainProjectPath =
        config.mainProject.absolutePath(config.workspace.rootPath);
    await _runGitSync(
      name: config.mainProject.name,
      repoPath: mainProjectPath,
      targetBranch: projectBranch,
      fallbackBranch: config.mainProject.defaultBranch,
      onLog: onLog,
    );

    for (final dependency in config.dependencies) {
      final targetBranch =
          dependencyOverrides[dependency.name] ?? projectBranch;
      await _runGitSync(
        name: dependency.name,
        repoPath: dependency.absolutePath(config.workspace.rootPath),
        targetBranch: targetBranch,
        fallbackBranch: dependency.defaultBranch,
        onLog: onLog,
      );
    }
  }

  Future<void> _runRestore({
    required MixbuildConfig config,
    required void Function(LogEntry entry) onLog,
  }) async {
    for (final dependency in config.dependencies) {
      final restoreCommand = dependency.restoreCommand;
      if (restoreCommand == null) {
        continue;
      }
      final dependencyPath = dependency.absolutePath(config.workspace.rootPath);
      onLog(
        _entry(
          level: 'INFO',
          message:
              'Running restore command for ${dependency.name}: $restoreCommand',
          accent: MixBuildPalette.warning,
        ),
      );
      final result = await _runner.run(
        restoreCommand,
        workingDirectory: dependencyPath,
        onStdout: (line) => _appendLiveProcessLog(
          line: line,
          level: 'OUT',
          accent: MixBuildPalette.muted,
          onLog: onLog,
        ),
        onStderr: (line) => _appendLiveProcessLog(
          line: line,
          level: 'ERR',
          accent: MixBuildPalette.warning,
          onLog: onLog,
        ),
      );
      if (result.exitCode != 0) {
        throw MixbuildEngineException(
          'restore_command failed for ${dependency.name} with exit code ${result.exitCode}',
        );
      }
    }
  }

  Future<void> _runBuild({
    required MixbuildConfig config,
    required BuildScenario scenario,
    required bool cleanBeforeBuild,
    required void Function(LogEntry entry) onLog,
  }) async {
    final workingDirectory =
        config.mainProject.absolutePath(config.workspace.rootPath);
    final buildCommand =
        cleanBeforeBuild && !scenario.command.contains('--clean')
            ? '${scenario.command} --clean'
            : scenario.command;
    onLog(
      _entry(
        level: 'INFO',
        message: 'Running build command: $buildCommand',
        accent: MixBuildPalette.primary,
      ),
    );
    final result = await _runner.run(
      buildCommand,
      workingDirectory: workingDirectory,
      onStdout: (line) => _appendLiveProcessLog(
        line: line,
        level: 'OUT',
        accent: MixBuildPalette.muted,
        onLog: onLog,
      ),
      onStderr: (line) => _appendLiveProcessLog(
        line: line,
        level: 'ERR',
        accent: MixBuildPalette.warning,
        onLog: onLog,
      ),
    );
    if (result.exitCode != 0) {
      throw MixbuildEngineException(
        'Build command failed with exit code ${result.exitCode}',
      );
    }
  }

  Future<void> _runPostHooks({
    required MixbuildConfig config,
    required BuildScenario scenario,
    required void Function(LogEntry entry) onLog,
  }) async {
    final workingDirectory =
        config.mainProject.absolutePath(config.workspace.rootPath);
    if (scenario.autoTag) {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final tagName = '${scenario.tagPrefix}$timestamp';
      final result = await _runner.runProcess(
        _resolveGitExecutable(),
        <String>['-C', workingDirectory, 'tag', tagName],
        workingDirectory: Directory.current.path,
      );
      if (result.exitCode == 0) {
        onLog(
          _entry(
            level: 'INFO',
            message: 'Created git tag: $tagName',
            accent: MixBuildPalette.success,
          ),
        );
      } else {
        onLog(
          _entry(
            level: 'WARN',
            message:
                'Auto tag failed but will not block success: ${result.stderr.trim()}',
            accent: MixBuildPalette.warning,
          ),
        );
      }
    }

    if (scenario.outputPath.isNotEmpty) {
      final outputDirectory = p.normalize(
        p.join(config.workspace.rootPath, scenario.outputPath),
      );
      if (Directory(outputDirectory).existsSync()) {
        await _runner.openPath(outputDirectory);
        onLog(
          _entry(
            level: 'INFO',
            message: 'Opened output directory: $outputDirectory',
            accent: MixBuildPalette.success,
          ),
        );
      }
    }

    if (Platform.isMacOS) {
      await _runner.run(
        "osascript -e 'display notification \"Build finished\" with title \"MixBuild Dashboard\"'",
        workingDirectory: workingDirectory,
      );
      onLog(
        _entry(
          level: 'INFO',
          message: 'macOS notification dispatched.',
          accent: MixBuildPalette.success,
        ),
      );
    }
  }

  Future<void> _runGitSync({
    required String name,
    required String repoPath,
    required String targetBranch,
    required String fallbackBranch,
    required void Function(LogEntry entry) onLog,
  }) async {
    await _runGitCommandOrThrow(
      repoPath: repoPath,
      arguments: const <String>['fetch', '--all', '--prune'],
      errorPrefix: 'Git fetch failed for $name',
    );
    await _runGitCommandOrThrow(
      repoPath: repoPath,
      arguments: const <String>['reset', '--hard'],
      errorPrefix: 'Git reset failed for $name',
    );
    await _runGitCommandOrThrow(
      repoPath: repoPath,
      arguments: const <String>['clean', '-fd'],
      errorPrefix: 'Git clean failed for $name',
    );

    final branchToUse = await _resolveBranch(
      repoPath: repoPath,
      requestedBranch: targetBranch,
      fallbackBranch: fallbackBranch,
    );
    final checkout = await _runner.runProcess(
      _resolveGitExecutable(),
      <String>['-C', repoPath, 'checkout', branchToUse],
      workingDirectory: Directory.current.path,
    );
    _appendProcessLog(result: checkout, onLog: onLog);
    if (checkout.exitCode != 0) {
      throw MixbuildEngineException(
          'Git checkout failed for $name: ${checkout.stderr.trim()}');
    }
    if (branchToUse != targetBranch) {
      onLog(
        _entry(
          level: 'WARN',
          message:
              '$name missing branch $targetBranch, fallback to default_branch=$fallbackBranch',
          accent: MixBuildPalette.warning,
        ),
      );
      return;
    }
    onLog(
      _entry(
        level: 'INFO',
        message: '$name aligned to branch $branchToUse',
        accent: MixBuildPalette.tertiary,
      ),
    );
  }

  Future<String> _resolveBranch({
    required String repoPath,
    required String requestedBranch,
    required String fallbackBranch,
  }) async {
    final branchCheck = await _runner.runProcess(
      _resolveGitExecutable(),
      <String>[
        '-C',
        repoPath,
        'show-ref',
        '--verify',
        '--quiet',
        'refs/heads/$requestedBranch'
      ],
      workingDirectory: Directory.current.path,
    );
    if (branchCheck.exitCode == 0) {
      return requestedBranch;
    }
    return fallbackBranch;
  }

  Future<void> _transition({
    required BuildStatus status,
    required double progress,
    required String message,
    required Color accent,
    required void Function(LogEntry entry) onLog,
    required void Function(BuildStatus status, double progress) onProgress,
  }) async {
    onProgress(status, progress);
    onLog(_entry(level: 'INFO', message: message, accent: accent));
  }

  LogEntry _entry({
    required String level,
    required String message,
    required Color accent,
  }) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return LogEntry(
      time: '$hh:$mm:$ss',
      level: level,
      message: message,
      accent: accent,
    );
  }

  void _appendProcessLog({
    required CommandRunResult result,
    required void Function(LogEntry entry) onLog,
  }) {
    final stdoutLines = result.stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(6);
    for (final line in stdoutLines) {
      onLog(
          _entry(level: 'INFO', message: line, accent: MixBuildPalette.muted));
    }
    final stderrLines = result.stderr
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(6);
    for (final line in stderrLines) {
      onLog(_entry(
          level: 'WARN', message: line, accent: MixBuildPalette.warning));
    }
  }

  void _appendLiveProcessLog({
    required String line,
    required String level,
    required Color accent,
    required void Function(LogEntry entry) onLog,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }
    onLog(_entry(level: level, message: trimmed, accent: accent));
  }

  void _ensureDirectory(String path, String label) {
    if (!Directory(path).existsSync()) {
      throw MixbuildEngineException('$label does not exist: $path');
    }
  }

  void _ensureGitRepo(String path, String label) {
    if (!Directory(p.join(path, '.git')).existsSync()) {
      throw MixbuildEngineException(
          '$label is not a valid git repository: $path');
    }
  }

  String _resolveExecutableName(String command, String workingDirectory) {
    final arguments = stringToArguments(command);
    if (arguments.isEmpty) {
      throw const MixbuildEngineException('Command cannot be empty.');
    }
    final executable = arguments.first;
    if (executable.contains('/') || executable.contains('\\')) {
      return p.isAbsolute(executable)
          ? executable
          : p.normalize(p.join(workingDirectory, executable));
    }
    return executable;
  }

  Future<void> _runGitCommandOrThrow({
    required String repoPath,
    required List<String> arguments,
    required String errorPrefix,
  }) async {
    final result = await _runner.runProcess(
      _resolveGitExecutable(),
      <String>['-C', repoPath, ...arguments],
      workingDirectory: Directory.current.path,
    );
    if (result.exitCode == 0) {
      return;
    }
    final rawMessage =
        result.stderr.trim().isEmpty ? result.command : result.stderr.trim();
    final message = _isPermissionDeniedMessage(rawMessage)
        ? '当前应用没有访问仓库目录的权限。请通过“浏览...”重新选择工作区目录后重试。'
        : rawMessage;
    throw MixbuildEngineException('$errorPrefix: $message');
  }

  String _resolveGitExecutable() {
    final resolved = _runner.which('git');
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved;
    }
    for (final candidate in const <String>[
      '/opt/homebrew/bin/git',
      '/usr/bin/git'
    ]) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return 'git';
  }

  bool _isPermissionDeniedMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('operation not permitted') ||
        normalized.contains('permission denied');
  }
}
