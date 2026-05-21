import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/services/mixbuild_yaml_store.dart';

void main() {
  test('parses yaml when dependencies is omitted', () {
    const yaml = '''
workspace:
  name: "Sample Workspace"
  root_path: "/tmp/workspace"
main_project:
  name: "SampleApp"
  path: "."
  type: "flutter"
  default_branch: "main"
build_scenarios:
  - name: "Debug Build"
    main_branch: "release/main"
    command: "fvm flutter build macos --debug"
''';

    final config = MixbuildConfig.fromYaml(
      filePath: '/tmp/sample.yaml',
      content: yaml,
    );

    expect(config.dependencies, isEmpty);
    expect(config.buildScenarios, hasLength(1));
    expect(config.workspace.name, 'Sample Workspace');
    expect(config.buildScenarios.single.mainBranch, 'release/main');
  });

  test('loadInitialConfigSync prefers non-sample workspace and remembers last opened', () {
    final tempDir = Directory.systemTemp.createTempSync('mixbuild-store-test');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final store = MixbuildYamlStore(configHomePath: tempDir.path);
    final workspacesDir = Directory(store.workspaceDirectoryPath)..createSync(recursive: true);
    final sampleFile = File('${workspacesDir.path}/sample.yaml')
      ..writeAsStringSync('''
workspace:
  name: "Sample Workspace"
  root_path: "/tmp/sample"
main_project:
  name: "SampleApp"
  path: "."
  type: "flutter"
  default_branch: "main"
build_scenarios:
  - name: "Debug Build"
    command: "fvm flutter build macos --debug"
''');
    final actualFile = File('${workspacesDir.path}/actual.yaml')
      ..writeAsStringSync('''
workspace:
  name: "Actual Workspace"
  root_path: "/tmp/actual"
main_project:
  name: "ActualApp"
  path: "ActualApp"
  type: "android"
  default_branch: "develop"
dependencies:
  - name: "common_ui"
    path: "modules/common_ui"
    type: "flutter"
    default_branch: "main"
build_scenarios:
  - name: "Release Build"
    command: "./gradlew assembleRelease"
''');

    sampleFile.setLastModifiedSync(DateTime(2024));
    actualFile.setLastModifiedSync(DateTime(2025));

    final loaded = store.loadInitialConfigSync();

    expect(loaded.workspace.name, 'Actual Workspace');
    expect(File(store.lastOpenedWorkspacePath).readAsStringSync().trim(), actualFile.path);

    final reopened = store.loadInitialConfigSync();
    expect(reopened.filePath, actualFile.path);
  });
}
