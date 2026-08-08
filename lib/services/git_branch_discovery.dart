import 'dart:io';

import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';

class GitBranchDiscoveryResult {
  const GitBranchDiscoveryResult({required this.branches, this.warningMessage});

  final List<String> branches;
  final String? warningMessage;
}

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
      return GitBranchDiscoveryResult(
        branches: _fallbackBranches(preferredBranch),
      );
    }

    final root = Directory(normalizedPath);
    if (!root.existsSync() || !Directory('$normalizedPath/.git').existsSync()) {
      return GitBranchDiscoveryResult(
        branches: _fallbackBranches(preferredBranch),
      );
    }

    final gitExecutable = _resolveGitExecutable();
    CommandRunResult fetchResult;
    CommandRunResult currentBranchResult;
    CommandRunResult refResult;
    try {
      fetchResult = await _runner.runProcess(gitExecutable, <String>[
        '-C',
        normalizedPath,
        'fetch',
        '--all',
        '--prune',
      ], workingDirectory: Directory.current.path);
      currentBranchResult = await _runner.runProcess(gitExecutable, <String>[
        '-C',
        normalizedPath,
        'branch',
        '--show-current',
      ], workingDirectory: Directory.current.path);
      refResult = await _runner.runProcess(gitExecutable, <String>[
        '-C',
        normalizedPath,
        'for-each-ref',
        '--format=%(refname)',
        'refs/heads',
        'refs/remotes',
      ], workingDirectory: Directory.current.path);
    } catch (error) {
      return GitBranchDiscoveryResult(
        branches: _fallbackBranches(preferredBranch),
        warningMessage: _buildExceptionWarningMessage(error),
      );
    }

    if (refResult.exitCode != 0) {
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
      if (preferredBranch != null && preferredBranch.trim().isNotEmpty)
        preferredBranch.trim(),
      if (currentBranch.isNotEmpty) currentBranch,
    };

    for (final line in refResult.stdout.split('\n')) {
      final raw = line.trim();
      if (raw.startsWith('refs/heads/')) {
        branches.add(raw.substring('refs/heads/'.length));
        continue;
      }
      if (!raw.startsWith('refs/remotes/')) {
        continue;
      }
      final remoteRef = raw.substring('refs/remotes/'.length);
      final separator = remoteRef.indexOf('/');
      if (separator == -1) {
        continue;
      }
      final branch = remoteRef.substring(separator + 1);
      if (branch.isNotEmpty && branch != 'HEAD') {
        branches.add(branch);
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
      warningMessage: fetchResult.exitCode != 0
          ? _buildWarningMessage(
              fetchResult,
              refResult,
              repoPath: normalizedPath,
            )
          : currentBranchResult.exitCode == 0
          ? null
          : 'Branch discovery could not determine the current branch; local refs are still available.',
    );
  }

  List<String> _fallbackBranches(String? preferredBranch) {
    return <String>{
      if (preferredBranch != null && preferredBranch.trim().isNotEmpty)
        preferredBranch.trim(),
      'develop',
      'main',
      'master',
    }.toList(growable: false);
  }

  String _buildWarningMessage(
    CommandRunResult fetchResult,
    CommandRunResult refResult, {
    required String repoPath,
  }) {
    final raw =
        <String>[
          fetchResult.stderr.trim(),
          fetchResult.stdout.trim(),
          refResult.stderr.trim(),
          refResult.stdout.trim(),
        ].firstWhere(
          (item) => item.isNotEmpty,
          orElse: () =>
              'Branch discovery failed. Fell back to default branches.',
        );
    if (_isPermissionDeniedMessage(raw)) {
      return _permissionDeniedMessage(repoPath);
    }
    final firstLine = raw.split('\n').first.trim();
    return firstLine.isEmpty
        ? 'Branch discovery failed. Fell back to default branches.'
        : 'Branch discovery failed: $firstLine';
  }

  String _buildExceptionWarningMessage(Object error) {
    final raw = error.toString();
    if (_isPermissionDeniedMessage(raw)) {
      return 'Branch discovery failed: the app cannot access the repository directory. Re-select the workspace directory with Browse, then refresh branches.';
    }
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.isEmpty) {
      return 'Branch discovery failed. Fell back to default branches.';
    }
    return 'Branch discovery failed: $firstLine';
  }

  bool _isPermissionDeniedMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('operation not permitted') ||
        normalized.contains('permission denied');
  }

  String _permissionDeniedMessage(String repoPath) {
    return 'Branch discovery failed: the app cannot access the repository directory. Re-select the workspace directory containing ${repoPath.split('/').last}, then refresh branches.';
  }

  String _resolveGitExecutable() {
    final resolved = _runner.which('git');
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved;
    }
    for (final candidate in const <String>[
      '/opt/homebrew/bin/git',
      '/usr/bin/git',
    ]) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return 'git';
  }
}
