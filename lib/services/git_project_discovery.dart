import 'dart:io';

import 'package:path/path.dart' as p;

/// 发现的 Git 仓库信息，包含绝对路径和相对于工作区根目录的路径。
class DiscoveredGitProject {
  const DiscoveredGitProject({
    required this.name,
    required this.absolutePath,
    required this.relativePath,
  });

  final String name;
  final String absolutePath;
  final String relativePath;
}

/// 递归扫描工作区目录，发现所有包含 `.git` 的子仓库。
///
/// 最大扫描深度默认 3 层，忽略 `.git`、`build`、`node_modules` 等目录。
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

  String _relativePath(String workspaceRoot, String projectPath) {
    final relativePath = p.relative(projectPath, from: workspaceRoot);
    return relativePath == '.' ? p.basename(projectPath) : relativePath;
  }
}