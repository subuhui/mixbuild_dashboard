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

  static final RegExp _commandPlaceholderPattern = RegExp(
    r'\{\{\s*([A-Za-z][A-Za-z0-9_-]*(?:\.[A-Za-z0-9_-]+)+)\s*\}\}|\$\{([A-Za-z][A-Za-z0-9_-]*(?:\.[A-Za-z0-9_-]+)+)\}',
  );

  final MixbuildCommandRunner _runner;

  bool killActive({MixbuildProjectType? projectType, String? workingDirectory}) {
    final killed = _runner.killActive();
    if (projectType == MixbuildProjectType.android && workingDirectory != null) {
      _stopGradleDaemon(workingDirectory);
    }
    return killed;
  }

  void _stopGradleDaemon(String workingDirectory) {
    try {
      final isWindows = Platform.isWindows;
      final gradlewExecutable = isWindows ? 'gradlew.bat' : './gradlew';
      final gradlewFile = File(p.join(workingDirectory, gradlewExecutable));
      final command = gradlewFile.existsSync()
          ? (isWindows ? 'gradlew.bat --stop' : './gradlew --stop')
          : 'gradle --stop';
      _runner.run(command, workingDirectory: workingDirectory).catchError((_) {
        return const CommandRunResult(
          command: '',
          workingDirectory: '',
          exitCode: -1,
          stdout: '',
          stderr: '',
        );
      });
    } catch (_) {
    }
  }

  Future<void> runPipeline({
    required MixbuildConfig config,
    required ProjectBuild project,
    required BuildScenario scenario,
    String? projectBranch,
    String updateDescription = '',
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
      updateDescription: updateDescription,
      dependencyOverrides: dependencyOverrides,
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
      projectBranch: projectBranch == null || projectBranch.trim().isEmpty
          ? scenario.mainBranch.trim().isEmpty
              ? project.branch
              : scenario.mainBranch
          : projectBranch,
      recreateLocalBranches: cleanBeforeBuild,
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
    await _runRestore(
      config: config,
      scenario: scenario,
      dependencyOverrides: dependencyOverrides,
      onLog: onLog,
    );

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
      updateDescription: updateDescription,
      cleanBeforeBuild: cleanBeforeBuild,
      dependencyOverrides: dependencyOverrides,
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
    required String updateDescription,
    required Map<String, String> dependencyOverrides,
    required void Function(LogEntry entry) onLog,
  }) async {
    final rootDirectory = Directory(config.workspace.rootPath);
    if (!rootDirectory.existsSync()) {
      throw MixbuildEngineException(
        'Workspace root does not exist: ${config.workspace.rootPath}',
      );
    }
    final mainProjectPath = config.mainProject.absolutePath(
      config.workspace.rootPath,
    );
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
        final restoreCommand = _resolveCommandTemplate(
          dependency.restoreCommand!,
          config: config,
          scenario: scenario,
          dependency: dependency,
          dependencyOverrides: dependencyOverrides,
        );
        toolNames.add(
          _resolveExecutableName(
            restoreCommand,
            dependency.absolutePath(config.workspace.rootPath),
          ),
        );
      }
    }
    final scenarioCommand = _resolveCommandTemplate(
      scenario.command,
      config: config,
      scenario: scenario,
      updateDescription: updateDescription,
      dependencyOverrides: dependencyOverrides,
    );
    toolNames.add(
      _resolveExecutableName(
        scenarioCommand,
        config.mainProject.absolutePath(config.workspace.rootPath),
      ),
    );

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
            'Required executable not found: $absoluteToolPath',
          );
        }
        continue;
      }
      if (_runner.which(toolName) == null) {
        throw MixbuildEngineException(
          'Required tool `$toolName` was not found in PATH',
        );
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
    required bool recreateLocalBranches,
    required Map<String, String> dependencyOverrides,
    required void Function(LogEntry entry) onLog,
  }) async {
    final mainProjectPath = config.mainProject.absolutePath(
      config.workspace.rootPath,
    );
    await _runGitSync(
      name: config.mainProject.name,
      repoPath: mainProjectPath,
      targetBranch: projectBranch,
      recreateLocalBranch: recreateLocalBranches,
      onLog: onLog,
    );

    for (final dependency in config.dependencies) {
      final targetBranch =
          dependencyOverrides[dependency.name] ?? projectBranch;
      await _runGitSync(
        name: dependency.name,
        repoPath: dependency.absolutePath(config.workspace.rootPath),
        targetBranch: targetBranch,
        recreateLocalBranch: recreateLocalBranches,
        onLog: onLog,
      );
    }
  }

  Future<void> _runRestore({
    required MixbuildConfig config,
    required BuildScenario scenario,
    required Map<String, String> dependencyOverrides,
    required void Function(LogEntry entry) onLog,
  }) async {
    for (final dependency in config.dependencies) {
      final restoreCommand = dependency.restoreCommand;
      if (restoreCommand == null) {
        continue;
      }
      final dependencyPath = dependency.absolutePath(config.workspace.rootPath);
      final resolvedRestoreCommand = _resolveCommandTemplate(
        restoreCommand,
        config: config,
        scenario: scenario,
        dependency: dependency,
        dependencyOverrides: dependencyOverrides,
      );
      onLog(
        _entry(
          level: 'INFO',
          message:
              'Running restore command for ${dependency.name}: $resolvedRestoreCommand',
          accent: MixBuildPalette.warning,
        ),
      );
      final result = await _runner.run(
        resolvedRestoreCommand,
        workingDirectory: dependencyPath,
        onStdout: (line) =>
            _appendLiveProcessLog(line: line, isStdErr: false, onLog: onLog),
        onStderr: (line) =>
            _appendLiveProcessLog(line: line, isStdErr: true, onLog: onLog),
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
    required String updateDescription,
    required bool cleanBeforeBuild,
    required Map<String, String> dependencyOverrides,
    required void Function(LogEntry entry) onLog,
  }) async {
    final workingDirectory = config.mainProject.absolutePath(
      config.workspace.rootPath,
    );
    final resolvedScenarioCommand = _resolveCommandTemplate(
      scenario.command,
      config: config,
      scenario: scenario,
      updateDescription: updateDescription,
      dependencyOverrides: dependencyOverrides,
    );
    final buildCommand =
        cleanBeforeBuild && !resolvedScenarioCommand.contains('--clean')
        ? '$resolvedScenarioCommand --clean'
        : resolvedScenarioCommand;
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
      onStdout: (line) =>
          _appendLiveProcessLog(line: line, isStdErr: false, onLog: onLog),
      onStderr: (line) =>
          _appendLiveProcessLog(line: line, isStdErr: true, onLog: onLog),
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
    final workingDirectory = config.mainProject.absolutePath(
      config.workspace.rootPath,
    );
    if (scenario.autoTag) {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final tagName = '${scenario.tagPrefix}$timestamp';
      final result = await _runner.runProcess(_resolveGitExecutable(), <String>[
        '-C',
        workingDirectory,
        'tag',
        tagName,
      ], workingDirectory: Directory.current.path);
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
  }

  Future<void> _runGitSync({
    required String name,
    required String repoPath,
    required String targetBranch,
    required bool recreateLocalBranch,
    required void Function(LogEntry entry) onLog,
  }) async {
    _cleanStaleIndexLock(repoPath);
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

    final remoteBranchRef = await _findRemoteBranchRef(
      repoPath: repoPath,
      branchName: targetBranch,
    );
    if (remoteBranchRef == null) {
      throw MixbuildEngineException(
        'Git checkout failed for $name: Remote branch origin/$targetBranch not found',
      );
    }
    if (recreateLocalBranch) {
      await _deleteLocalBranchIfPresent(
        name: name,
        repoPath: repoPath,
        branchName: targetBranch,
        onLog: onLog,
      );
    }
    final checkout = await _runner.runProcess(_resolveGitExecutable(), <String>[
      '-C',
      repoPath,
      'checkout',
      '-B',
      targetBranch,
      remoteBranchRef,
    ], workingDirectory: Directory.current.path);
    _appendProcessLog(result: checkout, onLog: onLog);
    if (checkout.exitCode != 0) {
      throw MixbuildEngineException(
        'Git checkout failed for $name: ${checkout.stderr.trim()}',
      );
    }
    final setUpstream = await _runner.runProcess(
      _resolveGitExecutable(),
      <String>[
        '-C',
        repoPath,
        'branch',
        '--set-upstream-to',
        remoteBranchRef,
        targetBranch,
      ],
      workingDirectory: Directory.current.path,
    );
    _appendProcessLog(result: setUpstream, onLog: onLog);
    if (setUpstream.exitCode != 0) {
      throw MixbuildEngineException(
        'Git upstream setup failed for $name: ${setUpstream.stderr.trim()}',
      );
    }
    final pull = await _runner.runProcess(_resolveGitExecutable(), <String>[
      '-C',
      repoPath,
      'pull',
      '--ff-only',
    ], workingDirectory: Directory.current.path);
    _appendProcessLog(result: pull, onLog: onLog);
    if (pull.exitCode != 0) {
      throw MixbuildEngineException(
        'Git pull failed for $name: ${pull.stderr.trim()}',
      );
    }
    onLog(
      _entry(
        level: 'INFO',
        message: '$name aligned to branch $targetBranch',
        accent: MixBuildPalette.tertiary,
      ),
    );
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
      final style = _resolveProcessLogStyle(line, isStdErr: false);
      onLog(_entry(level: style.level, message: line, accent: style.accent));
    }
    final stderrLines = result.stderr
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(6);
    for (final line in stderrLines) {
      final style = _resolveProcessLogStyle(line, isStdErr: true);
      onLog(_entry(level: style.level, message: line, accent: style.accent));
    }
  }

  void _appendLiveProcessLog({
    required String line,
    required bool isStdErr,
    required void Function(LogEntry entry) onLog,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final style = _resolveProcessLogStyle(trimmed, isStdErr: isStdErr);
    onLog(_entry(level: style.level, message: trimmed, accent: style.accent));
  }

  ({String level, Color accent}) _resolveProcessLogStyle(
    String line, {
    required bool isStdErr,
  }) {
    final normalized = line.trimLeft().toUpperCase();
    if (_matchesProcessPrefix(normalized, const <String>['[ERR]', '[ERROR]'])) {
      return (level: 'ERR', accent: MixBuildPalette.error);
    }
    if (_matchesProcessPrefix(normalized, const <String>[
      '[WARN]',
      '[WARNING]',
    ])) {
      return (level: 'WARN', accent: MixBuildPalette.warning);
    }
    if (_matchesProcessPrefix(normalized, const <String>['[INFO]'])) {
      return (level: 'INFO', accent: MixBuildPalette.muted);
    }
    return isStdErr
        ? (level: 'WARN', accent: MixBuildPalette.warning)
        : (level: 'OUT', accent: MixBuildPalette.muted);
  }

  bool _matchesProcessPrefix(String line, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (line.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  String _resolveCommandTemplate(
    String command, {
    required MixbuildConfig config,
    required BuildScenario scenario,
    MixbuildRepoConfig? dependency,
    String? updateDescription,
    Map<String, String> dependencyOverrides = const <String, String>{},
  }) {
    return command.replaceAllMapped(_commandPlaceholderPattern, (match) {
      final fieldPath = match.group(1) ?? match.group(2);
      if (fieldPath == null) {
        return match.group(0)!;
      }
      final value = _commandTemplateValues(
        config: config,
        scenario: scenario,
        dependency: dependency,
        updateDescription: updateDescription,
        dependencyOverrides: dependencyOverrides,
      )[fieldPath];
      if (value == null) {
        throw MixbuildEngineException(
          'Unknown command template field: $fieldPath',
        );
      }
      return value;
    });
  }

  Map<String, String> _commandTemplateValues({
    required MixbuildConfig config,
    required BuildScenario scenario,
    MixbuildRepoConfig? dependency,
    String? updateDescription,
    required Map<String, String> dependencyOverrides,
  }) {
    final effectiveMainBranch = scenario.mainBranch;
    final values = <String, String>{
      'workspace.name': config.workspace.name,
      'workspace.root_path': config.workspace.rootPath,
      'main_project.name': config.mainProject.name,
      'main_project.path': config.mainProject.path,
      'main_project.absolute_path': config.mainProject.absolutePath(
        config.workspace.rootPath,
      ),
      'main_project.type': config.mainProject.type.name,
      'main_project.restore_command': config.mainProject.restoreCommand ?? '',
      'scenario.id': scenario.id,
      'scenario.name': scenario.name,
      'scenario.main_branch': scenario.mainBranch,
      'scenario.output_dir': scenario.outputPath,
      'scenario.auto_tag': scenario.autoTag.toString(),
      'scenario.tag_prefix': scenario.tagPrefix,
      if (updateDescription != null)
        'build.update_description': _shellQuote(updateDescription),
    };
    for (final item in config.dependencies) {
      _addRepoTemplateValues(
        values: values,
        prefix: 'dependencies.${item.name}',
        repo: item,
        workspaceRoot: config.workspace.rootPath,
      );
      values['dependencies.${item.name}.branch'] =
          dependencyOverrides[item.name] ?? effectiveMainBranch;
    }
    if (dependency != null) {
      _addRepoTemplateValues(
        values: values,
        prefix: 'dependency',
        repo: dependency,
        workspaceRoot: config.workspace.rootPath,
      );
      values['dependency.branch'] =
          dependencyOverrides[dependency.name] ?? effectiveMainBranch;
    }
    return values;
  }

  String _shellQuote(String value) {
    if (Platform.isWindows) {
      return '"${value.replaceAll('"', '""').replaceAll('%', '%%')}"';
    }
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  void _addRepoTemplateValues({
    required Map<String, String> values,
    required String prefix,
    required MixbuildRepoConfig repo,
    required String workspaceRoot,
  }) {
    values['$prefix.name'] = repo.name;
    values['$prefix.path'] = repo.path;
    values['$prefix.absolute_path'] = repo.absolutePath(workspaceRoot);
    values['$prefix.type'] = repo.type.name;
    values['$prefix.restore_command'] = repo.restoreCommand ?? '';
  }

  Future<bool> _hasLocalBranch({
    required String repoPath,
    required String branchName,
  }) async {
    final branchCheck = await _runner.runProcess(
      _resolveGitExecutable(),
      <String>[
        '-C',
        repoPath,
        'show-ref',
        '--verify',
        '--quiet',
        'refs/heads/$branchName',
      ],
      workingDirectory: Directory.current.path,
    );
    return branchCheck.exitCode == 0;
  }

  Future<void> _deleteLocalBranchIfPresent({
    required String name,
    required String repoPath,
    required String branchName,
    required void Function(LogEntry entry) onLog,
  }) async {
    if (!await _hasLocalBranch(repoPath: repoPath, branchName: branchName)) {
      return;
    }
    final currentBranch = await _currentBranchName(repoPath: repoPath);
    if (currentBranch == branchName) {
      final detach = await _runner.runProcess(_resolveGitExecutable(), <String>[
        '-C',
        repoPath,
        'checkout',
        '--detach',
      ], workingDirectory: Directory.current.path);
      _appendProcessLog(result: detach, onLog: onLog);
      if (detach.exitCode != 0) {
        throw MixbuildEngineException(
          'Git checkout failed for $name: ${detach.stderr.trim()}',
        );
      }
    }
    final deleteBranch = await _runner.runProcess(
      _resolveGitExecutable(),
      <String>['-C', repoPath, 'branch', '-D', branchName],
      workingDirectory: Directory.current.path,
    );
    _appendProcessLog(result: deleteBranch, onLog: onLog);
    if (deleteBranch.exitCode != 0) {
      throw MixbuildEngineException(
        'Git branch delete failed for $name: ${deleteBranch.stderr.trim()}',
      );
    }
    onLog(
      _entry(
        level: 'INFO',
        message: '$name deleted local branch $branchName before clean sync',
        accent: MixBuildPalette.warning,
      ),
    );
  }

  Future<String?> _currentBranchName({required String repoPath}) async {
    final currentBranch = await _runner.runProcess(
      _resolveGitExecutable(),
      <String>['-C', repoPath, 'symbolic-ref', '--quiet', '--short', 'HEAD'],
      workingDirectory: Directory.current.path,
    );
    if (currentBranch.exitCode != 0) {
      return null;
    }
    final normalized = currentBranch.stdout.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<String?> _findRemoteBranchRef({
    required String repoPath,
    required String branchName,
  }) async {
    final remoteBranches = await _runner.runProcess(
      _resolveGitExecutable(),
      <String>['-C', repoPath, 'branch', '-r', '--list', '*/$branchName'],
      workingDirectory: Directory.current.path,
    );
    if (remoteBranches.exitCode != 0) {
      return null;
    }
    for (final line in remoteBranches.stdout.split('\n')) {
      final remoteRef = line.trim();
      if (remoteRef.isEmpty || remoteRef.endsWith('/HEAD')) {
        continue;
      }
      return remoteRef;
    }
    return null;
  }

  void _ensureDirectory(String path, String label) {
    if (!Directory(path).existsSync()) {
      throw MixbuildEngineException('$label does not exist: $path');
    }
  }

  void _ensureGitRepo(String path, String label) {
    if (!Directory(p.join(path, '.git')).existsSync()) {
      throw MixbuildEngineException(
        '$label is not a valid git repository: $path',
      );
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
    final result = await _runner.runProcess(_resolveGitExecutable(), <String>[
      '-C',
      repoPath,
      ...arguments,
    ], workingDirectory: Directory.current.path);
    if (result.exitCode == 0) {
      return;
    }
    final rawMessage = result.stderr.trim().isEmpty
        ? result.command
        : result.stderr.trim();
    final message = _isPermissionDeniedMessage(rawMessage)
        ? 'The app cannot access the repository directory. Re-select the workspace directory with Browse, then retry.'
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
      '/usr/bin/git',
    ]) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return 'git';
  }

  void _cleanStaleIndexLock(String repoPath) {
    final lockFile = File('$repoPath/.git/index.lock');
    if (!lockFile.existsSync()) {
      return;
    }
    final lastModified = lockFile.lastModifiedSync();
    final elapsed = DateTime.now().difference(lastModified);
    if (elapsed.inSeconds >= 5) {
      try {
        lockFile.deleteSync();
      } catch (_) {}
    }
  }

  bool _isPermissionDeniedMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('operation not permitted') ||
        normalized.contains('permission denied');
  }
}
