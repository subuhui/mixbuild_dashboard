import 'dart:convert';
import 'dart:io';

import 'package:process_run/process_run.dart';

/// 命令执行结果，包含完整 stdout/stderr 文本和退出码。
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

/// 进程执行抽象层，定义 shell 命令和直接进程调用的统一接口。
///
/// 实现类需支持 [which] 工具查找、[killActive] 终止活跃进程。
abstract class MixbuildCommandRunner {
  String? which(String command);
  Future<CommandRunResult> run(
    String command, {
    required String workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onStdout,
    void Function(String line)? onStderr,
  });
  Future<CommandRunResult> runProcess(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onStdout,
    void Function(String line)? onStderr,
  });
  Future<void> openPath(String path);
  bool killActive([ProcessSignal signal = ProcessSignal.sigkill]);
}

/// 基于 `dart:io` Process 的真实进程执行器。
///
/// macOS/Linux 使用 `/bin/zsh -lc` 执行 shell 命令，Windows 使用 `cmd /c`。
/// 支持实时 stdout/stderr 回调和 SIGKILL 终止。
class ProcessRunCommandRunner implements MixbuildCommandRunner {
  Process? _activeProcess;

  @override
  String? which(String command) {
    final resolved = whichSync(command);
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved;
    }
    if (Platform.isMacOS && command == 'git') {
      for (final candidate in const <String>[
        '/opt/homebrew/bin/git',
        '/usr/bin/git'
      ]) {
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
    void Function(String line)? onStdout,
    void Function(String line)? onStderr,
  }) async {
    final shellExecutable = Platform.isWindows ? 'cmd' : '/bin/zsh';
    final shellArguments =
        Platform.isWindows ? <String>['/c', command] : <String>['-lc', command];
    Process? process;
    try {
      process = await Process.start(
        shellExecutable,
        shellArguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: true,
        runInShell: false,
      );
      _activeProcess = process;
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutFuture = _collectStream(
        process.stdout,
        stdoutBuffer,
        onLine: onStdout,
      );
      final stderrFuture = _collectStream(
        process.stderr,
        stderrBuffer,
        onLine: onStderr,
      );
      final exitCode = await process.exitCode;
      await Future.wait(<Future<void>>[stdoutFuture, stderrFuture]);
      return CommandRunResult(
        command: command,
        workingDirectory: workingDirectory,
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
      );
    } on ProcessException catch (error) {
      return CommandRunResult(
        command: command,
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
  Future<CommandRunResult> runProcess(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    Map<String, String>? environment,
    void Function(String line)? onStdout,
    void Function(String line)? onStderr,
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
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutFuture = _collectStream(
        process.stdout,
        stdoutBuffer,
        onLine: onStdout,
      );
      final stderrFuture = _collectStream(
        process.stderr,
        stderrBuffer,
        onLine: onStderr,
      );
      final exitCode = await process.exitCode;
      await Future.wait(<Future<void>>[stdoutFuture, stderrFuture]);
      return CommandRunResult(
        command: _formatCommand(executable, arguments),
        workingDirectory: workingDirectory,
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
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
    final process = _activeProcess;
    if (process == null) {
      return false;
    }
    final killed = process.kill(signal);
    _activeProcess = null;
    return killed;
  }

  Future<void> _collectStream(
    Stream<List<int>> stream,
    StringBuffer buffer, {
    void Function(String line)? onLine,
  }) async {
    await for (final line
        in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      buffer.writeln(line);
      onLine?.call(line);
    }
  }

  String _formatCommand(String executable, List<String> arguments) {
    return [executable, ...arguments].join(' ');
  }
}
