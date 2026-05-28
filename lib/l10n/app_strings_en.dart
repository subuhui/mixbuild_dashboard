import 'package:mixbuild_dashboard/l10n/app_strings.dart';

class AppStringsEn extends AppStrings {
  // App
  @override
  String get appTitle => 'MixBuild Dashboard';
  @override
  String get appTitleWithVersion => 'MixBuild Dashboard v1.0';
  @override
  String get appBrand => 'MixBuild';
  @override
  String get appVersion => 'v1.0.0-stable';
  @override
  String get appVersionSubtitle => 'v1.0.0-stable · Flutter Desktop / macOS';

  // Navigation
  @override
  String get navDashboard => 'Dashboard';
  @override
  String get navBuildLogs => 'Build Logs';
  @override
  String get navSettings => 'Settings';
  @override
  String get navNewProject => 'New Project';
  @override
  String get navSupport => 'Support';
  @override
  String get navDocs => 'Docs';
  @override
  String get navOpenMenu => 'Open navigation';

  // Copyright
  @override
  String get copyright => '© 2026 MixBuild Systems';

  // Common buttons
  @override
  String get btnEdit => 'Edit';
  @override
  String get btnStop => 'Stop';
  @override
  String get btnStart => 'Start';
  @override
  String get btnCancel => 'Cancel';
  @override
  String get btnSave => 'Save';
  @override
  String get btnBrowse => 'Browse...';
  @override
  String get btnRefresh => 'Refresh';
  @override
  String get btnReload => 'Reload';
  @override
  String get btnClose => 'Close';
  @override
  String get btnAdd => 'Add';
  @override
  String get btnDelete => 'Delete';
  @override
  String get btnRemove => 'Remove';
  @override
  String get btnConfirm => 'Confirm';
  @override
  String get btnBack => 'Back';
  @override
  String get btnView => 'View';

  // Project editor
  @override
  String get projectEditorTitle => 'Project Configuration';
  @override
  String get projectEditorSubtitle =>
      'Visual editor for workspace, main project binding, dependency topology, and build scenario matrix';
  @override
  String get projectEditorSave => 'Save Project Config';
  @override
  String get projectNameLabel => 'Project Name';
  @override
  String get projectEditTooltip => 'Edit Project';
  @override
  String get projectWorkspace => 'Project Workspace';
  @override
  String get projectScenarios => 'Build Scenarios';
  @override
  String get projectNewTitle => 'New Project';
  @override
  String get projectNewAction => 'Create Project';
  @override
  String get projectEditTitle => 'Edit Project';
  @override
  String get projectSaveConfig => 'Save Project Config';
  @override
  String get projectYamlTitle => 'Current Project YAML';

  // Workspace & paths
  @override
  String get workspaceRoot => 'Workspace Root';
  @override
  String get workspaceRootHint => 'Enter root path to auto-scan Git projects';
  @override
  String get workspaceRootSubtitle =>
      'Enter root path or scan Git repos via system directory picker';
  @override
  String get workspaceSelect => 'Select Workspace';
  @override
  String get workspaceScanInfo =>
      'After entering or selecting a workspace, Git repos in the root and subdirectories will be auto-scanned; directories without permission will be skipped.';
  @override
  String get workspaceAutoScan =>
      'Auto-scan Git projects after entering root path';
  @override
  String get pathLabel => 'Path';
  @override
  String get pathHint => 'Select or enter relative path';
  @override
  String get outputDir => 'Output Directory';
  @override
  String get outputPath => 'Output Path';
  @override
  String get outputPathHint => '';

  // Main project
  @override
  String get mainProject => 'Main Project';
  @override
  String get mainProjectBranch => 'Main Project Branch';
  @override
  String get mainProjectBinding => 'Main Project Binding';
  @override
  String get mainProjectBindingSubtitle =>
      'Configure main project path and default branch';

