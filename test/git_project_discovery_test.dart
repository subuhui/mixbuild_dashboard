import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}