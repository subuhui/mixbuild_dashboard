import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';

/// 构建流水线生命周期状态。
///
/// 有序流转：idle → validating → syncing → restoring → building → postHook → success。
/// 终态包括 [success]、[failed]、[interrupted]。
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

/// [BuildStatus] 的 UI 扩展：标签、描述、颜色、流转控制属性。
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
        BuildStatus.postHook =>
          true,
        _ => false,
      };

  bool get controlsLocked => switch (this) {
        BuildStatus.validating ||
        BuildStatus.syncing ||
        BuildStatus.restoring ||
        BuildStatus.building ||
        BuildStatus.postHook =>
          true,
        _ => false,
      };

  bool get canStop => switch (this) {
        BuildStatus.syncing ||
        BuildStatus.restoring ||
        BuildStatus.building =>
          true,
        _ => false,
      };

  bool get canTrigger => !controlsLocked;

  String get triggerLabel => controlsLocked ? 'Loading…' : '开始构建任务';
}

/// 构建日志条目，包含时间戳、级别、消息文本和主题色。
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

/// 依赖仓库的分支信息，用于 UI 展示和分支切换。
///
/// [isOverride] 标记该分支是否为场景级覆盖（非默认分支），
/// [highlight] 用于在 UI 中高亮显示被覆盖的依赖。
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

/// 构建场景的运行时状态，包含当前进度、日志和依赖分支快照。
///
/// 与 [MixbuildScenarioConfig]（YAML 配置层）不同，本类持有运行时动态数据
/// （status、progress、logs），是 UI 层直接消费的对象。
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

/// 单个项目的构建实例，持有该项目下所有 [BuildScenario] 列表。
///
/// [id] 对应 YAML 配置文件的绝对路径，用于跨配置文件的项目唯一标识。
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

/// 底栏系统资源指标（CPU / MEM / Queue），用于仪表盘 HUD 展示。
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

/// 工作区绑定关系：将项目名映射到其在工作区根目录下的相对路径。
///
/// 用于全局配置面板展示和编辑，与 YAML 中的 main_project / dependencies 对应。
class WorkspaceBinding {
  const WorkspaceBinding({
    required this.projectName,
    required this.path,
    this.type,
    this.defaultBranch,
    this.restoreCommand,
  });

  final String projectName;
  final String path;
  final MixbuildProjectType? type;
  final String? defaultBranch;
  final String? restoreCommand;
}

/// 项目编辑器中的绑定配置，比 [WorkspaceBinding] 多了 [isMainProject] 标记。
///
/// 用于 [ProjectEditorPage] 的表单提交，区分主项目和依赖项。
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

/// 全局工作区配置，聚合了工作区根路径、活跃项目名和所有绑定关系。
///
/// 由 [DashboardController] 从 [MixbuildConfig] 派生，供 UI 全局配置面板消费。
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
      mainProjectDefaultBranch:
          mainProjectDefaultBranch ?? this.mainProjectDefaultBranch,
    );
  }
}
