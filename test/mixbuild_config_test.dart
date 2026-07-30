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

  test('parses and serializes ios project type', () {
    const yaml = '''
workspace:
  name: "iOS Workspace"
  root_path: "/tmp/workspace"
main_project:
  name: "iOSApp"
  path: "./ios-app"
  type: "iOS"
  default_branch: "main"
dependencies:
  - name: "native_kit"
    path: "./native-kit"
    type: "ios"
    default_branch: "develop"
    restore_command: "pod install"
build_scenarios:
  - name: "Release Build"
    command: "xcodebuild -scheme iOSApp archive"
''';

    final config = MixbuildConfig.fromYaml(
      filePath: '/tmp/ios.yaml',
      content: yaml,
    );

    expect(config.mainProject.type, MixbuildProjectType.ios);
    expect(config.dependencies.single.type, MixbuildProjectType.ios);
    expect(config.toYamlString(), contains('type: "ios"'));
  });

  test('rejects non-ascii main project name', () {
    const yaml = '''
workspace:
  name: "Workspace With Accents"
  root_path: "/tmp/workspace"
main_project:
  name: "Mainé"
  path: "."
  type: "flutter"
  default_branch: "main"
build_scenarios:
  - name: "Scenario With Accents"
    command: "fvm flutter build macos --debug"
''';

    expect(
      () => MixbuildConfig.fromYaml(
        filePath: '/tmp/invalid-main-name.yaml',
        content: yaml,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('main_project.name must contain only ASCII'),
        ),
      ),
    );
  });

  test('rejects non-ascii dependency name', () {
    const yaml = '''
workspace:
  name: "Workspace With Accents"
  root_path: "/tmp/workspace"
main_project:
  name: "SampleApp"
  path: "."
  type: "flutter"
  default_branch: "main"
dependencies:
  - name: "sharedé"
    path: "./shared"
    type: "flutter"
    default_branch: "develop"
build_scenarios:
  - name: "Scenario With Accents"
    command: "fvm flutter build macos --debug"
''';

    expect(
      () => MixbuildConfig.fromYaml(
        filePath: '/tmp/invalid-dependency-name.yaml',
        content: yaml,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('dependencies[].name must contain only ASCII'),
        ),
      ),
    );
  });

  test('rejects invalid constructed project names before serialization', () {
    final config = MixbuildConfig(
      filePath: '/tmp/invalid-constructed.yaml',
      workspace: const MixbuildWorkspaceConfig(
        name: 'Workspace With Accents',
        rootPath: '/tmp/workspace',
      ),
      mainProject: const MixbuildRepoConfig(
        name: 'SampleApp',
        path: '.',
        type: MixbuildProjectType.flutter,
        defaultBranch: 'main',
      ),
      dependencies: const <MixbuildRepoConfig>[
        MixbuildRepoConfig(
          name: 'sharedé',
          path: './shared',
          type: MixbuildProjectType.flutter,
          defaultBranch: 'develop',
        ),
      ],
      buildScenarios: const <MixbuildScenarioConfig>[
        MixbuildScenarioConfig(
          id: 'debug-build',
          name: 'Scenario With Accents',
          mainBranch: 'main',
          command: 'fvm flutter build macos --debug',
        ),
      ],
    );

    expect(config.toYamlString, throwsA(isA<FormatException>()));
  });

  test(
    'loadInitialConfigSync prefers non-sample workspace and remembers last opened',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'mixbuild-store-test',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final store = MixbuildYamlStore(configHomePath: tempDir.path);
      final workspacesDir = Directory(store.workspaceDirectoryPath)
        ..createSync(recursive: true);
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
      expect(
        File(store.lastOpenedWorkspacePath).readAsStringSync().trim(),
        actualFile.path,
      );

      final reopened = store.loadInitialConfigSync();
      expect(reopened.filePath, actualFile.path);
    },
  );
}
