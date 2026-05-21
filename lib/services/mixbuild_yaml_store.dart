import 'dart:async';
import 'dart:io';

import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:path/path.dart' as p;

class MixbuildYamlStore {
  const MixbuildYamlStore({String? configHomePath}) : _configHomePathOverride = configHomePath;

  final String? _configHomePathOverride;

  String get appConfigDirectoryPath => p.join(_configHomePath, 'mixbuild_dashboard');
  String get legacyYamlPath => p.join(appConfigDirectoryPath, 'mixbuild.yaml');
  String get workspaceDirectoryPath => p.join(appConfigDirectoryPath, 'workspaces');
  String get lastOpenedWorkspacePath => p.join(appConfigDirectoryPath, 'last_opened_workspace.txt');

  String get _localLegacyYamlPath => p.join(Directory.current.path, 'config', 'mixbuild.yaml');
  String get _localWorkspaceDirectoryPath =>
      p.join(Directory.current.path, 'config', 'workspaces');

  List<File> discoverWorkspaceYamlFilesSync() {
    return _discoverYamlFilesIn(workspaceDirectoryPath);
  }

  MixbuildConfig loadInitialConfigSync() {
    _ensureAppConfigDirectory();

    final lastOpened = _readLastOpenedWorkspaceSync();
    if (lastOpened != null) {
      return MixbuildConfig.fromFileSync(lastOpened.path);
    }

    final localWorkspaceFiles = _discoverYamlFilesIn(_localWorkspaceDirectoryPath);
    final appWorkspaceFiles = discoverWorkspaceYamlFilesSync();

    if (localWorkspaceFiles.isNotEmpty && _containsOnlySampleWorkspace(appWorkspaceFiles)) {
      final migratedWorkspaceFiles = _migrateLocalWorkspaceFilesSync();
      if (migratedWorkspaceFiles.isNotEmpty) {
        final preferredFile = _preferredWorkspaceFile(migratedWorkspaceFiles);
        _writeLastOpenedWorkspaceSync(preferredFile.path);
        return MixbuildConfig.fromFileSync(preferredFile.path);
      }
    }

    final workspaceFiles = discoverWorkspaceYamlFilesSync();
    if (workspaceFiles.isNotEmpty) {
      final preferredFile = _preferredWorkspaceFile(workspaceFiles);
      _writeLastOpenedWorkspaceSync(preferredFile.path);
      return MixbuildConfig.fromFileSync(preferredFile.path);
    }

    final legacyFile = File(legacyYamlPath);
    if (legacyFile.existsSync()) {
      final legacyConfig = MixbuildConfig.fromFileSync(legacyYamlPath);
      return saveConfigSync(legacyConfig);
    }

    final migratedWorkspaceFiles = _migrateLocalWorkspaceFilesSync();
    if (migratedWorkspaceFiles.isNotEmpty) {
      final preferredFile = _preferredWorkspaceFile(migratedWorkspaceFiles);
      _writeLastOpenedWorkspaceSync(preferredFile.path);
      return MixbuildConfig.fromFileSync(preferredFile.path);
    }

    final localLegacyFile = File(_localLegacyYamlPath);
    if (localLegacyFile.existsSync()) {
      final legacyConfig = MixbuildConfig.fromFileSync(localLegacyFile.path);
      return saveConfigSync(legacyConfig);
    }

    return saveConfigSync(_defaultConfig());
  }

  MixbuildConfig loadConfigSync(String filePath) {
    final config = MixbuildConfig.fromFileSync(filePath);
    _writeLastOpenedWorkspaceSync(config.filePath);
    return config;
  }

  String readYamlSync(String filePath) {
    return File(filePath).readAsStringSync();
  }

  MixbuildConfig saveRawYamlSync(String content, {String? currentFilePath}) {
    final provisionalPath = currentFilePath ?? legacyYamlPath;
    final parsed = MixbuildConfig.fromYaml(filePath: provisionalPath, content: content);
    final targetPath = workspaceYamlPath(parsed.workspaceSlug);
    _ensureWorkspaceDirectory();
    File(targetPath).writeAsStringSync(parsed.copyWith(filePath: targetPath).toYamlString());
    _deleteObsoleteWorkspaceFile(currentFilePath, targetPath);
    _writeLastOpenedWorkspaceSync(targetPath);
    return MixbuildConfig.fromFileSync(targetPath);
  }

  MixbuildConfig saveConfigSync(MixbuildConfig config) {
    final targetPath = workspaceYamlPath(config.workspaceSlug);
    _ensureWorkspaceDirectory();
    File(targetPath).writeAsStringSync(config.copyWith(filePath: targetPath).toYamlString());
    _deleteObsoleteWorkspaceFile(config.filePath, targetPath);
    _writeLastOpenedWorkspaceSync(targetPath);
    return MixbuildConfig.fromFileSync(targetPath);
  }

