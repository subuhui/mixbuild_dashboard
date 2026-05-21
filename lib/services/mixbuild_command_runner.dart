import 'dart:convert';
import 'dart:io';

import 'package:process_run/process_run.dart';

class CommandRunResult {
  const CommandRunResult({
    required this.command,
    required this.workingDirectory,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final String command;
  final String workingDirectory;
  final int exitCode;
  final String stdout;
  final String stderr;
}

abstract class MixbuildCommandRunner {
  String? which(String command);
  Future<CommandRunResult> run(
    String command, {
    required String workingDirectory,
    Map<String, String>? environment,
  });
  Future<CommandRunResult> runProcess(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    Map<String, String>? environment,
  });
  Future<void> openPath(String path);
  bool killActive([ProcessSignal signal = ProcessSignal.sigkill]);
}

class ProcessRunCommandRunner implements MixbuildCommandRunner {
  Shell? _activeShell;
  Process? _activeProcess;

  @override
  String? which(String command) {
    final resolved = whichSync(command);
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved;
    }
    if (Platform.isMacOS && command == 'git') {
      for (final candidate in const <String>['/opt/homebrew/bin/git', '/usr/bin/git']) {
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
    }
    return null;
  }

  @override
  Future<CommandRunResult> run(
    String command, {
    required String workingDirectory,
    Map<String, String>? environment,
  }) async {
    final shell = Shell(
      workingDirectory: workingDirectory,
      environment: environment,
      throwOnError: false,
      verbose: false,
      commandVerbose: false,
      commentVerbose: false,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    _activeShell = shell;
    try {
      final results = await shell.run(command);
      final lastResult = results.last;
      return CommandRunResult(
        command: command,
        workingDirectory: workingDirectory,
        exitCode: lastResult.exitCode,
        stdout: '${lastResult.stdout ?? ''}',
        stderr: '${lastResult.stderr ?? ''}',
      );
    } finally {
      if (identical(_activeShell, shell)) {
        _activeShell = null;
      }
    }
  }

  @override
  Future<CommandRunResult> runProcess(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    Map<String, String>? environment,
  }) async {
    Process? process;
    try {
      process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: true,
        runInShell: false,
      );
      _activeProcess = process;
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      return CommandRunResult(
        command: _formatCommand(executable, arguments),
        workingDirectory: workingDirectory,
        exitCode: exitCode,
        stdout: stdout,
        stderr: stderr,
      );
    } on ProcessException catch (error) {
      return CommandRunResult(
        command: _formatCommand(executable, arguments),
        workingDirectory: workingDirectory,
        exitCode: -1,
        stdout: '',
        stderr: error.toString(),
      );
    } finally {
      if (identical(_activeProcess, process)) {
        _activeProcess = null;
      }
    }
  }

  @override
  Future<void> openPath(String path) async {
    if (Platform.isMacOS) {
      await run('open "$path"', workingDirectory: Directory.current.path);
      return;
    }
    if (Platform.isLinux) {
      await run('xdg-open "$path"', workingDirectory: Directory.current.path);
      return;
    }
    if (Platform.isWindows) {
      await run('start "" "$path"', workingDirectory: Directory.current.path);
      return;
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  @override
  bool killActive([ProcessSignal signal = ProcessSignal.sigkill]) {
    final shell = _activeShell;
    if (shell != null) {
      final killed = shell.kill(signal);
      _activeShell = null;
      return killed;
    }
    final process = _activeProcess;
    if (process == null) {
      return false;
    }
    final killed = process.kill(signal);
    _activeProcess = null;
    return killed;
  }

  String _formatCommand(String executable, List<String> arguments) {
    return [executable, ...arguments].join(' ');
  }
}
