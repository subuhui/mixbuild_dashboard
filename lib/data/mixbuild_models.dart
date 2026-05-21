import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';

enum BuildStatus {
  idle,
  validating,
  syncing,
  restoring,
  building,
  postHook,
  success,
  failed,
  interrupted,
}

extension BuildStatusX on BuildStatus {
  String get label {
    switch (this) {
      case BuildStatus.idle:
        return 'IDLE';
      case BuildStatus.validating:
        return 'VALIDATING';
      case BuildStatus.syncing:
        return 'SYNCING';
      case BuildStatus.restoring:
        return 'RESTORING';
      case BuildStatus.building:
        return 'BUILDING';
      case BuildStatus.postHook:
        return 'POST_HOOK';
      case BuildStatus.success:
        return 'SUCCESS';
      case BuildStatus.failed:
        return 'FAILED';
      case BuildStatus.interrupted:
        return 'INTERRUPTED';
    }
  }

  String get description {
    switch (this) {
      case BuildStatus.idle:
        return '等待指令下达';
      case BuildStatus.validating:
        return '校验构建参数与分支状态';
      case BuildStatus.syncing:
        return '同步依赖仓库和缓存';
      case BuildStatus.restoring:
        return '串行执行 restore_command，重建依赖树';
      case BuildStatus.building:
        return '执行构建命令并采集日志';
      case BuildStatus.postHook:
        return '执行构建后回调';
      case BuildStatus.success:
        return '全流程完成';
      case BuildStatus.failed:
        return '出现不可恢复错误，等待重新触发';
      case BuildStatus.interrupted:
        return '用户主动中断，需从 VALIDATING 重新开始';
    }
  }

  Color get color {
    switch (this) {
      case BuildStatus.idle:
        return MixBuildPalette.muted;
      case BuildStatus.validating:
        return MixBuildPalette.warning;
      case BuildStatus.syncing:
        return MixBuildPalette.tertiary;
      case BuildStatus.restoring:
        return MixBuildPalette.warning;
      case BuildStatus.building:
        return MixBuildPalette.primary;
      case BuildStatus.postHook:
        return MixBuildPalette.success;
      case BuildStatus.success:
        return MixBuildPalette.success;
      case BuildStatus.failed:
        return MixBuildPalette.error;
      case BuildStatus.interrupted:
        return MixBuildPalette.muted;
    }
  }

  bool get isPipelineActive => switch (this) {
        BuildStatus.validating ||
        BuildStatus.syncing ||
        BuildStatus.restoring ||
        BuildStatus.building ||
        BuildStatus.postHook => true,
        _ => false,
      };

  bool get controlsLocked => switch (this) {
        BuildStatus.validating ||
        BuildStatus.syncing ||
        BuildStatus.restoring ||
        BuildStatus.building ||
        BuildStatus.postHook => true,
        _ => false,
      };

  bool get canStop => switch (this) {
        BuildStatus.syncing ||
        BuildStatus.restoring ||
        BuildStatus.building => true,
        _ => false,
      };

  bool get canTrigger => !controlsLocked;

  String get triggerLabel => controlsLocked ? 'Loading…' : '开始构建任务';
}

class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
    required this.accent,
  });

  final String time;
  final String level;
  final String message;
  final Color accent;
}

class DependencyBranch {
  const DependencyBranch({
    required this.name,
    required this.branch,
    required this.icon,
    this.isOverride = false,
    this.highlight,
  });

  final String name;
  final String branch;
  final IconData icon;
  final bool isOverride;
  final Color? highlight;

  DependencyBranch copyWith({
    String? name,
    String? branch,
    IconData? icon,
    bool? isOverride,
    Color? highlight,
  }) {
    return DependencyBranch(
      name: name ?? this.name,
      branch: branch ?? this.branch,
      icon: icon ?? this.icon,
      isOverride: isOverride ?? this.isOverride,
      highlight: highlight ?? this.highlight,
    );
  }
}

class BuildScenario {
  const BuildScenario({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.environment,
    required this.mainBranch,
    required this.command,
    required this.status,
    required this.progress,
    required this.logs,
    required this.dependencies,
    required this.outputPath,
    required this.autoTag,
    required this.tagPrefix,
    this.yamlOverride = '',
  });

  final String id;
  final String name;
  final String subtitle;
  final String environment;
  final String mainBranch;
  final String command;
  final BuildStatus status;
  final double progress;
  final List<LogEntry> logs;
  final List<DependencyBranch> dependencies;
  final String outputPath;
  final bool autoTag;
  final String tagPrefix;
  final String yamlOverride;

  BuildScenario copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? environment,
    String? mainBranch,
    String? command,
    BuildStatus? status,
    double? progress,
    List<LogEntry>? logs,
    List<DependencyBranch>? dependencies,
    String? outputPath,
    bool? autoTag,
    String? tagPrefix,
    String? yamlOverride,
  }) {
    return BuildScenario(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      environment: environment ?? this.environment,
      mainBranch: mainBranch ?? this.mainBranch,
      command: command ?? this.command,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      logs: logs ?? this.logs,
      dependencies: dependencies ?? this.dependencies,
      outputPath: outputPath ?? this.outputPath,
      autoTag: autoTag ?? this.autoTag,
      tagPrefix: tagPrefix ?? this.tagPrefix,
      yamlOverride: yamlOverride ?? this.yamlOverride,
    );
  }
}

class ProjectBuild {
  const ProjectBuild({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.branch,
    required this.scenarios,
  });

  final String id;
  final String emoji;
  final String name;
  final String description;
  final String branch;
  final List<BuildScenario> scenarios;

  ProjectBuild copyWith({
    String? id,
    String? emoji,
    String? name,
    String? description,
    String? branch,
    List<BuildScenario>? scenarios,
  }) {
    return ProjectBuild(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      name: name ?? this.name,
      description: description ?? this.description,
      branch: branch ?? this.branch,
      scenarios: scenarios ?? this.scenarios,
    );
  }
}

class ResourceMetric {
  const ResourceMetric({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;
}

class WorkspaceBinding {
  const WorkspaceBinding({required this.projectName, required this.path});

  final String projectName;
  final String path;
}

class ProjectBindingConfig {
  const ProjectBindingConfig({
    required this.projectName,
    required this.path,
    required this.type,
    required this.defaultBranch,
    required this.restoreCommand,
    required this.isMainProject,
  });

  final String projectName;
  final String path;
  final MixbuildProjectType type;
  final String defaultBranch;
  final String? restoreCommand;
  final bool isMainProject;
}

class GlobalConfig {
  const GlobalConfig({
    required this.workspaceRoot,
    required this.activeProjectName,
    required this.bindings,
    this.mainProjectDefaultBranch = 'main',
  });

  final String workspaceRoot;
  final String activeProjectName;
  final List<WorkspaceBinding> bindings;
  final String mainProjectDefaultBranch;

  GlobalConfig copyWith({
    String? workspaceRoot,
    String? activeProjectName,
    List<WorkspaceBinding>? bindings,
    String? mainProjectDefaultBranch,
  }) {
    return GlobalConfig(
      workspaceRoot: workspaceRoot ?? this.workspaceRoot,
      activeProjectName: activeProjectName ?? this.activeProjectName,
      bindings: bindings ?? this.bindings,
      mainProjectDefaultBranch: mainProjectDefaultBranch ?? this.mainProjectDefaultBranch,
    );
  }
}