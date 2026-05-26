import 'package:mixbuild_dashboard/l10n/app_strings.dart';

class AppStringsZh extends AppStrings {
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
  String get navDashboard => '仪表盘';
  @override
  String get navBuildLogs => '构建日志';
  @override
  String get navSettings => '设置';
  @override
  String get navNewProject => '新增项目';
  @override
  String get navSupport => '支持';
  @override
  String get navDocs => '文档';
  @override
  String get navOpenMenu => '打开导航';

  // Copyright
  @override
  String get copyright => '© 2026 MixBuild Systems';

  // Common buttons
  @override
  String get btnEdit => '编辑';
  @override
  String get btnStop => '停止';
  @override
  String get btnStart => '开始';
  @override
  String get btnCancel => '取消';
  @override
  String get btnSave => '保存';
  @override
  String get btnBrowse => '浏览...';
  @override
  String get btnRefresh => '刷新';
  @override
  String get btnReload => '重载';
  @override
  String get btnClose => '关闭';
  @override
  String get btnAdd => '新增';
  @override
  String get btnDelete => '删除';
  @override
  String get btnRemove => '移除';
  @override
  String get btnConfirm => '确认';
  @override
  String get btnBack => '返回';
  @override
  String get btnView => '查看';

  // Project editor
  @override
  String get projectEditorTitle => '工程配置中心';
  @override
  String get projectEditorSubtitle => '可视化编辑工作区、主工程绑定、依赖拓扑和构建场景矩阵';
  @override
  String get projectEditorSave => '保存项目配置';
  @override
  String get projectNameLabel => '工程名称';
  @override
  String get projectEditTooltip => '编辑项目';
  @override
  String get projectWorkspace => '项目工作区';
  @override
  String get projectScenarios => '构建场景';
  @override
  String get projectNewTitle => '新增项目';
  @override
  String get projectNewAction => '创建项目';
  @override
  String get projectEditTitle => '项目编辑';
  @override
  String get projectSaveConfig => '保存项目配置';
  @override
  String get projectYamlTitle => '当前项目 YAML';

  // Workspace & paths
  @override
  String get workspaceRoot => '工作区根路径';
  @override
  String get workspaceRootHint => '输入根路径后自动扫描 Git 项目';
  @override
  String get workspaceRootSubtitle => '输入根路径或通过系统目录选择器扫描 Git 仓库';
  @override
  String get workspaceSelect => '选择工作区';
  @override
  String get workspaceScanInfo =>
      '输入或选择工作区后，将自动扫描根目录及子目录中的 Git 仓库；遇到无权限目录会自动跳过。';
  @override
  String get workspaceAutoScan => '输入根路径后自动扫描 Git 项目';
  @override
  String get pathLabel => '路径选择';
  @override
  String get pathHint => '选择或输入相对路径';
  @override
  String get outputDir => '输出目录';
  @override
  String get outputPath => '输出路径';
  @override
  String get outputPathHint => '';

  // Main project
  @override
  String get mainProject => '主工程';
  @override
  String get mainProjectBranch => '主工程分支';
  @override
  String get mainProjectBinding => '主工程绑定';
  @override
  String get mainProjectBindingSubtitle => '配置主工程路径与默认分支';

  // Dependencies
  @override
  String get dependencyTopology => '依赖项拓扑视图';
  @override
  String get dependencyTopologyMatrix => '依赖拓扑矩阵';
  @override
  String get dependencyBranchOverride => '依赖分支覆盖';
  @override
  String get dependencyAddSelect => '选择添加依赖';
  @override
  String get dependencyAddSelectTooltip => '选择添加依赖';
  @override
  String get dependencyAddNone => '无可选依赖';
  @override
  String get dependencyAddItem => '选择添加依赖';
  @override
  String get dependencyAddEmpty => '工作区中没有可继续添加的项目。';
  @override
  String get dependencyAddEmptyHint => '点击右上角"选择添加依赖"，从工作区扫描结果中选择要加入的模块。';
  @override
  String get dependencyEmpty => '当前没有依赖项。通过"选择添加依赖"即可生成可编辑依赖行。';
  @override
  String get dependencyEmptyHint => '';
  @override
  String get dependencyCount => '依赖项';
  @override
  String get dependencyModulePath => '选择模块路径';
  @override
  String get dependencyRemoveTooltip => '移除依赖';
  @override
  String get dependencyRestoreCmd => 'restore 命令';
  @override
  String get dependencyDetected => '依赖项检测';
  @override
  String get dependencyDefault => '默认';
  @override
  String get dependencyOverride => '覆写';

  // Build scenarios
  @override
  String get scenarioConfig => '构建场景配置';
  @override
  String get scenarioMatrixEditor => '构建场景矩阵编辑器';
  @override
  String get scenarioMatrixEditorSubtitle => '维护命令、依赖分支覆盖、输出目录和自动标签策略';
  @override
  String get scenarioAddNew => '新增构建场景';
  @override
  String get scenarioConfirmAdd => '确认新增场景';
  @override
  String get scenarioName => '场景名称';
  @override
  String get scenarioNameHint => '';
  @override
  String get scenarioCommand => '构建命令';
  @override
  String get scenarioCommandHint => '';
  @override
  String get scenarioCleanBefore => '执行构建前强制清理 (--clean)';
  @override
  String get scenarioCleanBeforeShort => '构建前清理 (--clean)';
  @override
  String get scenarioMainBranch => '主项目分支';
  @override
  String get scenarioMainBranchSubtitle => '新增场景时同步确认主项目默认 Git 分支';
  @override
  String get scenarioUnnamed => '未命名场景';
  @override
  String get scenarioNoCommand => '未配置执行指令';
  @override
  String get scenarioEditTooltip => '编辑场景';
  @override
  String get scenarioDeleteTooltip => '删除场景';
  @override
  String get scenarioDefaultName => '新场景';
  @override
  String get scenarioDefaultSubtitle => '手动新增场景';
  @override
  String get scenarioCreatedLog => '场景已创建，等待执行';

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
  String get statusIdleDesc => '等待指令下达';
  @override
  String get statusValidatingDesc => '校验构建参数与分支状态';
  @override
  String get statusSyncingDesc => '同步依赖仓库和缓存';
  @override
  String get statusRestoringDesc => '串行执行 restore_command，重建依赖树';
  @override
  String get statusBuildingDesc => '执行构建命令并采集日志';
  @override
  String get statusPostHookDesc => '执行构建后回调';
  @override
  String get statusSuccessDesc => '全流程完成';
  @override
  String get statusFailedDesc => '出现不可恢复错误，等待重新触发';
  @override
  String get statusInterruptedDesc => '用户主动中断，需从 VALIDATING 重新开始';

