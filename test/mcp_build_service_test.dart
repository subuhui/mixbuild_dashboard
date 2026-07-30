import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/build_execution_history_store.dart';
import 'package:mixbuild_dashboard/services/mcp_build_service.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:mixbuild_dashboard/services/mixbuild_engine.dart';
import 'package:mixbuild_dashboard/services/mixbuild_yaml_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory configHome;
  late Directory workspace;
  late Directory projectDirectory;
  late MixbuildYamlStore yamlStore;
  late BuildExecutionHistoryStore historyStore;
  late _RecordingEngine engine;
  late McpBuildService service;

  setUp(() {
    configHome = Directory.systemTemp.createTempSync('mixbuild-mcp-config_');
    workspace = Directory.systemTemp.createTempSync('mixbuild-mcp-workspace_');
    projectDirectory = Directory(p.join(workspace.path, 'app'))
      ..createSync(recursive: true);
    Directory(p.join(projectDirectory.path, 'lib')).createSync();
    yamlStore = MixbuildYamlStore(configHomePath: configHome.path);
    historyStore = BuildExecutionHistoryStore(configHomePath: configHome.path);
    engine = _RecordingEngine();
    service = McpBuildService(yamlStore, engine, historyStore);
    yamlStore.saveNewConfigSync(
      MixbuildConfig(
        filePath: '',
        workspace: MixbuildWorkspaceConfig(
          name: 'MCP Workspace',
          rootPath: workspace.path,
        ),
        mainProject: const MixbuildRepoConfig(
          name: 'sample_app',
          path: 'app',
          type: MixbuildProjectType.flutter,
          defaultBranch: 'main',
        ),
        dependencies: const <MixbuildRepoConfig>[
          MixbuildRepoConfig(
            name: 'shared_ui',
            path: 'shared_ui',
            type: MixbuildProjectType.flutter,
            defaultBranch: 'main',
          ),
        ],
        buildScenarios: const <MixbuildScenarioConfig>[
          MixbuildScenarioConfig(
            id: 'release-build',
            name: 'Release Build',
            mainBranch: 'release/1.0',
            command: 'flutter build macos --release',
            outputDir: 'build/release',
            dependencyOverrides: <String, String>{'shared_ui': 'release/1.0'},
          ),
        ],
      ),
    );
  });

  tearDown(() {
    if (configHome.existsSync()) {
      configHome.deleteSync(recursive: true);
    }
    if (workspace.existsSync()) {
      workspace.deleteSync(recursive: true);
    }
  });

  test('matches a project subdirectory and exact branch', () {
    final result = service.listScenarios(
      projectDirectory: p.join(projectDirectory.path, 'lib'),
      branch: 'release/1.0',
    );

    expect(result['project'], 'sample_app');
    expect(
      result['project_directory'],
      projectDirectory.resolveSymbolicLinksSync(),
    );
    final scenarios = result['scenarios'] as List<dynamic>;
    expect(scenarios, hasLength(1));
    expect((scenarios.single as Map<String, dynamic>)['name'], 'Release Build');
  });

  test('rejects a directory match when no scenario matches the branch', () {
    expect(
      () => service.listScenarios(
        projectDirectory: projectDirectory.path,
        branch: 'feature/missing',
      ),
      throwsA(
        isA<McpBuildServiceException>().having(
          (error) => error.message,
          'message',
          contains('No build scenario matches branch'),
        ),
      ),
    );
  });

  test('runs the existing engine and persists MCP execution history', () async {
    final result = await service.buildProject(
      projectDirectory: projectDirectory.path,
      branch: 'release/1.0',
      cleanBeforeBuild: true,
    );

    expect(result['success'], isTrue);
    expect(result['status'], 'success');
    expect(
      result['output_directory'],
      p.join(projectDirectory.resolveSymbolicLinksSync(), 'build/release'),
    );
    expect(engine.lastScenario?.name, 'Release Build');
    expect(engine.lastCleanBeforeBuild, isTrue);
    expect(engine.lastDependencyOverrides, const <String, String>{
      'shared_ui': 'release/1.0',
    });

    final history = historyStore.loadHistorySync();
    expect(history, hasLength(1));
    expect(history.single.projectName, 'sample_app');
    expect(history.single.scenarioName, 'Release Build');
    expect(history.single.status, BuildStatus.success);
  });

  test('adds a scenario to the project matched by directory', () {
    final result = service.addScenario(
      projectDirectory: p.join(projectDirectory.path, 'lib'),
      branch: 'feature/mcp',
      name: 'MCP Build',
      command: 'flutter build apk --release',
      outputDirectory: 'build/app/outputs',
      dependencyOverrides: const <String, String>{'shared_ui': 'feature/mcp'},
    );

    expect(result['success'], isTrue);
    final config = MixbuildConfig.fromFileSync(result['config_file'] as String);
    expect(config.buildScenarios, hasLength(2));
    final added = config.buildScenarios.last;
    expect(added.name, 'MCP Build');
    expect(added.mainBranch, 'feature/mcp');
    expect(added.command, 'flutter build apk --release');
    expect(added.dependencyOverrides, const <String, String>{
      'shared_ui': 'feature/mcp',
    });
  });
}

class _RecordingEngine extends MixbuildEngine {
  _RecordingEngine() : super(ProcessRunCommandRunner());

  BuildScenario? lastScenario;
  bool? lastCleanBeforeBuild;
  Map<String, String>? lastDependencyOverrides;

  @override
  Future<void> runPipeline({
    required MixbuildConfig config,
    required ProjectBuild project,
    required BuildScenario scenario,
    required bool cleanBeforeBuild,
    required Map<String, String> dependencyOverrides,
    required void Function(BuildStatus status, double progress) onProgress,
    required void Function(LogEntry entry) onLog,
  }) async {
    lastScenario = scenario;
    lastCleanBeforeBuild = cleanBeforeBuild;
    lastDependencyOverrides = dependencyOverrides;
    onProgress(BuildStatus.success, 1);
  }
}
