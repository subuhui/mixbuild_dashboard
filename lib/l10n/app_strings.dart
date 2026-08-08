import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/l10n/app_strings_en.dart';
import 'package:mixbuild_dashboard/l10n/app_strings_zh.dart';

abstract class AppStrings {
  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  String get appTitle;
  String get appTitleWithVersion;
  String get appBrand;
  String get appVersion;
  String get appVersionSubtitle;
  String appVersionWith(String v);
  String appTitleWithVersionWith(String v);
  String appVersionSubtitleWith(String v);

  String get navDashboard;
  String get navBuildLogs;
  String get navSettings;
  String get navNewProject;
  String get navSupport;
  String get navDocs;
  String get navOpenMenu;

  String get copyright;

  String get btnEdit;
  String get btnStop;
  String get btnStart;
  String get btnCancel;
  String get btnSave;
  String get btnBrowse;
  String get btnRefresh;
  String get btnReload;
  String get btnClose;
  String get btnAdd;
  String get btnDelete;
  String get btnRemove;
  String get btnConfirm;
  String get btnBack;
  String get btnView;

  String get projectEditorTitle;
  String get projectEditorSubtitle;
  String get projectEditorSave;
  String get projectNameLabel;
  String get projectEditTooltip;
  String get projectWorkspace;
  String get projectScenarios;
  String get projectNewTitle;
  String get projectNewAction;
  String get projectEditTitle;
  String get projectSaveConfig;
  String get projectYamlTitle;

  String get workspaceRoot;
  String get workspaceRootHint;
  String get workspaceRootSubtitle;
  String get workspaceSelect;
  String get workspaceScanInfo;
  String get workspaceAutoScan;
  String get pathLabel;
  String get pathHint;
  String get outputDir;
  String get outputPath;
  String get outputPathHint;

  String get mainProject;
  String get mainProjectBranch;
  String get mainProjectBinding;
  String get mainProjectBindingSubtitle;

  String get dependencyTopology;
  String get dependencyTopologyMatrix;
  String get dependencyBranchOverride;
  String get dependencyAddSelect;
  String get dependencyAddSelectTooltip;
  String get dependencyAddNone;
  String get dependencyAddItem;
  String get dependencyAddEmpty;
  String get dependencyAddEmptyHint;
  String get dependencyEmpty;
  String get dependencyEmptyHint;
  String get dependencyCount;
  String get dependencyModulePath;
  String get dependencyRemoveTooltip;
  String get dependencyRestoreCmd;
  String get dependencyDetected;
  String get dependencyDefault;
  String get dependencyOverride;

  String get scenarioConfig;
  String get scenarioMatrixEditor;
  String get scenarioMatrixEditorSubtitle;
  String get scenarioAddNew;
  String get scenarioConfirmAdd;
  String get gitBranchesLoading;
  String get scenarioName;
  String get scenarioNameHint;
  String get scenarioCommand;
  String get scenarioCommandHint;
  String get scenarioDefaultUpdateDescription;
  String get scenarioDefaultUpdateDescriptionHint;
  String get buildUpdateDescription;
  String get buildUpdateDescriptionHint;
  String get scenarioCleanBefore;
  String get scenarioCleanBeforeShort;
  String get scenarioMainBranch;
  String get scenarioMainBranchSubtitle;
  String get scenarioUnnamed;
  String get scenarioNoCommand;
  String get scenarioEditTooltip;
  String get scenarioDeleteTooltip;
  String get scenarioDefaultName;
  String get scenarioDefaultSubtitle;
  String get scenarioCreatedLog;

  String get statusIdle;
  String get statusValidating;
  String get statusSyncing;
  String get statusRestoring;
  String get statusBuilding;
  String get statusPostHook;
  String get statusSuccess;
  String get statusFailed;
  String get statusInterrupted;

  String get statusIdleDesc;
  String get statusValidatingDesc;
  String get statusSyncingDesc;
  String get statusRestoringDesc;
  String get statusBuildingDesc;
  String get statusPostHookDesc;
  String get statusSuccessDesc;
  String get statusFailedDesc;
  String get statusInterruptedDesc;