  @override
  String get triggerLabel => '开始构建任务';
  @override
  String get loadingLabel => 'Loading…';

  // Build status labels
  @override
  String get currentStatus => '当前状态';
  @override
  String get runningStatus => '运行中';
  @override
  String get failedStatus => '失败';
  @override
  String get readyStatus => '就绪';
  @override
  String get connectedStatus => '已连接';
  @override
  String get parallelRunning => '并行运行';

  // Build logs
  @override
  String get buildLogsTitle => '构建日志';
  @override
  String get buildLogsSubtitle => '执行任务历史与日志列表';
  @override
  String get buildLogsEmpty => '暂无任务历史';
  @override
  String get buildLogsEmptyDetail => '暂无执行任务记录';
  @override
  String get buildLogsNoMatch => '没有匹配的记录';
  @override
  String get buildLogsSelectRecord => '请选择一条任务记录';
  @override
  String get buildLogsNoLogs => '当前任务暂无日志';
  @override
  String get buildLogsBranch => '分支';
  @override
  String get buildLogsStart => '开始于';
  @override
  String get buildLogsStartFinish => '开始于 · 结束于';

  // YAML editor
  @override
  String get yamlEditorTitle => 'YAML Configuration Override';
  @override
  String get yamlEditorSubtitle => '编辑 YAML 覆写内容并即时应用到当前工作区配置';
  @override
  String get yamlEditorFilename => 'mixbuild.config.yaml';
  @override
  String get yamlEditorFooter => '所有更改将保存到当前工作区 YAML。';
  @override
  String get yamlEditorCancel => '取消';
  @override
  String get yamlEditorSave => '保存配置';
  @override
  String get yamlOverride => 'Override';
  @override
  String get yamlOverrideTitle => 'YAML Configuration Override';
  @override
  String get yamlReload => '重载 YAML';
  @override
  String get yamlOpen => '打开 YAML';
  @override
  String get yamlGlobalConfig => 'Global Config';

  // Global config
  @override
  String get globalConfigTitle => '工程配置中心';

  // Advanced options
  @override
  String get advancedOptions => '高级选项';
  @override
  String get advancedOptionsSubtitle => '配置产物输出目录以及构建成功后的自动标签行为';

  // Auto tag
  @override
  String get autoTag => '自动标签';
  @override
  String get autoTagTitle => '自动打标签';
  @override
  String get autoTagDesc => '构建成功后自动应用 Git Tag';
  @override
  String get tagPrefix => '标签前缀';
  @override
  String get tagPrefixHint => '';
  @override
  String get autoTagEnabled => '已开启';
  @override
  String get autoTagDisabled => '关闭';

  // Scenario preview
  @override
  String get scenarioTarget => '目标';

  // Misc
  @override
  String get mainBranchLabel => '主分支';
  @override
  String get nodesLabel => 'NODES';
  @override
  String get zshTerminalTitle => 'zsh';

  // Error messages
  @override
  String yamlSaveError(String error) => 'YAML 保存失败: $error';
  @override
  String dirAccessError(String error) => '申请目录访问权限失败: $error';
  @override
  String scanError(String error) => '扫描失败: $error';
  @override
  String projectAlreadySelected(String name) => '项目 $name 已被选择，无需重复添加。';
  @override
  String projectAlreadyInConfig(String name) => '项目 $name 已经在当前配置中。';
  @override
  String logSaved(String path) => '完整日志已保存: $path';
  @override
  String noLogMatch(String query) => '没有匹配 "$query" 的日志';
  @override
  String readyForCommand(String name) =>
      'Ready to receive build command for project: $name';
  @override
  String discoveredGitProjects(int count) =>
      '已发现 $count 个 Git 项目，可用于主工程和依赖拓扑的路径选择。';
  @override
  String dependencyCountInfo(int count) => '自动解析 $count 个模块，并允许调整路径、分支与恢复命令';
  @override
  String availableCount(int count) => '可选 $count';
  @override
  String mainProjectBranchInfo(String branch) => '主项目: $branch';
  @override
  String parallelRunningCount(int count) => '并行运行: $count';
  @override
  String failedCount(int count) => '失败 $count';
  @override
  String runningCount(int count) => '运行中 $count';
  @override
  String branchInfo(String branch) => '分支: $branch';
  @override
  String terminalTitle(String command, String project) =>
      'zsh — $command — $project';
  @override
  String dependenciesDetected(int count) => '$count 个依赖项已检测';
  @override
  String buildLogsShowingLatest(int visible, int total) =>
      '显示最近 $visible / $total 条日志';
  @override
  String buildLogsShowingMatches(int visible, int total) =>
      '显示匹配结果 $visible / $total 条';
  @override
  String buildLogsLoadOlder(int count) => '加载更早日志 ($count)';
}