  // Dependencies
  @override
  String get dependencyTopology => 'Dependency Topology';
  @override
  String get dependencyTopologyMatrix => 'Dependency Topology Matrix';
  @override
  String get dependencyBranchOverride => 'Dependency Branch Override';
  @override
  String get dependencyAddSelect => 'Select to Add Dependency';
  @override
  String get dependencyAddSelectTooltip => 'Select to Add Dependency';
  @override
  String get dependencyAddNone => 'No available dependencies';
  @override
  String get dependencyAddItem => 'Select to Add Dependency';
  @override
  String get dependencyAddEmpty => 'No projects available to add in workspace.';
  @override
  String get dependencyAddEmptyHint =>
      'Click "Select to Add Dependency" in the top right to choose modules from workspace scan results.';
  @override
  String get dependencyEmpty =>
      'No dependencies yet. Use "Select to Add Dependency" to generate editable dependency rows.';
  @override
  String get dependencyEmptyHint => '';
  @override
  String get dependencyCount => 'Dependencies';
  @override
  String get dependencyModulePath => 'Select module path';
  @override
  String get dependencyRemoveTooltip => 'Remove Dependency';
  @override
  String get dependencyRestoreCmd => 'restore command';
  @override
  String get dependencyDetected => 'Dependencies Detected';
  @override
  String get dependencyDefault => 'Default';
  @override
  String get dependencyOverride => 'Override';

  // Build scenarios
  @override
  String get scenarioConfig => 'Build Scenario Configuration';
  @override
  String get scenarioMatrixEditor => 'Build Scenario Matrix Editor';
  @override
  String get scenarioMatrixEditorSubtitle =>
      'Maintain commands, dependency branch overrides, output directories, and auto-tag policies';
  @override
  String get scenarioAddNew => 'New Build Scenario';
  @override
  String get scenarioConfirmAdd => 'Confirm New Scenario';
  @override
  String get scenarioName => 'Scenario Name';
  @override
  String get scenarioNameHint => '';
  @override
  String get scenarioCommand => 'Build Command';
  @override
  String get scenarioCommandHint => '';
  @override
  String get scenarioCleanBefore => 'Force clean before build (--clean)';
  @override
  String get scenarioCleanBeforeShort => 'Clean before build (--clean)';
  @override
  String get scenarioMainBranch => 'Main Project Branch';
  @override
  String get scenarioMainBranchSubtitle =>
      'Confirm main project default Git branch when adding new scenario';
  @override
  String get scenarioUnnamed => 'Unnamed Scenario';
  @override
  String get scenarioNoCommand => 'No command configured';
  @override
  String get scenarioEditTooltip => 'Edit Scenario';
  @override
  String get scenarioDeleteTooltip => 'Delete Scenario';
  @override
  String get scenarioDefaultName => 'New Scenario';
  @override
  String get scenarioDefaultSubtitle => 'Manually added scenario';
  @override
  String get scenarioCreatedLog => 'Scenario created and waiting for execution';

  // Build status
  @override
  String get statusIdle => 'IDLE';
  @override
  String get statusValidating => 'VALIDATING';
  @override
  String get statusSyncing => 'SYNCING';
  @override
  String get statusRestoring => 'RESTORING';
  @override
  String get statusBuilding => 'BUILDING';
  @override
  String get statusPostHook => 'POST_HOOK';
  @override
  String get statusSuccess => 'SUCCESS';
  @override
  String get statusFailed => 'FAILED';
  @override
  String get statusInterrupted => 'INTERRUPTED';

  @override
  String get statusIdleDesc => 'Waiting for command';
  @override
  String get statusValidatingDesc =>
      'Validating build parameters and branch status';
  @override
  String get statusSyncingDesc => 'Syncing dependency repos and cache';
  @override
  String get statusRestoringDesc =>
      'Executing restore_command serially, rebuilding dependency tree';
  @override
  String get statusBuildingDesc =>
      'Executing build command and collecting logs';
  @override
  String get statusPostHookDesc => 'Executing post-build hooks';
  @override
  String get statusSuccessDesc => 'Full pipeline completed';
  @override
  String get statusFailedDesc => 'Unrecoverable error, waiting for retrigger';
  @override
  String get statusInterruptedDesc =>
      'User interrupted, needs to restart from VALIDATING';

  @override
  String get triggerLabel => 'Start Build Task';
  @override
  String get loadingLabel => 'Loading…';

  // Build status labels
  @override
  String get currentStatus => 'Current Status';
  @override
  String get runningStatus => 'Running';
  @override
  String get failedStatus => 'Failed';
  @override
  String get readyStatus => 'Ready';
  @override
  String get connectedStatus => 'Connected';
  @override
  String get parallelRunning => 'Parallel Running';

  // Build logs
  @override
  String get buildLogsTitle => 'Build Logs';
  @override
  String get buildLogsSubtitle => 'Execution history and log list';
  @override
  String get buildLogsEmpty => 'No build history';
  @override
  String get buildLogsEmptyDetail => 'No execution records yet';
  @override
  String get buildLogsNoMatch => 'No logs match';
  @override
  String get buildLogsSelectRecord => 'Please select a task record';
  @override
  String get buildLogsNoLogs => 'No logs for current task';
  @override
  String get buildLogsBranch => 'Branch';
  @override
  String get buildLogsStart => 'Started at';
  @override
  String get buildLogsStartFinish => 'Started at · Finished at';