  String get triggerLabel;
  String get loadingLabel;

  String get currentStatus;
  String get runningStatus;
  String get failedStatus;
  String get readyStatus;
  String get connectedStatus;
  String get parallelRunning;

  String get buildLogsTitle;
  String get buildLogsSubtitle;
  String get buildLogsEmpty;
  String get buildLogsEmptyDetail;
  String get buildLogsNoMatch;
  String get buildLogsSelectRecord;
  String get buildLogsNoLogs;
  String get buildLogsBranch;
  String get buildLogsStart;
  String get buildLogsStartFinish;
  String get buildLogsSearchHint;
  String get logDownloadTooltip;

  String get yamlEditorTitle;
  String get yamlEditorSubtitle;
  String get yamlEditorFilename;
  String get yamlEditorFooter;
  String get yamlEditorCancel;
  String get yamlEditorSave;
  String get yamlOverride;
  String get yamlOverrideTitle;
  String get yamlReload;
  String get yamlOpen;
  String get yamlGlobalConfig;
  String get yamlCopied;
  String get yamlDiscardTitle;
  String get yamlDiscardMessage;
  String get yamlDiscard;

  String get globalConfigTitle;
  String get settingsAppearanceTitle;
  String get settingsAppearanceSubtitle;
  String get settingsThemeSystem;
  String get settingsThemeLight;
  String get settingsThemeDark;
  String get settingsThemeSectionNote;

  String get advancedOptions;
  String get advancedOptionsSubtitle;

  String get autoTag;
  String get autoTagTitle;
  String get autoTagDesc;
  String get tagPrefix;
  String get tagPrefixHint;
  String get autoTagEnabled;
  String get autoTagDisabled;

  String get scenarioTarget;

  String get mainBranchLabel;
  String get nodesLabel;
  String get zshTerminalTitle;

  String get settingsDataTitle;
  String get settingsDataSubtitle;
  String get settingsExport;
  String get settingsExportDesc;
  String get settingsImport;
  String get settingsImportDesc;
  String get settingsImportConfirmTitle;
  String get settingsImportConfirmMessage;
  String exportSuccess(int count);
  String exportError(String error);
  String importSuccess(int count);
  String importError(String error);

  String get settingsClearLogs;
  String get settingsClearLogsDesc;
  String get settingsClearLogsConfirmTitle;
  String get settingsClearLogsConfirmMessage;
  String settingsClearLogsSuccess(int count);
  String settingsClearLogsError(String error);

  String get settingsServerTitle;
  String get settingsServerSubtitle;
  String get settingsServerPortLabel;
  String get settingsServerPortHint;
  String get settingsServerPortInvalid;
  String get settingsServerPortSave;
  String get settingsServerPortSuccess;
  String get settingsServerStatus;
  String get settingsServerRunning;
  String get settingsServerStopped;
  String get settingsServerCurlExample;
  String get settingsServerCurlProject;
  String get settingsServerCurlScenario;
  String get settingsServerCurlCopied;

  String yamlSaveError(String error);
  String dirAccessError(String error);
  String scanError(String error);
  String projectAlreadySelected(String name);
  String projectAlreadyInConfig(String name);
  String logSaved(String path);
  String noLogMatch(String query);
  String readyForCommand(String name);
  String discoveredGitProjects(int count);
  String dependencyCountInfo(int count);
  String availableCount(int count);
  String mainProjectBranchInfo(String branch);
  String parallelRunningCount(int count);
  String failedCount(int count);
  String runningCount(int count);
  String branchInfo(String branch);
  String terminalTitle(String command, String project);
  String dependenciesDetected(int count);
  String buildLogsShowingLatest(int visible, int total);
  String buildLogsShowingMatches(int visible, int total);
  String buildLogsLoadOlder(int count);
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'zh':
        return AppStringsZh();
      case 'en':
      default:
        return AppStringsEn();
    }
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
