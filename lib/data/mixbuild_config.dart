import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

enum MixbuildProjectType { android, flutter }

MixbuildProjectType _parseProjectType(String value) {
  return MixbuildProjectType.values.firstWhere(
    (item) => item.name == value,
    orElse: () => MixbuildProjectType.android,
  );
}

class MixbuildWorkspaceConfig {
  const MixbuildWorkspaceConfig({required this.name, required this.rootPath});

  final String name;
  final String rootPath;

  MixbuildWorkspaceConfig copyWith({String? name, String? rootPath}) {
    return MixbuildWorkspaceConfig(
      name: name ?? this.name,
      rootPath: rootPath ?? this.rootPath,
    );
  }
}

class MixbuildRepoConfig {
  const MixbuildRepoConfig({
    required this.name,
    required this.path,
    required this.type,
    required this.defaultBranch,
    this.restoreCommand,
  });

  final String name;
  final String path;
  final MixbuildProjectType type;
  final String defaultBranch;
  final String? restoreCommand;

  String absolutePath(String workspaceRoot) {
    return p.normalize(p.join(workspaceRoot, path));
  }

  MixbuildRepoConfig copyWith({
    String? name,
    String? path,
    MixbuildProjectType? type,
    String? defaultBranch,
    Object? restoreCommand = _sentinel,
  }) {
    return MixbuildRepoConfig(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      defaultBranch: defaultBranch ?? this.defaultBranch,
      restoreCommand: restoreCommand == _sentinel
          ? this.restoreCommand
          : restoreCommand as String?,
    );
  }
}

class MixbuildScenarioConfig {
  const MixbuildScenarioConfig({
    required this.id,
    required this.name,
    required this.mainBranch,
    required this.command,
    this.outputDir,
    this.autoTag = false,
    this.tagPrefix = '',
  });

  final String id;
  final String name;
  final String mainBranch;
  final String command;
  final String? outputDir;
  final bool autoTag;
  final String tagPrefix;

  MixbuildScenarioConfig copyWith({
    String? id,
    String? name,
    String? mainBranch,
    String? command,
    Object? outputDir = _sentinel,
    bool? autoTag,
    String? tagPrefix,
  }) {
    return MixbuildScenarioConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      mainBranch: mainBranch ?? this.mainBranch,
      command: command ?? this.command,
      outputDir: outputDir == _sentinel ? this.outputDir : outputDir as String?,
      autoTag: autoTag ?? this.autoTag,
      tagPrefix: tagPrefix ?? this.tagPrefix,
    );
  }
}

class MixbuildConfig {
  const MixbuildConfig({
    required this.filePath,
    required this.workspace,
    required this.mainProject,
    required this.dependencies,
    required this.buildScenarios,
  });

  final String filePath;
  final MixbuildWorkspaceConfig workspace;
  final MixbuildRepoConfig mainProject;
  final List<MixbuildRepoConfig> dependencies;
  final List<MixbuildScenarioConfig> buildScenarios;

  factory MixbuildConfig.fromYaml({
    required String filePath,
    required String content,
  }) {
    final root = loadYaml(content);
    if (root is! YamlMap) {
      throw const FormatException('YAML root must be a map.');
    }

    final workspaceMap = _asMap(root['workspace'], field: 'workspace');
    final mainProjectMap = _asMap(root['main_project'], field: 'main_project');
    final dependencyList = _asOptionalList(root['dependencies']);
    final scenarioList = _asOptionalList(root['build_scenarios']);

    return MixbuildConfig(
      filePath: filePath,
      workspace: MixbuildWorkspaceConfig(
        name: _asString(workspaceMap['name'], field: 'workspace.name'),
        rootPath: _asString(workspaceMap['root_path'], field: 'workspace.root_path'),
      ),
      mainProject: MixbuildRepoConfig(
        name: _asString(mainProjectMap['name'], field: 'main_project.name'),
        path: _asString(mainProjectMap['path'], field: 'main_project.path'),
        type: _parseProjectType(
          _asString(mainProjectMap['type'], field: 'main_project.type'),
        ),
        defaultBranch: _asString(
          mainProjectMap['default_branch'],
          field: 'main_project.default_branch',
        ),
      ),
      dependencies: dependencyList.map((entry) {
        final item = _asMap(entry, field: 'dependencies[]');
        return MixbuildRepoConfig(
          name: _asString(item['name'], field: 'dependencies[].name'),
          path: _asString(item['path'], field: 'dependencies[].path'),
          type: _parseProjectType(
            _asString(item['type'], field: 'dependencies[].type'),
          ),
          defaultBranch: _asString(
            item['default_branch'],
            field: 'dependencies[].default_branch',
          ),
          restoreCommand: _asOptionalString(item['restore_command']),
        );
      }).toList(growable: false),
      buildScenarios: scenarioList.asMap().entries.map((entry) {
        final item = _asMap(entry.value, field: 'build_scenarios[]');
        final name = _asString(item['name'], field: 'build_scenarios[].name');
        return MixbuildScenarioConfig(
          id: _slugify('${entry.key + 1}-$name'),
          name: name,
          mainBranch: _asOptionalString(item['main_branch']) ?? _asString(
            mainProjectMap['default_branch'],
            field: 'main_project.default_branch',
          ),
          command: _asOptionalString(item['command']) ?? '',
          outputDir: _asOptionalString(item['output_dir']),
          autoTag: item['auto_tag'] == true,
          tagPrefix: _asOptionalString(item['tag_prefix']) ?? '',
        );
      }).toList(growable: false),
    );
  }

