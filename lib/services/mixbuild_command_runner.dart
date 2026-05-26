import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
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
  static const Duration _streamCloseGracePeriod = Duration(milliseconds: 150);
  static const List<String> _macOsFallbackBins = <String>[
    '/opt/homebrew/bin',
    '/usr/local/bin',
    '/usr/bin',
    '/bin',
    '/usr/sbin',
    '/sbin',
  ];

  Process? _activeProcess;

  @override
  String? which(String command) {
    final resolved = whichSync(command);
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved;
    }
    return _findExecutableInKnownPaths(command);
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
        environment: _mergeEnvironment(environment),
        includeParentEnvironment: true,
        runInShell: false,
      );
      _activeProcess = process;
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutSubscription = _listenToStream(
        process.stdout,
        stdoutBuffer,
        onLine: onStdout,
      );
      final stderrSubscription = _listenToStream(
        process.stderr,
        stderrBuffer,
        onLine: onStderr,
      );
      final exitCode = await process.exitCode;
      await Future.wait(<Future<void>>[
        _closeStreamSubscription(stdoutSubscription),
        _closeStreamSubscription(stderrSubscription),
      ]);
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
        environment: _mergeEnvironment(environment),
        includeParentEnvironment: true,
        runInShell: false,
      );
      _activeProcess = process;
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutSubscription = _listenToStream(
        process.stdout,
        stdoutBuffer,
        onLine: onStdout,
      );
      final stderrSubscription = _listenToStream(
        process.stderr,
        stderrBuffer,
        onLine: onStderr,
      );
      final exitCode = await process.exitCode;
      await Future.wait(<Future<void>>[
        _closeStreamSubscription(stdoutSubscription),
        _closeStreamSubscription(stderrSubscription),
      ]);
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
    final killed = _killProcessTree(process.pid, signal);
    _activeProcess = null;
    return killed;
  }

  _StreamCollection _listenToStream(
    Stream<List<int>> stream,
    StringBuffer buffer, {
    void Function(String line)? onLine,
  }) {
    final done = Completer<void>();
    final subscription =
        stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        buffer.writeln(line);
        onLine?.call(line);
      },
      onDone: () {
        if (!done.isCompleted) {
          done.complete();
        }
      },
      onError: (_) {
        if (!done.isCompleted) {
          done.complete();
        }
      },
      cancelOnError: false,
    );
    return _StreamCollection(subscription: subscription, done: done.future);
  }

  Future<void> _closeStreamSubscription(_StreamCollection stream) async {
    try {
      await stream.done.timeout(_streamCloseGracePeriod);
    } on TimeoutException {
      await stream.subscription.cancel();
    }
  }

  bool _killProcessTree(int pid, ProcessSignal signal) {
    var killedAny = false;
    for (final childPid in _childProcessIds(pid)) {
      if (_killProcessTree(childPid, signal)) {
        killedAny = true;
      }
    }
    return Process.killPid(pid, signal) || killedAny;
  }

  List<int> _childProcessIds(int pid) {
    if (Platform.isWindows) {
      return const <int>[];
    }
    final pgrepExecutable =
        _findExecutableInKnownPaths('pgrep') ?? whichSync('pgrep');
    if (pgrepExecutable == null || pgrepExecutable.trim().isEmpty) {
      return const <int>[];
    }
    try {
      final result = Process.runSync(
        pgrepExecutable,
        <String>['-P', '$pid'],
        runInShell: false,
      );
      if (result.exitCode != 0) {
        return const <int>[];
      }
      return result.stdout
          .toString()
          .split('\n')
          .map((line) => int.tryParse(line.trim()))
          .whereType<int>()
          .toList(growable: false);
    } catch (_) {
      return const <int>[];
    }
  }

  String _formatCommand(String executable, List<String> arguments) {
    return [executable, ...arguments].join(' ');
  }

  String? _findExecutableInKnownPaths(String command) {
    for (final directory in _knownPathEntries()) {
      final candidate = p.join(directory, command);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  Map<String, String> _mergeEnvironment(Map<String, String>? environment) {
    final merged = <String, String>{...?environment};
    final separator = Platform.isWindows ? ';' : ':';
    final existingPath = merged['PATH'] ?? Platform.environment['PATH'] ?? '';
    final pathEntries = LinkedHashSet<String>.from(
      <String>[
        ...existingPath.split(separator),
        ..._knownPathEntries(),
      ].where((entry) => entry.trim().isNotEmpty),
    );
    merged['PATH'] = pathEntries.join(separator);
    return merged;
  }

  List<String> _knownPathEntries() {
    final separator = Platform.isWindows ? ';' : ':';
    final pathEntries = LinkedHashSet<String>.from(
      (Platform.environment['PATH'] ?? '')
          .split(separator)
          .where((entry) => entry.trim().isNotEmpty),
    );
    final homeDirectory = Platform.environment['HOME'];
    if (homeDirectory != null && homeDirectory.trim().isNotEmpty) {
      pathEntries.add(p.join(homeDirectory, '.pub-cache', 'bin'));
    }
    if (Platform.isMacOS) {
      pathEntries.addAll(_macOsFallbackBins);
    }
    return pathEntries.toList(growable: false);
  }
}

class _StreamCollection {
  const _StreamCollection({
    required this.subscription,
    required this.done,
  });

  final StreamSubscription<String> subscription;
  final Future<void> done;
}