  // YAML editor
  @override
  String get yamlEditorTitle => 'YAML Configuration Override';
  @override
  String get yamlEditorSubtitle =>
      'Edit YAML override content and apply to current workspace config';
  @override
  String get yamlEditorFilename => 'mixbuild.config.yaml';
  @override
  String get yamlEditorFooter =>
      'All changes will be saved to current workspace YAML.';
  @override
  String get yamlEditorCancel => 'Cancel';
  @override
  String get yamlEditorSave => 'Save Configuration';
  @override
  String get yamlOverride => 'Override';
  @override
  String get yamlOverrideTitle => 'YAML Configuration Override';
  @override
  String get yamlReload => 'Reload YAML';
  @override
  String get yamlOpen => 'Open YAML';
  @override
  String get yamlGlobalConfig => 'Global Config';

  // Global config
  @override
  String get globalConfigTitle => 'Global Configuration';
  @override
  String get settingsAppearanceTitle => 'Appearance';
  @override
  String get settingsAppearanceSubtitle =>
      'Choose the app theme. Your selection is saved locally.';
  @override
  String get settingsThemeSystem => 'Follow System';
  @override
  String get settingsThemeLight => 'Light Material 3';
  @override
  String get settingsThemeDark => 'Dark Material 3';
  @override
  String get settingsThemeSectionNote =>
      'Theme changes take effect immediately and are restored on next launch.';

  // Advanced options
  @override
  String get advancedOptions => 'Advanced Options';
  @override
  String get advancedOptionsSubtitle =>
      'Configure output directory and auto-tag behavior after successful build';

  // Auto tag
  @override
  String get autoTag => 'Auto Tag';
  @override
  String get autoTagTitle => 'Auto Tag';
  @override
  String get autoTagDesc => 'Auto-apply Git Tag after successful build';
  @override
  String get tagPrefix => 'Tag Prefix';
  @override
  String get tagPrefixHint => '';
  @override
  String get autoTagEnabled => 'Enabled';
  @override
  String get autoTagDisabled => 'Disabled';

  // Scenario preview
  @override
  String get scenarioTarget => 'Target';

  // Misc
  @override
  String get mainBranchLabel => 'Main Branch';
  @override
  String get nodesLabel => 'NODES';
  @override
  String get zshTerminalTitle => 'zsh';

  // Error messages
  @override
  String yamlSaveError(String error) => 'YAML save failed: $error';
  @override
  String dirAccessError(String error) =>
      'Directory access request failed: $error';
  @override
  String scanError(String error) => 'Scan failed: $error';
  @override
  String projectAlreadySelected(String name) =>
      'Project $name is already selected, no need to add again.';
  @override
  String projectAlreadyInConfig(String name) =>
      'Project $name is already in current config.';
  @override
  String logSaved(String path) => 'Full log saved: $path';
  @override
  String noLogMatch(String query) => 'No logs match "$query"';
  @override
  String readyForCommand(String name) =>
      'Ready to receive build command for project: $name';
  @override
  String discoveredGitProjects(int count) =>
      'Discovered $count Git projects for main project and dependency path selection.';
  @override
  String dependencyCountInfo(int count) =>
      'Auto-resolving $count modules, with adjustable paths, branches, and restore commands';
  @override
  String availableCount(int count) => '$count available';
  @override
  String mainProjectBranchInfo(String branch) => 'Main: $branch';
  @override
  String parallelRunningCount(int count) => 'Parallel Running: $count';
  @override
  String failedCount(int count) => 'Failed $count';
  @override
  String runningCount(int count) => 'Running $count';
  @override
  String branchInfo(String branch) => 'Branch: $branch';
  @override
  String terminalTitle(String command, String project) =>
      'zsh — $command — $project';
  @override
  String dependenciesDetected(int count) => '$count Dependencies Detected';
  @override
  String buildLogsShowingLatest(int visible, int total) =>
      'Showing latest $visible of $total logs';
  @override
  String buildLogsShowingMatches(int visible, int total) =>
      'Showing $visible of $total matching logs';
  @override
  String buildLogsLoadOlder(int count) => 'Load older ($count)';
}