  factory MixbuildConfig.fromFileSync(String filePath) {
    return MixbuildConfig.fromYaml(
      filePath: filePath,
      content: File(filePath).readAsStringSync(),
    );
  }

  MixbuildConfig copyWith({
    String? filePath,
    MixbuildWorkspaceConfig? workspace,
    MixbuildRepoConfig? mainProject,
    List<MixbuildRepoConfig>? dependencies,
    List<MixbuildScenarioConfig>? buildScenarios,
  }) {
    return MixbuildConfig(
      filePath: filePath ?? this.filePath,
      workspace: workspace ?? this.workspace,
      mainProject: mainProject ?? this.mainProject,
      dependencies: dependencies ?? this.dependencies,
      buildScenarios: buildScenarios ?? this.buildScenarios,
    );
  }

  String get workspaceSlug => workspaceSlugFor(workspace.name);

  static String workspaceSlugFor(String workspaceName) => _slugify(workspaceName);

  String toYamlString() {
    final buffer = StringBuffer()
      ..writeln('workspace:')
      ..writeln('  name: ${_quote(workspace.name)}')
      ..writeln('  root_path: ${_quote(workspace.rootPath)}')
      ..writeln('main_project:')
      ..writeln('  name: ${_quote(mainProject.name)}')
      ..writeln('  path: ${_quote(mainProject.path)}')
      ..writeln('  type: ${_quote(mainProject.type.name)}')
      ..writeln('  default_branch: ${_quote(mainProject.defaultBranch)}')
      ..writeln('dependencies:');

    for (final dependency in dependencies) {
      buffer
        ..writeln('  - name: ${_quote(dependency.name)}')
        ..writeln('    path: ${_quote(dependency.path)}')
        ..writeln('    type: ${_quote(dependency.type.name)}')
        ..writeln('    default_branch: ${_quote(dependency.defaultBranch)}');
      if (dependency.restoreCommand != null) {
        buffer.writeln(
          '    restore_command: ${_quote(dependency.restoreCommand!)}',
        );
      }
    }

    buffer.writeln('build_scenarios:');
    for (final scenario in buildScenarios) {
      buffer
        ..writeln('  - name: ${_quote(scenario.name)}')
        ..writeln('    main_branch: ${_quote(scenario.mainBranch)}')
        ..writeln('    command: ${_quote(scenario.command)}');
      if (scenario.outputDir != null) {
        buffer.writeln('    output_dir: ${_quote(scenario.outputDir!)}');
      }
      if (scenario.autoTag) {
        buffer.writeln('    auto_tag: true');
      }
      if (scenario.tagPrefix.isNotEmpty) {
        buffer.writeln('    tag_prefix: ${_quote(scenario.tagPrefix)}');
      }
    }
    return buffer.toString();
  }
}

const Object _sentinel = Object();

YamlMap _asMap(Object? value, {required String field}) {
  if (value is! YamlMap) {
    throw FormatException('$field must be a map.');
  }
  return value;
}

YamlList _asOptionalList(Object? value) {
  if (value == null) {
    return YamlList.wrap(const []);
  }
  if (value is! YamlList) {
    throw const FormatException('dependencies must be a list.');
  }
  return value;
}

String _asString(Object? value, {required String field}) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value.trim();
}

String? _asOptionalString(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw const FormatException('Expected string value.');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _slugify(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return normalized.isEmpty ? 'scenario' : normalized;
}

String _quote(String value) {
  return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
}
