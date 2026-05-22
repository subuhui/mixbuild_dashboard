import 'dart:io';

import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';

/// 分支发现结果，包含分支列表和可选的警告信息。
class GitBranchDiscoveryResult {
  const GitBranchDiscoveryResult({
    required this.branches,
    this.warningMessage,
  });

  final List<String> branches;
  final String? warningMessage;
}

/// Git 分支枚举服务，通过 `git for-each-ref` 发现本地和远程分支。
///
/// 执行前会先 `git fetch --all --prune` 同步远程引用。
/// 失败时回退到 ['develop', 'main', 'master'] 兜底列表。
class GitBranchDiscovery {
  GitBranchDiscovery({MixbuildCommandRunner? runner})
      : _runner = runner ?? ProcessRunCommandRunner();

  final MixbuildCommandRunner _runner;

  Future<GitBranchDiscoveryResult> discoverBranches(
    String repoPath, {
    String? preferredBranch,
  }) async {
    final normalizedPath = repoPath.trim();
    if (normalizedPath.isEmpty) {
      return GitBranchDiscoveryResult(branches: _fallbackBranches(preferredBranch));
    }

    final root = Directory(normalizedPath);
    if (!root.existsSync() || !Directory('$normalizedPath/.git').existsSync()) {
      return GitBranchDiscoveryResult(branches: _fallbackBranches(preferredBranch));
    }

    final gitExecutable = _resolveGitExecutable();
    CommandRunResult fetchResult;
    CommandRunResult currentBranchResult;
    CommandRunResult refResult;
    try {
      fetchResult = await _runner.runProcess(
        gitExecutable,
        <String>['-C', normalizedPath, 'fetch', '--all', '--prune'],
        workingDirectory: Directory.current.path,
      );
      currentBranchResult = await _runner.runProcess(
        gitExecutable,
        <String>['-C', normalizedPath, 'branch', '--show-current'],
        workingDirectory: Directory.current.path,
      );
      refResult = await _runner.runProcess(
        gitExecutable,
        <String>[
          '-C',
          normalizedPath,
          'for-each-ref',
          '--format=%(refname:short)',
          'refs/heads',
          'refs/remotes',
        ],
        workingDirectory: Directory.current.path,
      );
    } catch (error) {
      return GitBranchDiscoveryResult(
        branches: _fallbackBranches(preferredBranch),
        warningMessage: _buildExceptionWarningMessage(error),
      );
    }

    if (fetchResult.exitCode != 0 || refResult.exitCode != 0) {
      return GitBranchDiscoveryResult(
        branches: _fallbackBranches(preferredBranch),
        warningMessage: _buildWarningMessage(
          fetchResult,
          refResult,
          repoPath: normalizedPath,
        ),
      );
    }

    final currentBranch = currentBranchResult.stdout.trim();
    final branches = <String>{
      if (preferredBranch != null && preferredBranch.trim().isNotEmpty) preferredBranch.trim(),
      if (currentBranch.isNotEmpty) currentBranch,
    };

    for (final line in refResult.stdout.split('\n')) {
      final raw = line.trim();
      if (raw.isEmpty || raw.endsWith('/HEAD')) {
        continue;
      }
      final normalized = raw.contains('/') ? raw.split('/').skip(1).join('/') : raw;
      if (normalized.isNotEmpty) {
        branches.add(normalized);
      }
    }

    final sorted = branches.toList(growable: false)
      ..sort((left, right) {
        if (left == currentBranch) {
          return -1;
        }
        if (right == currentBranch) {
          return 1;
        }
        return left.compareTo(right);
      });
    return GitBranchDiscoveryResult(
      branches: sorted.isEmpty ? _fallbackBranches(preferredBranch) : sorted,
      warningMessage: currentBranchResult.exitCode == 0
          ? null
          : '已回退到兜底分支列表，请检查仓库权限或本地 Git 状态。',
    );
  }

  List<String> _fallbackBranches(String? preferredBranch) {
    return <String>{
      if (preferredBranch != null && preferredBranch.trim().isNotEmpty) preferredBranch.trim(),
      'develop',
      'main',
      'master',
    }.toList(growable: false);
  }

  String _buildWarningMessage(
    CommandRunResult fetchResult,
    CommandRunResult refResult,
    {
    required String repoPath,
  }
  ) {
    final raw = <String>[
      fetchResult.stderr.trim(),
      fetchResult.stdout.trim(),
      refResult.stderr.trim(),
      refResult.stdout.trim(),
    ].firstWhere(
      (item) => item.isNotEmpty,
      orElse: () => '分支列表拉取失败，已回退到兜底分支。',
    );
    if (_isPermissionDeniedMessage(raw)) {
      return _permissionDeniedMessage(repoPath);
    }
    final firstLine = raw.split('\n').first.trim();
    return firstLine.isEmpty
        ? '分支列表拉取失败，已回退到兜底分支。'
        : '分支列表拉取失败：$firstLine';
  }

  String _buildExceptionWarningMessage(Object error) {
    final raw = error.toString();
    if (_isPermissionDeniedMessage(raw)) {
      return '分支列表拉取失败：当前应用没有访问仓库目录的权限。请通过“浏览...”重新选择工作区目录后再刷新分支。';
    }
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.isEmpty) {
      return '分支列表拉取失败，已回退到兜底分支。';
    }
    return '分支列表拉取失败：$firstLine';
  }

  bool _isPermissionDeniedMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('operation not permitted') ||
        normalized.contains('permission denied');
  }

  String _permissionDeniedMessage(String repoPath) {
    return '分支列表拉取失败：当前应用没有访问仓库目录的权限。请通过“浏览...”重新选择包含 ${repoPath.split('/').last} 的工作区目录后再刷新分支。';
  }

  String _resolveGitExecutable() {
    final resolved = _runner.which('git');
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved;
    }
    for (final candidate in const <String>['/opt/homebrew/bin/git', '/usr/bin/git']) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return 'git';
  }
}