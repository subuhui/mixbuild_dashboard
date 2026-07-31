import 'dart:io';

import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/services/build_execution_history_store.dart';
import 'package:mixbuild_dashboard/services/mixbuild_engine.dart';
import 'package:mixbuild_dashboard/services/mixbuild_yaml_store.dart';
import 'package:path/path.dart' as p;

class McpBuildServiceException implements Exception {
  const McpBuildServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class McpBuildService {
  const McpBuildService(this._yamlStore, this._engine, this._historyStore);

  final MixbuildYamlStore _yamlStore;
  final MixbuildEngine _engine;
  final BuildExecutionHistoryStore _historyStore;

  Map<String, dynamic> listScenarios({
    required String projectDirectory,
    required String branch,
  }) {
    final match = _matchProject(
      projectDirectory: projectDirectory,
      branch: branch,
    );
    return <String, dynamic>{
      'workspace': match.config.workspace.name,
      'project': match.config.mainProject.name,
      'project_directory': match.projectDirectory,
      'branch': branch.trim(),
      'scenarios': match.scenarios.map(_scenarioJson).toList(growable: false),
    };
  }

  Future<Map<String, dynamic>> buildProject({
    required String projectDirectory,
    required String branch,
    String? scenarioName,
    bool cleanBeforeBuild = false,
  }) async {
    final match = _matchProject(
      projectDirectory: projectDirectory,
      branch: branch,
    );
    final scenarioConfig = _selectScenario(
      match.scenarios,
      scenarioName: scenarioName,
    );
    final scenario = _runtimeScenario(match.config, scenarioConfig);
    final project = ProjectBuild(
      id: match.config.filePath,
      emoji: '',
      name: match.config.mainProject.name,
      description: match.config.workspace.name,
      branch: branch.trim(),
      type: match.config.mainProject.type,
      scenarios: <BuildScenario>[scenario],
    );
    final startedAt = DateTime.now();
    final logs = <LogEntry>[];
    var status = BuildStatus.success;
    String? errorMessage;

    try {
      await _engine.runPipeline(
        config: match.config,
        project: project,
        scenario: scenario,
        projectBranch: scenarioConfig.mainBranch,
        cleanBeforeBuild: cleanBeforeBuild,
        dependencyOverrides: scenarioConfig.dependencyOverrides,
        onProgress: (nextStatus, _) => status = nextStatus,
        onLog: logs.add,
      );
      status = BuildStatus.success;
    } catch (error) {
      status = BuildStatus.failed;
      errorMessage = '$error';
    }

    final finishedAt = DateTime.now();
    _appendHistory(
      BuildExecutionRecord(
        id: 'mcp-${startedAt.microsecondsSinceEpoch}',
        projectId: match.config.filePath,
        projectName: match.config.mainProject.name,
        scenarioId: scenario.id,
        scenarioName: scenario.name,
        command: scenario.command,
        branch: branch.trim(),
        status: status,
        startedAt: startedAt,
        finishedAt: finishedAt,
        logs: logs,
      ),
    );

    return <String, dynamic>{
      'success': errorMessage == null,
      'workspace': match.config.workspace.name,
      'project': match.config.mainProject.name,
      'project_directory': match.projectDirectory,
      'branch': branch.trim(),
      'scenario': _scenarioJson(scenarioConfig),
      'clean_before_build': cleanBeforeBuild,
      'status': status.name,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt.toIso8601String(),
      if (scenarioConfig.outputDir != null)
        'output_directory': _outputDirectory(
          match.projectDirectory,
          scenarioConfig.outputDir!,
        ),
      ...errorMessage == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'error': errorMessage},
      'logs': logs
          .map(
            (entry) => <String, dynamic>{
              'time': entry.time,
              'level': entry.level,
              'message': entry.message,
            },
          )
          .toList(growable: false),
    };
  }

