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

  test('parses and serializes yaml without removed branch fields', () {
    const yaml = '''
workspace:
  name: "Driver"
  root_path: "/tmp/workspace"
main_project:
  name: "android-driver"
  path: "android-driver"
  type: "android"
dependencies:
  - name: "driver-v2"
    path: "driver-v2"
    type: "android"
build_scenarios:
  - name: "Release"
    main_branch: "release_26_07V1"
    command: "./gradlew assembleRelease"
    dependency_overrides:
      driver-v2: "release_26_07V1"
''';

    final config = MixbuildConfig.fromYaml(
      filePath: '/tmp/driver.yaml',
      content: yaml,
    );

    expect(config.mainProject.name, 'android-driver');
    expect(config.dependencies.single.name, 'driver-v2');
    expect(config.buildScenarios.single.mainBranch, 'release_26_07V1');
    expect(config.toYamlString(), isNot(contains('default_branch')));
  });

  test('parses and serializes an optional default update description', () {
    const yaml = '''
workspace:
  name: "Release Workspace"
  root_path: "/tmp/workspace"
main_project:
  name: "sample_app"
  path: "."
  type: "flutter"
build_scenarios:
  - name: "Release"
    main_branch: "main"
    command: './build.sh --notes=\${build.update_description}'
    default_update_description: "修复登录问题\\n优化性能"
''';

    final config = MixbuildConfig.fromYaml(
      filePath: '/tmp/update-description.yaml',
      content: yaml,
    );

    expect(
      config.buildScenarios.single.defaultUpdateDescription,
      '修复登录问题\n优化性能',
    );
    expect(
      config.toYamlString(),
      contains('default_update_description: "修复登录问题\\n优化性能"'),
    );
  });

  test('accepts dot-separated project names used by command variables', () {
    const yaml = '''
workspace:
  name: "Flutter Modules"
  root_path: "/tmp/workspace"
main_project:
  name: "FhbApp.Flutter"
  path: "FhbApp.Flutter"
  type: "flutter"
dependencies:
  - name: "flutter.module.ui"
    path: "flutter.module.ui"
    type: "flutter"
build_scenarios:
  - name: "Debug"
    main_branch: "main"
    command: "echo \${dependencies.flutter.module.ui.path}"
''';

    final config = MixbuildConfig.fromYaml(
      filePath: '/tmp/dotted-project-names.yaml',
      content: yaml,
    );

    expect(config.mainProject.name, 'FhbApp.Flutter');
    expect(config.dependencies.single.name, 'flutter.module.ui');
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
dependencies:
  - name: "native_kit"
    path: "./native-kit"
    type: "ios"
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
dependencies:
  - name: "sharedé"
    path: "./shared"
    type: "flutter"
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
      ),
      dependencies: const <MixbuildRepoConfig>[
        MixbuildRepoConfig(
          name: 'sharedé',
          path: './shared',
          type: MixbuildProjectType.flutter,
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
dependencies:
  - name: "common_ui"
    path: "modules/common_ui"
    type: "flutter"
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
