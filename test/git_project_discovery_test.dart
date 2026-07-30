import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/services/git_project_discovery.dart';
import 'package:path/path.dart' as p;

void main() {
  test('discovers git repositories in workspace root and nested directories', () async {
    final workspaceRoot = await Directory.systemTemp.createTemp('mixbuild_workspace_');
    addTearDown(() async {
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    });

    final appRepo = Directory(p.join(workspaceRoot.path, 'LogisticsClient'));
    final moduleRepo = Directory(p.join(workspaceRoot.path, 'modules', 'common_ui'));
    final nonRepo = Directory(p.join(workspaceRoot.path, 'docs'));

    await Directory(p.join(appRepo.path, '.git')).create(recursive: true);
    await Directory(p.join(moduleRepo.path, '.git')).create(recursive: true);
    await nonRepo.create(recursive: true);

    final projects = await const GitProjectDiscovery().discover(workspaceRoot.path);

    expect(projects.map((item) => item.relativePath), <String>[
      'LogisticsClient',
      p.join('modules', 'common_ui'),
    ]);
  });

  test('returns empty list when workspace does not exist', () async {
    final projects = await const GitProjectDiscovery().discover(
      p.join(Directory.systemTemp.path, 'missing_workspace_${DateTime.now().microsecondsSinceEpoch}'),
    );

    expect(projects, isEmpty);
  });

  test('detects project types from root project files instead of names',
      () async {
    final workspaceRoot =
        await Directory.systemTemp.createTemp('mixbuild_workspace_');
    addTearDown(() async {
      if (await workspaceRoot.exists()) {
        await workspaceRoot.delete(recursive: true);
      }
    });

    final iosRepo = Directory(p.join(workspaceRoot.path, 'mobile-client'));
    final flutterRepo = Directory(p.join(workspaceRoot.path, 'dart-client'));
    final androidRepo = Directory(p.join(workspaceRoot.path, 'gradle-client'));
    final studiosRepo = Directory(p.join(workspaceRoot.path, 'studios-client'));
    await Directory(p.join(iosRepo.path, '.git')).create(recursive: true);
    await Directory(p.join(iosRepo.path, 'Runner.xcodeproj'))
        .create(recursive: true);
    await Directory(p.join(flutterRepo.path, '.git')).create(recursive: true);
    await File(p.join(flutterRepo.path, 'pubspec.yaml')).writeAsString('''
dependencies:
  flutter:
    sdk: flutter
''');
    await Directory(p.join(androidRepo.path, '.git')).create(recursive: true);
    await File(p.join(androidRepo.path, 'settings.gradle')).create();
    await File(p.join(androidRepo.path, 'build.gradle')).create();
    await Directory(p.join(studiosRepo.path, '.git')).create(recursive: true);

    final projects =
        await const GitProjectDiscovery().discover(workspaceRoot.path);
    final projectsByName = <String, DiscoveredGitProject>{
      for (final project in projects) project.name: project,
    };

    expect(
      projectsByName['mobile-client']!.projectType,
      MixbuildProjectType.ios,
    );
    expect(
      projectsByName['dart-client']!.projectType,
      MixbuildProjectType.flutter,
    );
    expect(
      projectsByName['gradle-client']!.projectType,
      MixbuildProjectType.android,
    );
    expect(projectsByName['studios-client']!.projectType, isNull);
  });
}