  Map<String, dynamic> addScenario({
    required String projectDirectory,
    required String branch,
    required String name,
    required String command,
    String? outputDirectory,
    bool autoTag = false,
    String tagPrefix = '',
    Map<String, String> dependencyOverrides = const <String, String>{},
  }) {
    final trimmedName = _requiredText(name, field: 'name');
    final trimmedBranch = _requiredText(branch, field: 'branch');
    final trimmedCommand = _requiredText(command, field: 'command');
    final projectMatch = _matchProjectDirectory(projectDirectory);
    final duplicate = projectMatch.config.buildScenarios.any(
      (scenario) =>
          scenario.name == trimmedName && scenario.mainBranch == trimmedBranch,
    );
    if (duplicate) {
      throw McpBuildServiceException(
        'Build scenario already exists: $trimmedName / $trimmedBranch',
      );
    }

    final dependencyNames = projectMatch.config.dependencies
        .map((dependency) => dependency.name)
        .toSet();
    for (final entry in dependencyOverrides.entries) {
      if (!dependencyNames.contains(entry.key)) {
        throw McpBuildServiceException(
          'Unknown dependency override: ${entry.key}',
        );
      }
      _requiredText(entry.value, field: 'dependency_overrides.${entry.key}');
    }

    final scenario = MixbuildScenarioConfig(
      id: '',
      name: trimmedName,
      mainBranch: trimmedBranch,
      command: trimmedCommand,
      outputDir: _optionalText(outputDirectory),
      autoTag: autoTag,
      tagPrefix: tagPrefix.trim(),
      dependencyOverrides: Map<String, String>.from(dependencyOverrides),
    );
    final savedConfig = _yamlStore.saveConfigSync(
      projectMatch.config.copyWith(
        buildScenarios: <MixbuildScenarioConfig>[
          ...projectMatch.config.buildScenarios,
          scenario,
        ],
      ),
    );
    final savedScenario = savedConfig.buildScenarios.last;

    return <String, dynamic>{
      'success': true,
      'workspace': savedConfig.workspace.name,
      'project': savedConfig.mainProject.name,
      'project_directory': _projectDirectory(savedConfig),
      'config_file': savedConfig.filePath,
      'scenario': _scenarioJson(savedScenario),
    };
  }

  _ProjectMatch _matchProject({
    required String projectDirectory,
    required String branch,
  }) {
    final projectMatch = _matchProjectDirectory(projectDirectory);
    final trimmedBranch = _requiredText(branch, field: 'branch');
    final scenarios = projectMatch.config.buildScenarios
        .where((scenario) => scenario.mainBranch == trimmedBranch)
        .toList(growable: false);
    if (scenarios.isEmpty) {
      throw McpBuildServiceException(
        'No build scenario matches branch `$trimmedBranch` for '
        '${projectMatch.config.mainProject.name}.',
      );
    }
    return _ProjectMatch(
      config: projectMatch.config,
      projectDirectory: projectMatch.projectDirectory,
      scenarios: scenarios,
    );
  }

  _ProjectMatch _matchProjectDirectory(String projectDirectory) {
    final requestedPath = _canonicalDirectory(projectDirectory);
    final candidates = <_ProjectMatch>[];
    for (final config in _loadConfigs()) {
      final mainProjectPath = _canonicalPath(_projectDirectory(config));
      if (requestedPath == mainProjectPath ||
          p.isWithin(mainProjectPath, requestedPath)) {
        candidates.add(
          _ProjectMatch(
            config: config,
            projectDirectory: mainProjectPath,
            scenarios: const <MixbuildScenarioConfig>[],
          ),
        );
      }
    }
    if (candidates.isEmpty) {
      throw McpBuildServiceException(
        'No MixBuild project matches directory: $requestedPath',
      );
    }

    candidates.sort(
      (left, right) =>
          right.projectDirectory.length.compareTo(left.projectDirectory.length),
    );
    final best = candidates.first;
    final ambiguous = candidates.where(
      (candidate) => candidate.projectDirectory == best.projectDirectory,
    );
    if (ambiguous.length > 1) {
      final workspaces = ambiguous
          .map((candidate) => candidate.config.workspace.name)
          .join(', ');
      throw McpBuildServiceException(
        'Multiple MixBuild workspaces match $requestedPath: $workspaces',
      );
    }
    return best;
  }

