import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:path/path.dart' as p;

void main() {
  test('resolves custom executable from pub cache bin outside inherited PATH',
      () async {
    final homeDirectory = Platform.environment['HOME'];
    expect(homeDirectory, isNotNull);
    const executableName = 'mixbuild_test_fvm';

    final pubCacheBin = Directory(p.join(homeDirectory!, '.pub-cache', 'bin'));
    await pubCacheBin.create(recursive: true);
    final fvmFile = File(p.join(pubCacheBin.path, executableName));
    final existedBefore = await fvmFile.exists();
    final originalContents =
        existedBefore ? await fvmFile.readAsString() : null;

    addTearDown(() async {
      if (existedBefore) {
        await fvmFile.writeAsString(originalContents!);
      } else if (await fvmFile.exists()) {
        await fvmFile.delete();
      }
    });

    await fvmFile.writeAsString('#!/bin/sh\nexit 0\n');
    await Process.run('chmod', <String>['+x', fvmFile.path]);

    final runner = ProcessRunCommandRunner();

    expect(runner.which(executableName), fvmFile.path);
  });

  test(
      'runProcess injects pub cache bin into PATH lookups for custom executable',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'mixbuild_runner_test_',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final homeDirectory = Platform.environment['HOME'];
    expect(homeDirectory, isNotNull);
    const executableName = 'mixbuild_test_fvm';

    final pubCacheBin = Directory(p.join(homeDirectory!, '.pub-cache', 'bin'));
    await pubCacheBin.create(recursive: true);
    final fvmFile = File(p.join(pubCacheBin.path, executableName));
    final existedBefore = await fvmFile.exists();
    final originalContents =
        existedBefore ? await fvmFile.readAsString() : null;

    addTearDown(() async {
      if (existedBefore) {
        await fvmFile.writeAsString(originalContents!);
      } else if (await fvmFile.exists()) {
        await fvmFile.delete();
      }
    });

    await fvmFile.writeAsString(
      '#!/bin/sh\nprintf "fake-fvm %s\\n" "\$*"\n',
    );
    await Process.run('chmod', <String>['+x', fvmFile.path]);

    final runner = ProcessRunCommandRunner();
    final result = await runner.runProcess(
      executableName,
      const <String>['--version'],
      workingDirectory: tempDirectory.path,
      environment: const <String, String>{'PATH': ''},
    );

    expect(result.exitCode, 0);
    expect(result.stdout, contains('fake-fvm --version'));
  });

  test('run returns promptly after shell exits even if child keeps pipes open',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'mixbuild_runner_hang_test_',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final runner = ProcessRunCommandRunner();
    final stopwatch = Stopwatch()..start();
    final result = await runner.run(
      'sleep 2 & echo done',
      workingDirectory: tempDirectory.path,
    );
    stopwatch.stop();

    expect(result.exitCode, 0);
    expect(result.stdout, contains('done'));
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(milliseconds: 1200)),
    );
  });
}
