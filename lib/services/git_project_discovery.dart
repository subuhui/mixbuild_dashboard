import 'dart:io';

import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Discovered Git repository with absolute and workspace-relative paths.
class DiscoveredGitProject {
  const DiscoveredGitProject({
    required this.name,
    required this.absolutePath,
    required this.relativePath,
    this.projectType,
  });

  final String name;
  final String absolutePath;
  final String relativePath;

  /// Project type inferred from files in the repository root.
  final MixbuildProjectType? projectType;
}

/// Recursively scans a workspace directory for child repositories containing `.git`.
///
/// The default max depth is 3 and common generated directories are skipped.
class GitProjectDiscovery {
  const GitProjectDiscovery({this.maxDepth = 3});

  final int maxDepth;

  static const Set<String> _ignoredDirectoryNames = <String>{
    '.git',
    '.dart_tool',
    '.idea',
    '.vscode',
    'build',
    'node_modules',
  };

  Future<List<DiscoveredGitProject>> discover(String workspaceRoot) async {
    final normalizedRoot = p.normalize(workspaceRoot.trim());
    if (normalizedRoot.isEmpty) {
      return const <DiscoveredGitProject>[];
    }

    final rootDirectory = Directory(normalizedRoot);
    if (!await rootDirectory.exists()) {
      return const <DiscoveredGitProject>[];
    }

    final projects = <DiscoveredGitProject>[];
    final pending = <({Directory directory, int depth})>[
      (directory: rootDirectory, depth: 0),
    ];

    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final currentPath = p.normalize(current.directory.path);
      final gitMetadata = FileSystemEntity.typeSync(p.join(currentPath, '.git'));
      if (gitMetadata != FileSystemEntityType.notFound) {
        projects.add(
          DiscoveredGitProject(
            name: p.basename(currentPath),
            absolutePath: currentPath,
            relativePath: _relativePath(normalizedRoot, currentPath),
            projectType: await _detectProjectType(current.directory),
          ),
        );
        continue;
      }

      if (current.depth >= maxDepth) {
        continue;
      }

      try {
        await for (final entity in current.directory.list(followLinks: false)) {
          if (entity is! Directory) {
            continue;
          }
          final name = p.basename(entity.path);
          if (_ignoredDirectoryNames.contains(name) || name.startsWith('.')) {
            continue;
          }
          pending.add((directory: entity, depth: current.depth + 1));
        }
      } on FileSystemException {
        continue;
      }
    }

    projects.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return projects;
  }

  /// Detects project type by priority: Flutter, iOS, then Android.
  Future<MixbuildProjectType?> _detectProjectType(
    Directory projectDirectory,
  ) async {
    try {
      final rootEntities = <String, FileSystemEntity>{};
      await for (final entity in projectDirectory.list(followLinks: false)) {
        rootEntities[p.basename(entity.path).toLowerCase()] = entity;
      }

      final pubspec = rootEntities['pubspec.yaml'];
      if (pubspec is File && await _isFlutterProject(pubspec)) {
        return MixbuildProjectType.flutter;
      }

      if (rootEntities.keys.any(
        (name) =>
            name == 'podfile' ||
            name.endsWith('.xcodeproj') ||
            name.endsWith('.xcworkspace'),
      )) {
        return MixbuildProjectType.ios;
      }

      final hasGradleSettings = rootEntities.containsKey('settings.gradle') ||
          rootEntities.containsKey('settings.gradle.kts');
      final hasGradleBuild = rootEntities.containsKey('build.gradle') ||
          rootEntities.containsKey('build.gradle.kts');
      final hasGradleWrapper = rootEntities.containsKey('gradlew') ||
          rootEntities.containsKey('gradlew.bat');
      if (hasGradleSettings && (hasGradleBuild || hasGradleWrapper)) {
        return MixbuildProjectType.android;
      }
    } on FileSystemException {
      return null;
    }
    return null;
  }

  /// Checks whether pubspec declares a Flutter SDK dependency.
  Future<bool> _isFlutterProject(File pubspec) async {
    try {
      final document = loadYaml(await pubspec.readAsString());
      if (document is! YamlMap) {
        return false;
      }
      return _hasFlutterSdkDependency(document['dependencies']) ||
          _hasFlutterSdkDependency(document['dev_dependencies']);
    } on YamlException {
      return false;
    }
  }

  /// Checks whether the flutter dependency entry points to the Flutter SDK.
  bool _hasFlutterSdkDependency(Object? dependencies) {
    if (dependencies is! YamlMap) {
      return false;
    }
    final flutterDependency = dependencies['flutter'];
    return flutterDependency is YamlMap &&
        flutterDependency['sdk'] == 'flutter';
  }

  String _relativePath(String workspaceRoot, String projectPath) {
    final relativePath = p.relative(projectPath, from: workspaceRoot);
    return relativePath == '.' ? p.basename(projectPath) : relativePath;
  }
}