  List<MixbuildConfig> _loadConfigs() {
    var files = _yamlStore.discoverWorkspaceYamlFilesSync();
    if (files.isEmpty) {
      _yamlStore.loadInitialConfigSync();
      files = _yamlStore.discoverWorkspaceYamlFilesSync();
    }
    final configs = <MixbuildConfig>[];
    for (final file in files) {
      try {
        configs.add(MixbuildConfig.fromFileSync(file.path));
      } on FormatException {
        continue;
      }
    }
    if (configs.isEmpty) {
      throw const McpBuildServiceException(
        'No valid MixBuild workspace configuration was found.',
      );
    }
    return configs;
  }

  MixbuildScenarioConfig _selectScenario(
    List<MixbuildScenarioConfig> scenarios, {
    String? scenarioName,
  }) {
    final trimmedName = _optionalText(scenarioName);
    if (trimmedName != null) {
      final matches = scenarios
          .where((scenario) => scenario.name == trimmedName)
          .toList(growable: false);
      if (matches.length != 1) {
        throw McpBuildServiceException(
          'Expected one scenario named `$trimmedName`, found ${matches.length}.',
        );
      }
      return matches.single;
    }
    if (scenarios.length != 1) {
      final names = scenarios.map((scenario) => scenario.name).join(', ');
      throw McpBuildServiceException(
        'Multiple scenarios match this directory and branch. '
        'Specify scenario_name from: $names',
      );
    }
    return scenarios.single;
  }

  BuildScenario _runtimeScenario(
    MixbuildConfig config,
    MixbuildScenarioConfig scenario,
  ) {
    return BuildScenario(
      id: scenario.id,
      name: scenario.name,
      subtitle: config.workspace.name,
      environment: config.workspace.name,
      mainBranch: scenario.mainBranch,
      command: scenario.command,
      status: BuildStatus.idle,
      progress: 0,
      logs: const <LogEntry>[],
      dependencies: const <DependencyBranch>[],
      outputPath: scenario.outputDir ?? '',
      autoTag: scenario.autoTag,
      tagPrefix: scenario.tagPrefix,
    );
  }

  void _appendHistory(BuildExecutionRecord record) {
    final currentHistory = _historyStore.loadHistorySync();
    _historyStore.saveHistorySync(<BuildExecutionRecord>[
      record,
      ...currentHistory,
    ]);
  }

  String _projectDirectory(MixbuildConfig config) {
    return config.mainProject.absolutePath(config.workspace.rootPath);
  }
}

class _ProjectMatch {
  const _ProjectMatch({
    required this.config,
    required this.projectDirectory,
    required this.scenarios,
  });

  final MixbuildConfig config;
  final String projectDirectory;
  final List<MixbuildScenarioConfig> scenarios;
}

Map<String, dynamic> _scenarioJson(MixbuildScenarioConfig scenario) {
  return <String, dynamic>{
    'id': scenario.id,
    'name': scenario.name,
    'branch': scenario.mainBranch,
    'command': scenario.command,
    if (scenario.outputDir != null) 'output_directory': scenario.outputDir,
    'auto_tag': scenario.autoTag,
    if (scenario.tagPrefix.isNotEmpty) 'tag_prefix': scenario.tagPrefix,
    'dependency_overrides': scenario.dependencyOverrides,
  };
}

String _canonicalDirectory(String value) {
  final path = _requiredText(value, field: 'project_directory');
  final directory = Directory(path);
  if (!directory.existsSync()) {
    throw McpBuildServiceException(
      'Project directory does not exist: ${directory.absolute.path}',
    );
  }
  return _canonicalPath(directory.path);
}

String _canonicalPath(String value) {
  final absolutePath = p.normalize(p.absolute(value));
  final directory = Directory(absolutePath);
  if (directory.existsSync()) {
    return directory.resolveSymbolicLinksSync();
  }
  return absolutePath;
}

String _outputDirectory(String projectDirectory, String outputDirectory) {
  return p.normalize(
    p.isAbsolute(outputDirectory)
        ? outputDirectory
        : p.join(projectDirectory, outputDirectory),
  );
}

String _requiredText(String value, {required String field}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw McpBuildServiceException('$field must be a non-empty string.');
  }
  return trimmed;
}

String? _optionalText(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
