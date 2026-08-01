import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';

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
        return 'Waiting for command';
      case BuildStatus.validating:
        return 'Validating build parameters and branch state';
      case BuildStatus.syncing:
        return 'Syncing dependency repositories and caches';
      case BuildStatus.restoring:
        return 'Running restore_command serially and rebuilding dependencies';
      case BuildStatus.building:
        return 'Running build command and collecting logs';
      case BuildStatus.postHook:
        return 'Running post-build hooks';
      case BuildStatus.success:
        return 'Pipeline completed';
      case BuildStatus.failed:
        return 'Failed with an unrecoverable error';
      case BuildStatus.interrupted:
        return 'Interrupted by user; restart from VALIDATING';
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

  String get triggerLabel => controlsLocked ? 'Loading...' : 'Start build task';

  String labelWithContext(BuildContext context) {
    final strings = AppStrings.of(context);
    switch (this) {
      case BuildStatus.idle:
        return strings.statusIdle;
      case BuildStatus.validating:
        return strings.statusValidating;
      case BuildStatus.syncing:
        return strings.statusSyncing;
      case BuildStatus.restoring:
        return strings.statusRestoring;
      case BuildStatus.building:
        return strings.statusBuilding;
      case BuildStatus.postHook:
        return strings.statusPostHook;
      case BuildStatus.success:
        return strings.statusSuccess;
      case BuildStatus.failed:
        return strings.statusFailed;
      case BuildStatus.interrupted:
        return strings.statusInterrupted;
    }
  }

  String descriptionWithContext(BuildContext context) {
    final strings = AppStrings.of(context);
    switch (this) {
      case BuildStatus.idle:
        return strings.statusIdleDesc;
      case BuildStatus.validating:
        return strings.statusValidatingDesc;
      case BuildStatus.syncing:
        return strings.statusSyncingDesc;
      case BuildStatus.restoring:
        return strings.statusRestoringDesc;
      case BuildStatus.building:
        return strings.statusBuildingDesc;
      case BuildStatus.postHook:
        return strings.statusPostHookDesc;
      case BuildStatus.success:
        return strings.statusSuccessDesc;
      case BuildStatus.failed:
        return strings.statusFailedDesc;
      case BuildStatus.interrupted:
        return strings.statusInterruptedDesc;
    }
  }

  String triggerLabelWithContext(BuildContext context) {
    final strings = AppStrings.of(context);
    return controlsLocked ? strings.loadingLabel : strings.triggerLabel;
  }
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'time': time,
      'level': level,
      'message': message,
      'accent': accent.toARGB32(),
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      time: json['time'] as String? ?? '',
      level: json['level'] as String? ?? 'INFO',
      message: json['message'] as String? ?? '',
      accent:
          Color((json['accent'] as num?)?.toInt() ?? Colors.white.toARGB32()),
    );
  }
}

class BuildExecutionRecord {
  const BuildExecutionRecord({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.scenarioId,
    required this.scenarioName,
    required this.command,
    required this.branch,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    this.logs = const <LogEntry>[],
  });

  final String id;
  final String projectId;
  final String projectName;
  final String scenarioId;
  final String scenarioName;
  final String command;
  final String branch;
  final BuildStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<LogEntry> logs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'projectId': projectId,
      'projectName': projectName,
      'scenarioId': scenarioId,
      'scenarioName': scenarioName,
      'command': command,
      'branch': branch,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'logs': logs.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  factory BuildExecutionRecord.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['logs'];
    return BuildExecutionRecord(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      projectName: json['projectName'] as String? ?? '',
      scenarioId: json['scenarioId'] as String? ?? '',
      scenarioName: json['scenarioName'] as String? ?? '',
      command: json['command'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      status: _buildStatusFromName(json['status'] as String?),
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      finishedAt: DateTime.tryParse(json['finishedAt'] as String? ?? ''),
      logs: rawLogs is List
          ? rawLogs
              .whereType<Map>()
              .map(
                (entry) => LogEntry.fromJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .toList(growable: false)
          : const <LogEntry>[],
    );
  }

  BuildExecutionRecord copyWith({
    String? id,
    String? projectId,
    String? projectName,
    String? scenarioId,
    String? scenarioName,
    String? command,
    String? branch,
    BuildStatus? status,
    DateTime? startedAt,
    Object? finishedAt = _buildExecutionSentinel,
    List<LogEntry>? logs,
  }) {
    return BuildExecutionRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      scenarioId: scenarioId ?? this.scenarioId,
      scenarioName: scenarioName ?? this.scenarioName,
      command: command ?? this.command,
      branch: branch ?? this.branch,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt == _buildExecutionSentinel
          ? this.finishedAt
          : finishedAt as DateTime?,
      logs: logs ?? this.logs,
    );
  }
}

BuildStatus _buildStatusFromName(String? name) {
  if (name == null || name.trim().isEmpty) {
    return BuildStatus.idle;
  }
  for (final status in BuildStatus.values) {
    if (status.name == name) {
      return status;
    }
  }
  return BuildStatus.idle;
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
    this.defaultUpdateDescription = '',
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
  final String defaultUpdateDescription;
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
    String? defaultUpdateDescription,
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
      defaultUpdateDescription:
          defaultUpdateDescription ?? this.defaultUpdateDescription,
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
    required this.type,
  });

  final String id;
  final String emoji;
  final String name;
  final String description;
  final String branch;
  final List<BuildScenario> scenarios;
  final MixbuildProjectType type;

  ProjectBuild copyWith({
    String? id,
    String? emoji,
    String? name,
    String? description,
    String? branch,
    List<BuildScenario>? scenarios,
    MixbuildProjectType? type,
  }) {
    return ProjectBuild(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      name: name ?? this.name,
      description: description ?? this.description,
      branch: branch ?? this.branch,
      scenarios: scenarios ?? this.scenarios,
      type: type ?? this.type,
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
  const WorkspaceBinding({
    required this.projectName,
    required this.path,
    this.type,
    this.restoreCommand,
  });

  final String projectName;
  final String path;
  final MixbuildProjectType? type;
  final String? restoreCommand;
}

class ProjectBindingConfig {
  const ProjectBindingConfig({
    required this.projectName,
    required this.path,
    required this.type,
    required this.restoreCommand,
    required this.isMainProject,
  });

  final String projectName;
  final String path;
  final MixbuildProjectType type;
  final String? restoreCommand;
  final bool isMainProject;
}

const Object _buildExecutionSentinel = Object();

class GlobalConfig {
  const GlobalConfig({
    required this.workspaceRoot,
    required this.activeProjectName,
    required this.bindings,
  });

  final String workspaceRoot;
  final String activeProjectName;
  final List<WorkspaceBinding> bindings;

  GlobalConfig copyWith({
    String? workspaceRoot,
    String? activeProjectName,
    List<WorkspaceBinding>? bindings,
  }) {
    return GlobalConfig(
      workspaceRoot: workspaceRoot ?? this.workspaceRoot,
      activeProjectName: activeProjectName ?? this.activeProjectName,
      bindings: bindings ?? this.bindings,
    );
  }
}