  MixbuildConfig saveNewConfigSync(MixbuildConfig config) {
    final targetPath = workspaceYamlPath(config.workspaceSlug);
    _ensureWorkspaceDirectory();
    File(targetPath).writeAsStringSync(config.copyWith(filePath: targetPath).toYamlString());
    _writeLastOpenedWorkspaceSync(targetPath);
    return MixbuildConfig.fromFileSync(targetPath);
  }

  Stream<FileSystemEvent> watch(String filePath) {
    return File(filePath).watch(events: FileSystemEvent.modify | FileSystemEvent.create | FileSystemEvent.delete);
  }

  String workspaceYamlPath(String workspaceSlug) {
    return p.join(workspaceDirectoryPath, '$workspaceSlug.yaml');
  }

  List<File> _discoverYamlFilesIn(String directoryPath) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      return const [];
    }
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.yaml') || file.path.endsWith('.yml'))
        .toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
    return files;
  }

  List<File> _migrateLocalWorkspaceFilesSync() {
    final localFiles = _discoverYamlFilesIn(_localWorkspaceDirectoryPath);
    if (localFiles.isEmpty) {
      return const [];
    }

    _ensureWorkspaceDirectory();
    final migratedFiles = <File>[];
    for (final localFile in localFiles) {
      final config = MixbuildConfig.fromFileSync(localFile.path);
      final savedConfig = saveConfigSync(config);
      migratedFiles.add(File(savedConfig.filePath));
    }
    return migratedFiles;
  }

  MixbuildConfig _defaultConfig() {
    final workspaceRoot = Directory.current.path;
    final workspaceName = p.basename(workspaceRoot);
    return MixbuildConfig(
      filePath: workspaceYamlPath(_slugForWorkspace(workspaceName)),
      workspace: MixbuildWorkspaceConfig(
        name: workspaceName,
        rootPath: workspaceRoot,
      ),
      mainProject: const MixbuildRepoConfig(
        name: 'main_project',
        path: '.',
        type: MixbuildProjectType.flutter,
        defaultBranch: 'main',
      ),
      dependencies: const [],
      buildScenarios: const [
        MixbuildScenarioConfig(
          id: 'default-debug-build',
          name: 'Debug Build',
          mainBranch: 'main',
          command: 'fvm flutter build macos --debug',
          outputDir: 'build/macos/Build/Products/Debug',
        ),
      ],
    );
  }

  String _slugForWorkspace(String workspaceName) {
    final normalized = workspaceName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized.isEmpty ? 'workspace' : normalized;
  }

  String get _configHomePath {
    final overridePath = _configHomePathOverride;
    if (overridePath != null && overridePath.trim().isNotEmpty) {
      return overridePath.trim();
    }

    final xdgConfigHome = Platform.environment['XDG_CONFIG_HOME'];
    if (xdgConfigHome != null && xdgConfigHome.trim().isNotEmpty) {
      return xdgConfigHome.trim();
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return p.join(home.trim(), '.config');
    }

    throw StateError('Unable to determine user config directory.');
  }

  void _ensureAppConfigDirectory() {
    Directory(appConfigDirectoryPath).createSync(recursive: true);
  }

  void _ensureWorkspaceDirectory() {
    _ensureAppConfigDirectory();
    Directory(workspaceDirectoryPath).createSync(recursive: true);
  }

  File? _readLastOpenedWorkspaceSync() {
    final pointerFile = File(lastOpenedWorkspacePath);
    if (!pointerFile.existsSync()) {
      return null;
    }

    final path = pointerFile.readAsStringSync().trim();
    if (path.isEmpty) {
      return null;
    }

    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }

    return file;
  }

  void _writeLastOpenedWorkspaceSync(String filePath) {
    _ensureAppConfigDirectory();
    File(lastOpenedWorkspacePath).writeAsStringSync(filePath);
  }

  bool _containsOnlySampleWorkspace(List<File> files) {
    if (files.isEmpty) {
      return false;
    }
    return files.every((file) => p.basename(file.path) == 'sample.yaml');
  }

  File _preferredWorkspaceFile(List<File> files) {
    final sorted = [...files]
      ..sort((left, right) {
        final leftIsSample = p.basename(left.path) == 'sample.yaml';
        final rightIsSample = p.basename(right.path) == 'sample.yaml';
        if (leftIsSample != rightIsSample) {
          return leftIsSample ? 1 : -1;
        }
        return right.lastModifiedSync().compareTo(left.lastModifiedSync());
      });
    return sorted.first;
  }

  void _deleteObsoleteWorkspaceFile(String? previousPath, String targetPath) {
    if (previousPath == null || previousPath == targetPath) {
      return;
    }
    if (!p.isWithin(workspaceDirectoryPath, previousPath) && p.normalize(previousPath) != p.normalize(targetPath)) {
      return;
    }

    final oldFile = File(previousPath);
    if (oldFile.existsSync()) {
      oldFile.deleteSync();
    }
  }
}
