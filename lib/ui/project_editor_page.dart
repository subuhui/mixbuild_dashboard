import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/app/responsive_layout.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_config.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/services/git_branch_discovery.dart';
import 'package:mixbuild_dashboard/services/git_project_discovery.dart';
import 'package:mixbuild_dashboard/services/workspace_bookmark_service.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';
import 'package:path/path.dart' as p;

class ProjectEditorResult {
  const ProjectEditorResult({
    required this.config,
    required this.bindings,
    required this.scenarios,
  });

  final GlobalConfig config;
  final List<ProjectBindingConfig> bindings;
  final List<BuildScenario> scenarios;
}

class ProjectEditorPage extends StatefulWidget {
  const ProjectEditorPage({
    super.key,
    required this.config,
    required this.scenarios,
    required this.baseDependencies,
    this.title = '',
    this.primaryActionLabel = '',
  });

  final GlobalConfig config;
  final List<BuildScenario> scenarios;
  final List<DependencyBranch> baseDependencies;
  final String title;
  final String primaryActionLabel;

  static Future<ProjectEditorResult?> show(
    BuildContext context, {
    required GlobalConfig config,
    required List<BuildScenario> scenarios,
    required List<DependencyBranch> baseDependencies,
    String title = '',
    String primaryActionLabel = '',
  }) {
    return Navigator.of(context).push<ProjectEditorResult>(
      MaterialPageRoute<ProjectEditorResult>(
        builder: (context) => ProjectEditorPage(
          config: config,
          scenarios: scenarios,
          baseDependencies: baseDependencies,
          title: title,
          primaryActionLabel: primaryActionLabel,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends State<ProjectEditorPage> {
  late final TextEditingController _workspaceController;
  late final TextEditingController _projectNameController;
  late final GitBranchDiscovery _gitBranchDiscovery;
  late final GitProjectDiscovery _gitProjectDiscovery;
  late final List<_ProjectBindingDraft> _bindingDrafts;
  late final List<_ScenarioDraft> _scenarioDrafts;
  Timer? _workspaceScanDebounce;
  List<DiscoveredGitProject> _discoveredProjects =
      const <DiscoveredGitProject>[];
  final Map<_ProjectBindingDraft, List<String>> _draftBranchOptions =
      <_ProjectBindingDraft, List<String>>{};
  final Map<_ProjectBindingDraft, String> _draftBranchWarnings =
      <_ProjectBindingDraft, String>{};
  final Set<_ProjectBindingDraft> _loadingBranchDrafts =
      <_ProjectBindingDraft>{};
  String? _scanError;
  bool _isScanning = false;

  List<DiscoveredGitProject> get _availableDiscoveredProjects {
    return _discoveredProjects
        .where((project) => !_isProjectSelected(project))
        .toList(growable: false);
  }

  _ProjectBindingDraft get _mainBindingDraft => _bindingDrafts.first;
  List<_ProjectBindingDraft> get _dependencyDrafts =>
      _bindingDrafts.skip(1).toList();

  @override
  void initState() {
    super.initState();
    _gitBranchDiscovery = GitBranchDiscovery();
    _gitProjectDiscovery = const GitProjectDiscovery();
    _workspaceController = TextEditingController(
      text: widget.config.workspaceRoot,
    );
    _projectNameController = TextEditingController(
      text: widget.config.activeProjectName,
    );
    _bindingDrafts = _createBindingDrafts();
    _scenarioDrafts =
        widget.scenarios.map(_ScenarioDraft.fromScenario).toList();
    _workspaceController.addListener(_handleWorkspacePathChanged);
    unawaited(_initializeEditorState());
  }

  Future<void> _initializeEditorState() async {
    if (_workspaceController.text.trim().isNotEmpty) {
      await _refreshDiscoveredProjects();
    }
    if (!mounted) {
      return;
    }
    await _refreshAllDraftBranchOptions();
  }

  @override
  void dispose() {
    _workspaceScanDebounce?.cancel();
    _workspaceController.removeListener(_handleWorkspacePathChanged);
    _workspaceController.dispose();
    _projectNameController.dispose();
    for (final draft in _bindingDrafts) {
      draft.dispose();
    }
    for (final draft in _scenarioDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  List<_ProjectBindingDraft> _createBindingDrafts() {
    final defaultBranch = widget.config.mainProjectDefaultBranch;
    if (widget.config.bindings.isEmpty) {
      return [
        _ProjectBindingDraft(
          projectName: 'new_project',
          isMainProject: true,
          path: '.',
          type: MixbuildProjectType.flutter,
          defaultBranch: defaultBranch,
          restoreCommand: null,
        ),
      ];
    }
    return widget.config.bindings.asMap().entries.map((entry) {
      final index = entry.key;
      final binding = entry.value;
      final dependency = widget.baseDependencies.where(
        (item) => item.name == binding.projectName,
      );
      final isMainProject = index == 0;
      final inferredType =
          binding.type ?? _inferProjectType(binding.projectName, binding.path);
      return _ProjectBindingDraft(
        projectName: binding.projectName,
        isMainProject: isMainProject,
        path: binding.path,
        type: inferredType,
        defaultBranch: binding.defaultBranch ??
            (isMainProject
                ? defaultBranch
                : (dependency.isNotEmpty
                    ? dependency.first.branch
                    : defaultBranch)),
        restoreCommand: isMainProject
            ? binding.restoreCommand
            : binding.restoreCommand ?? _defaultRestoreCommand(inferredType),
      );
    }).toList();
  }

  DiscoveredGitProject? _findDiscoveredProjectByPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final project in _discoveredProjects) {
      if (project.relativePath == normalized ||
          project.absolutePath == normalized) {
        return project;
      }
    }
    return null;
  }

  bool _isProjectSelected(
    DiscoveredGitProject project, {
    _ProjectBindingDraft? excluding,
  }) {
    return _bindingDrafts.any((draft) {
      if (identical(draft, excluding)) {
        return false;
      }
      return _normalizeRepoName(draft.projectName) ==
              _normalizeRepoName(project.name) ||
          draft.pathController.text.trim() == project.relativePath;
    });
  }

  void _showSelectionMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  MixbuildProjectType _inferProjectType(String name, String path) {
    final seed = '$name $path'.toLowerCase();
    if (seed.contains('flutter') ||
        seed.contains('module') ||
        seed.contains('ui') ||
        seed.contains('sdk')) {
      return MixbuildProjectType.flutter;
    }
    return MixbuildProjectType.android;
  }

  String _defaultRestoreCommand(MixbuildProjectType type) {
    return type == MixbuildProjectType.flutter
        ? 'fvm flutter pub get'
        : './gradlew assembleRelease';
  }

  void _handleWorkspacePathChanged() {
    _scheduleWorkspaceScan();
  }

  void _scheduleWorkspaceScan({bool immediate = false}) {
    _workspaceScanDebounce?.cancel();
    if (immediate) {
      unawaited(_refreshDiscoveredProjects());
      return;
    }
    _workspaceScanDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_refreshDiscoveredProjects()),
    );
  }

  Future<void> _pickWorkspaceRoot() async {
    final selectedPath = await _showNativeDirectoryPicker();
    if (selectedPath == null || selectedPath.isEmpty) {
      return;
    }
    _workspaceController
      ..text = selectedPath
      ..selection = TextSelection.collapsed(offset: selectedPath.length);
    await _refreshDiscoveredProjects();
  }

  Future<String?> _showNativeDirectoryPicker() async {
    try {
      final selectedPath = await getDirectoryPath(
        confirmButtonText: AppStrings.of(context).workspaceSelect,
        initialDirectory: _workspaceController.text.trim().isEmpty
            ? null
            : _workspaceController.text.trim(),
      );
      if (selectedPath == null || selectedPath.isEmpty) {
        return null;
      }
      // 持久化该目录的 security-scoped bookmark，下次启动免重授权
      await WorkspaceBookmarkService().saveBookmark(selectedPath);
      return selectedPath;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content:
                Text(AppStrings.of(context).dirAccessError(error.toString()))));
      }
      return null;
    }
  }

  Future<void> _refreshDiscoveredProjects() async {
    final workspaceRoot = _workspaceController.text.trim();
    if (workspaceRoot.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isScanning = false;
        _scanError = null;
        _discoveredProjects = const <DiscoveredGitProject>[];
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isScanning = true;
        _scanError = null;
      });
    }

    try {
      final projects = await _gitProjectDiscovery.discover(workspaceRoot);
      if (!mounted) {
        return;
      }
      _syncBindingsWithDiscoveredProjects(projects);
      setState(() {
        _isScanning = false;
        _discoveredProjects = projects;
        _scanError = projects.isEmpty ? '当前目录下未发现包含 .git 的项目。' : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isScanning = false;
        _scanError = AppStrings.of(context).scanError(error.toString());
        _discoveredProjects = const <DiscoveredGitProject>[];
      });
    }
  }

  void _syncBindingsWithDiscoveredProjects(
    List<DiscoveredGitProject> projects,
  ) {
    final projectsByName = <String, DiscoveredGitProject>{
      for (final project in projects) _normalizeRepoName(project.name): project,
    };

    for (final draft in _bindingDrafts) {
      final match = projectsByName[_normalizeRepoName(draft.projectName)];
      if (match == null) {
        continue;
      }
      draft.projectName = match.name;
      draft.pathController.text = match.relativePath;
      draft.type = _inferProjectType(draft.projectName, match.relativePath);
      unawaited(_refreshBranchOptionsForDraft(draft));
    }
  }

  String _normalizeRepoName(String value) {
    return value.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'),
          '',
        );
  }

  List<String> _pathOptionsForDraft(_ProjectBindingDraft draft) {
    return <String>{
      if (draft.pathController.text.trim().isNotEmpty)
        draft.pathController.text.trim(),
      ..._discoveredProjects.map((project) => project.relativePath),
    }.toList()
      ..sort();
  }

  void _applyPathToDraft(_ProjectBindingDraft draft, String path) {
    final matchedProject = _findDiscoveredProjectByPath(path);
    if (matchedProject != null &&
        _isProjectSelected(matchedProject, excluding: draft)) {
      _showSelectionMessage(
          AppStrings.of(context).projectAlreadySelected(matchedProject.name));
      return;
    }

    setState(() {
      final previousName = draft.projectName;
      draft.pathController.text = path;
      if (matchedProject != null) {
        draft.projectName = matchedProject.name;
      }
      draft.type = _inferProjectType(draft.projectName, path);
      if (!draft.isMainProject) {
        draft.restoreCommandController.text = _defaultRestoreCommand(
          draft.type,
        );
        _replaceScenarioDependency(
          previousName: previousName,
          nextDependency: _dependencyBranchFromDraft(draft),
        );
      }
    });
  }

  void _addDependencyFromProject(DiscoveredGitProject project) {
    if (_isProjectSelected(project)) {
      _showSelectionMessage(
          AppStrings.of(context).projectAlreadyInConfig(project.name));
      return;
    }

    setState(() {
      final draft = _ProjectBindingDraft(
        projectName: project.name,
        isMainProject: false,
        path: project.relativePath,
        type: _inferProjectType(project.name, project.relativePath),
        defaultBranch: 'develop',
        restoreCommand: _defaultRestoreCommand(
          _inferProjectType(project.name, project.relativePath),
        ),
      );
      _bindingDrafts.add(draft);
      final dependency = _dependencyBranchFromDraft(draft);
      for (final scenarioDraft in _scenarioDrafts) {
        scenarioDraft.replaceDependency(
          previousName: null,
          nextDependency: dependency,
        );
      }
      unawaited(_refreshBranchOptionsForDraft(draft));
    });
  }

  void _removeDependencyDraft(_ProjectBindingDraft draft) {
    setState(() {
      _draftBranchOptions.remove(draft);
      _draftBranchWarnings.remove(draft);
      _loadingBranchDrafts.remove(draft);
      _bindingDrafts.remove(draft);
      draft.dispose();
      for (final scenarioDraft in _scenarioDrafts) {
        scenarioDraft.removeDependency(draft.projectName);
      }
    });
  }

  void _replaceScenarioDependency({
    required String previousName,
    required DependencyBranch nextDependency,
  }) {
    for (final scenarioDraft in _scenarioDrafts) {
      scenarioDraft.replaceDependency(
        previousName: previousName,
        nextDependency: nextDependency,
      );
    }
  }

  DependencyBranch _dependencyBranchFromDraft(_ProjectBindingDraft draft) {
    return DependencyBranch(
      name: draft.projectName,
      branch: draft.defaultBranchController.text.trim().isEmpty
          ? 'develop'
          : draft.defaultBranchController.text.trim(),
      icon: _dependencyIconForDraft(draft.type, draft.projectName),
    );
  }

  IconData _dependencyIconForDraft(MixbuildProjectType type, String name) {
    if (type == MixbuildProjectType.flutter) {
      return Icons.flutter_dash;
    }
    final lowerName = name.toLowerCase();
    if (lowerName.contains('api') || lowerName.contains('service')) {
      return Icons.cloud_outlined;
    }
    if (lowerName.contains('ui') || lowerName.contains('design')) {
      return Icons.palette_outlined;
    }
    return Icons.developer_board_outlined;
  }

  Future<void> _refreshAllDraftBranchOptions() async {
    await Future.wait(_bindingDrafts.map(_refreshBranchOptionsForDraft));
  }

  String? _absolutePathForDraft(_ProjectBindingDraft draft) {
    final workspaceRoot = _workspaceController.text.trim();
    final draftPath = draft.pathController.text.trim();
    if (workspaceRoot.isEmpty || draftPath.isEmpty) {
      return null;
    }
    return p.normalize(
      p.isAbsolute(draftPath) ? draftPath : p.join(workspaceRoot, draftPath),
    );
  }

  Future<void> _refreshBranchOptionsForDraft(_ProjectBindingDraft draft) async {
    final absolutePath = _absolutePathForDraft(draft);
    final preferredBranch = draft.defaultBranchController.text.trim();
    if (mounted) {
      setState(() {
        _loadingBranchDrafts.add(draft);
      });
    }
    final result = absolutePath == null
        ? GitBranchDiscoveryResult(
            branches: <String>{
              if (preferredBranch.isNotEmpty) preferredBranch,
              'develop',
              'main',
              'master',
            }.toList(growable: false),
          )
        : await _gitBranchDiscovery.discoverBranches(
            absolutePath,
            preferredBranch: preferredBranch,
          );
    if (!mounted) {
      return;
    }
    setState(() {
      _draftBranchOptions[draft] = result.branches;
      _loadingBranchDrafts.remove(draft);
      if (result.warningMessage == null ||
          result.warningMessage!.trim().isEmpty) {
        _draftBranchWarnings.remove(draft);
      } else {
        _draftBranchWarnings[draft] = result.warningMessage!;
      }
      if (draft.defaultBranchController.text.trim().isEmpty &&
          result.branches.isNotEmpty) {
        draft.defaultBranchController.text = result.branches.first;
      }
    });
  }

  List<String> _branchOptionsForDraft(_ProjectBindingDraft draft) {
    final currentBranch = draft.defaultBranchController.text.trim();
    return <String>{
      if (currentBranch.isNotEmpty) currentBranch,
      ...?_draftBranchOptions[draft],
    }.toList(growable: false);
  }

  void _setDraftDefaultBranch(_ProjectBindingDraft draft, String branch) {
    setState(() {
      draft.defaultBranchController.text = branch;
      if (!draft.isMainProject) {
        _replaceScenarioDependency(
          previousName: draft.projectName,
          nextDependency: _dependencyBranchFromDraft(draft),
        );
      }
    });
  }

  List<ScenarioBranchDraft> _scenarioDependencyDrafts({
    List<DependencyBranch>? scenarioDependencies,
  }) {
    return _dependencyDrafts.map((draft) {
      final currentBranch = draft.defaultBranchController.text.trim();
      var initialBranch = currentBranch.isEmpty ? 'develop' : currentBranch;
      if (scenarioDependencies != null) {
        for (final dependency in scenarioDependencies) {
          if (dependency.name == draft.projectName) {
            initialBranch = dependency.branch;
            break;
          }
        }
      }
      return ScenarioBranchDraft(
        projectName: draft.projectName,
        initialBranch: initialBranch,
        icon: _dependencyIconForDraft(draft.type, draft.projectName),
        options: _branchOptionsForDraft(draft),
        highlight: MixBuildPalette.primary,
      );
    }).toList(growable: false);
  }

  Future<void> _openScenarioDialog({_ScenarioDraft? editingDraft}) async {
    final initialScenario = editingDraft?.toScenario();
    final result = await showDialog<BuildScenario>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AddScenarioDialog(
        mainProject: ScenarioBranchDraft(
          projectName: _mainBindingDraft.projectName,
          initialBranch: initialScenario?.mainBranch.trim().isNotEmpty == true
              ? initialScenario!.mainBranch
              : (_mainBindingDraft.defaultBranchController.text.trim().isEmpty
                  ? 'develop'
                  : _mainBindingDraft.defaultBranchController.text.trim()),
          icon: _dependencyIconForDraft(
            _mainBindingDraft.type,
            _mainBindingDraft.projectName,
          ),
          options: _branchOptionsForDraft(_mainBindingDraft),
          highlight: MixBuildPalette.tertiary,
        ),
        dependencyDrafts: _scenarioDependencyDrafts(
          scenarioDependencies: initialScenario?.dependencies,
        ),
        initialScenario: initialScenario,
        title: editingDraft == null
            ? AppStrings.of(context).scenarioAddNew
            : '编辑构建场景',
        primaryActionLabel: editingDraft == null
            ? AppStrings.of(context).scenarioConfirmAdd
            : '保存场景修改',
      ),
    );
    if (result == null) {
      return;
    }

    setState(() {
      final nextDraft = _ScenarioDraft.fromScenario(result);
      if (editingDraft == null) {
        _scenarioDrafts.add(nextDraft);
        return;
      }
      final targetIndex = _scenarioDrafts.indexOf(editingDraft);
      if (targetIndex == -1) {
        _scenarioDrafts.add(nextDraft);
      } else {
        editingDraft.dispose();
        _scenarioDrafts[targetIndex] = nextDraft;
      }
    });
  }

  Future<void> _openAddScenarioDialog() async {
    await _openScenarioDialog();
  }

  Future<void> _openEditScenarioDialog(_ScenarioDraft draft) async {
    await _openScenarioDialog(editingDraft: draft);
  }

  void _removeScenarioDraft(_ScenarioDraft draft) {
    setState(() {
      _scenarioDrafts.remove(draft);
      draft.dispose();
    });
  }

  ProjectEditorResult _buildResult() {
    final bindings =
        _bindingDrafts.map((draft) => draft.toConfig()).toList(growable: false);
    final config = widget.config.copyWith(
      workspaceRoot: _workspaceController.text.trim(),
      activeProjectName: _projectNameController.text.trim(),
      bindings: bindings
          .map(
            (binding) => WorkspaceBinding(
              projectName: binding.projectName,
              path: binding.path,
              type: binding.type,
              defaultBranch: binding.defaultBranch,
              restoreCommand: binding.restoreCommand,
            ),
          )
          .toList(growable: false),
    );
    final scenarios = _scenarioDrafts
        .map((draft) => draft.toScenario())
        .toList(growable: false);
    return ProjectEditorResult(
      config: config,
      bindings: bindings,
      scenarios: scenarios,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = ResponsiveLayout.of(context);
    final strings = AppStrings.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const DashboardBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: responsive.shellPadding,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1280,
                    maxHeight: 920,
                  ),
                  child: Container(
                    decoration: MixBuildTheme.surfacePanel(radius: 28),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
                          decoration: BoxDecoration(
                            color: MixBuildPalette.surfaceHighest,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: MixBuildPalette.foreground
                                    .withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 920;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(Icons.arrow_back),
                                  ),
                                  SizedBox(
                                    width: compact
                                        ? constraints.maxWidth - 56
                                        : constraints.maxWidth - 340,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.title.isEmpty
                                              ? strings.projectEditorTitle
                                              : widget.title,
                                          style: theme.textTheme.headlineMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          strings.projectEditorSubtitle,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: compact ? constraints.maxWidth : 260,
                                    child: TextField(
                                      controller: _projectNameController,
                                      decoration: InputDecoration(
                                        labelText: strings.projectNameLabel,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(28),
                            children: [
                              _buildWorkspaceSection(theme),
                              const SizedBox(height: 24),
                              _buildMainProjectSection(theme),
                              const SizedBox(height: 24),
                              _buildDependencySection(theme),
                              const SizedBox(height: 24),
                              _buildScenarioSection(theme),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                          decoration: BoxDecoration(
                            color: MixBuildPalette.surfaceLow.withValues(
                              alpha: 0.52,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(28),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: MixBuildPalette.foreground
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 12,
                            spacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: responsive.isCompact ? 720 : 520,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: MixBuildPalette.muted,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        strings.yamlEditorFooter,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(strings.btnCancel),
                              ),
                              FilledButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).pop(_buildResult()),
                                icon: const Icon(Icons.save_outlined),
                                label: Text(widget.primaryActionLabel.isEmpty
                                    ? strings.projectEditorSave
                                    : widget.primaryActionLabel),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSection(ThemeData theme) {
    final strings = AppStrings.of(context);
    return _ConfigSectionCard(
      title: strings.workspaceRoot,
      subtitle: strings.workspaceRootSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact
                        ? constraints.maxWidth
                        : constraints.maxWidth - 264,
                    child: TextField(
                      controller: _workspaceController,
                      decoration: InputDecoration(
                        hintText: strings.workspaceRootHint,
                        suffixIcon: _isScanning
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _refreshDiscoveredProjects(),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickWorkspaceRoot,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(strings.btnBrowse),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refreshDiscoveredProjects,
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(strings.btnRefresh),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _scanError ??
                (_discoveredProjects.isEmpty
                    ? strings.workspaceScanInfo
                    : strings
                        .discoveredGitProjects(_discoveredProjects.length)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: _scanError == null
                  ? MixBuildPalette.muted
                  : MixBuildPalette.warning,
            ),
          ),
          if (_discoveredProjects.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _discoveredProjects.map((project) {
                final selected = _isProjectSelected(project);
                return Container(
                  width: 208,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? MixBuildPalette.primary.withValues(alpha: 0.06)
                        : MixBuildPalette.surfaceHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? MixBuildPalette.primary.withValues(alpha: 0.22)
                          : MixBuildPalette.foreground.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            selected
                                ? Icons.check_circle_outline
                                : Icons.open_with,
                            size: 16,
                            color: selected
                                ? MixBuildPalette.primary
                                : MixBuildPalette.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        project.relativePath,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MixBuildTheme.monoTextStyle(
                          fontSize: 12,
                          color: MixBuildPalette.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selected ? '已在当前配置中' : '可在下方选择添加为主工程或依赖项',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? MixBuildPalette.primary
                              : MixBuildPalette.muted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainProjectSection(ThemeData theme) {
    final strings = AppStrings.of(context);
    final draft = _mainBindingDraft;
    return _ConfigSectionCard(
      title: strings.mainProjectBinding,
      subtitle: strings.mainProjectBindingSubtitle,
      child: Row(
        children: [
          Expanded(
            child: _EditorFieldTile(
              label: strings.projectNameLabel,
              child: _ReadOnlyField(value: draft.projectName),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _EditorFieldTile(
              label: strings.pathLabel,
              child: _PathSelectorField(
                controller: draft.pathController,
                options: _pathOptionsForDraft(draft),
                hintText: strings.pathHint,
                onPathSelected: (value) {
                  _applyPathToDraft(draft, value);
                  unawaited(_refreshBranchOptionsForDraft(draft));
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _EditorFieldTile(
              label: strings.mainBranchLabel,
              child: _BranchSelectorField(
                value: draft.defaultBranchController.text.trim(),
                options: _branchOptionsForDraft(draft),
                isLoading: _loadingBranchDrafts.contains(draft),
                warningMessage: _draftBranchWarnings[draft],
                onSelected: (value) => _setDraftDefaultBranch(draft, value),
                onRefresh: () =>
                    unawaited(_refreshBranchOptionsForDraft(draft)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDependencySection(ThemeData theme) {
    final strings = AppStrings.of(context);
    return _ConfigSectionCard(
      title: strings.dependencyTopology,
      subtitle: strings.dependencyCountInfo(_dependencyDrafts.length),
      trailing: PopupMenuButton<DiscoveredGitProject>(
        enabled: _availableDiscoveredProjects.isNotEmpty,
        tooltip: strings.dependencyAddSelect,
        onSelected: _addDependencyFromProject,
        itemBuilder: (context) {
          return _availableDiscoveredProjects.map((project) {
            return PopupMenuItem<DiscoveredGitProject>(
              value: project,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name),
                  Text(
                    project.relativePath,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MixBuildPalette.muted,
                        ),
                  ),
                ],
              ),
            );
          }).toList(growable: false);
        },
        child: FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.add_link_outlined),
          label: Text(
            _availableDiscoveredProjects.isEmpty
                ? strings.dependencyAddNone
                : strings.dependencyAddSelect,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MixBuildPalette.surfaceHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: MixBuildPalette.foreground.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.add_link_outlined, color: MixBuildPalette.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.dependencyAddItem,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        _availableDiscoveredProjects.isEmpty
                            ? strings.dependencyAddEmpty
                            : strings.dependencyAddEmptyHint,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: MixBuildPalette.surfaceHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    strings.availableCount(_availableDiscoveredProjects.length),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (_dependencyDrafts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              decoration: BoxDecoration(
                color: MixBuildPalette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MixBuildPalette.foreground.withValues(alpha: 0.06),
                ),
              ),
              child: Text(
                strings.dependencyEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: MixBuildPalette.muted,
                ),
              ),
            ),
          ..._dependencyDrafts.map((draft) {
            return Padding(
              key: ValueKey(
                'dependency-${draft.projectName}-${draft.pathController.text}',
              ),
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MixBuildPalette.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: MixBuildPalette.foreground.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: MixBuildPalette.foreground
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _dependencyIconForDraft(
                              draft.type,
                              draft.projectName,
                            ),
                            color: MixBuildPalette.muted,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _ReadOnlyField(value: draft.projectName),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: _PathSelectorField(
                            controller: draft.pathController,
                            options: _pathOptionsForDraft(draft),
                            hintText: strings.dependencyModulePath,
                            onPathSelected: (value) {
                              _applyPathToDraft(draft, value);
                              unawaited(_refreshBranchOptionsForDraft(draft));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 320,
                          child: _BranchSelectorField(
                            value: draft.defaultBranchController.text.trim(),
                            options: _branchOptionsForDraft(draft),
                            isLoading: _loadingBranchDrafts.contains(draft),
                            warningMessage: _draftBranchWarnings[draft],
                            onSelected: (value) =>
                                _setDraftDefaultBranch(draft, value),
                            onRefresh: () =>
                                unawaited(_refreshBranchOptionsForDraft(draft)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: strings.dependencyRemoveTooltip,
                          onPressed: () => _removeDependencyDraft(draft),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: draft.restoreCommandController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: strings.dependencyRestoreCmd,
                        prefixIcon: Icon(
                          draft.type == MixbuildProjectType.flutter
                              ? Icons.terminal
                              : Icons.developer_board_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScenarioSection(ThemeData theme) {
    final strings = AppStrings.of(context);
    return _ConfigSectionCard(
      title: strings.scenarioMatrixEditor,
      subtitle: strings.scenarioMatrixEditorSubtitle,
      trailing: FilledButton.icon(
        onPressed: _openAddScenarioDialog,
        icon: const Icon(Icons.add),
        label: Text(strings.scenarioAddNew),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: _scenarioDrafts.map((draft) {
          return SizedBox(
            width: 392,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openEditScenarioDialog(draft),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MixBuildPalette.foreground.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: MixBuildPalette.foreground.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: MixBuildPalette.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _scenarioBadge(draft.nameController.text),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  draft.nameController.text.trim().isEmpty
                                      ? strings.scenarioUnnamed
                                      : draft.nameController.text.trim(),
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  draft.subtitle,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: strings.scenarioEditTooltip,
                            onPressed: () => _openEditScenarioDialog(draft),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: strings.scenarioDeleteTooltip,
                            onPressed: () => _removeScenarioDraft(draft),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        draft.commandController.text.trim().isEmpty
                            ? strings.scenarioNoCommand
                            : draft.commandController.text.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MixBuildTheme.monoTextStyle(
                          fontSize: 12,
                          color: MixBuildPalette.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _ScenarioMetaItem(
                              label: strings.mainBranchLabel,
                              value: draft.mainBranch,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ScenarioMetaItem(
                              label: strings.outputDir,
                              value: draft.outputController.text.trim().isEmpty
                                  ? '未配置'
                                  : draft.outputController.text.trim(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ScenarioMetaItem(
                              label: strings.autoTag,
                              value: draft.autoTag
                                  ? (draft.tagController.text.trim().isEmpty
                                      ? strings.autoTagEnabled
                                      : draft.tagController.text.trim())
                                  : strings.autoTagDisabled,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TinyBadge(
                            label:
                                strings.mainProjectBranchInfo(draft.mainBranch),
                            color: MixBuildPalette.tertiary,
                          ),
                          ...draft.dependencies.map((dependency) {
                            return TinyBadge(
                              label: '${dependency.name}: ${dependency.branch}',
                              color: dependency.highlight ??
                                  MixBuildPalette.primary,
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _scenarioBadge(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('release') || lowerName.contains('prod')) {
      return 'R';
    }
    if (lowerName.contains('debug') || lowerName.contains('qa')) {
      return 'Q';
    }
    return 'B';
  }
}

class _ProjectBindingDraft {
  _ProjectBindingDraft({
    required this.projectName,
    required this.isMainProject,
    required String path,
    required this.type,
    required String defaultBranch,
    required String? restoreCommand,
  })  : pathController = TextEditingController(text: path),
        defaultBranchController = TextEditingController(text: defaultBranch),
        restoreCommandController = TextEditingController(
          text: restoreCommand ?? '',
        );

  String projectName;
  final bool isMainProject;
  final TextEditingController pathController;
  final TextEditingController defaultBranchController;
  final TextEditingController restoreCommandController;
  MixbuildProjectType type;

  ProjectBindingConfig toConfig() {
    return ProjectBindingConfig(
      projectName: projectName,
      path: pathController.text.trim(),
      type: type,
      defaultBranch: defaultBranchController.text.trim().isEmpty
          ? 'develop'
          : defaultBranchController.text.trim(),
      restoreCommand: restoreCommandController.text.trim().isEmpty
          ? null
          : restoreCommandController.text.trim(),
      isMainProject: isMainProject,
    );
  }

  void dispose() {
    pathController.dispose();
    defaultBranchController.dispose();
    restoreCommandController.dispose();
  }
}

class _ScenarioDraft {
  _ScenarioDraft({
    required this.original,
    required this.nameController,
    required this.commandController,
    required this.outputController,
    required this.tagController,
    required this.autoTag,
    required this.mainBranch,
    required this.dependencies,
  });

  factory _ScenarioDraft.fromScenario(BuildScenario scenario) {
    return _ScenarioDraft(
      original: scenario,
      nameController: TextEditingController(text: scenario.name),
      commandController: TextEditingController(text: scenario.command),
      outputController: TextEditingController(text: scenario.outputPath),
      tagController: TextEditingController(text: scenario.tagPrefix),
      autoTag: scenario.autoTag,
      mainBranch: scenario.mainBranch,
      dependencies: List<DependencyBranch>.from(scenario.dependencies),
    );
  }

  final BuildScenario original;
  final TextEditingController nameController;
  final TextEditingController commandController;
  final TextEditingController outputController;
  final TextEditingController tagController;
  bool autoTag;
  String mainBranch;
  List<DependencyBranch> dependencies;

  String get subtitle => original.subtitle;

  void replaceDependency({
    required String? previousName,
    required DependencyBranch nextDependency,
  }) {
    final normalizedNext = nextDependency.name.toLowerCase();
    var replaced = false;
    dependencies = dependencies.map((dependency) {
      final normalizedCurrent = dependency.name.toLowerCase();
      final matchedPrevious = previousName != null &&
          normalizedCurrent == previousName.toLowerCase();
      final matchedNext = normalizedCurrent == normalizedNext;
      if (matchedPrevious || matchedNext) {
        replaced = true;
        return nextDependency.copyWith(
          isOverride: dependency.isOverride,
          highlight: dependency.highlight,
        );
      }
      return dependency;
    }).toList(growable: false);

    if (!replaced) {
      dependencies = [...dependencies, nextDependency];
    }
  }

  void removeDependency(String projectName) {
    dependencies = dependencies
        .where(
          (dependency) =>
              dependency.name.toLowerCase() != projectName.toLowerCase(),
        )
        .toList(growable: false);
  }

  BuildScenario toScenario() {
    return original.copyWith(
      name: nameController.text.trim().isEmpty
          ? original.name
          : nameController.text.trim(),
      mainBranch:
          mainBranch.trim().isEmpty ? original.mainBranch : mainBranch.trim(),
      command: commandController.text.trim(),
      dependencies: dependencies,
      outputPath: outputController.text.trim(),
      autoTag: autoTag,
      tagPrefix: tagController.text.trim(),
    );
  }

  void dispose() {
    nameController.dispose();
    commandController.dispose();
    outputController.dispose();
    tagController.dispose();
  }
}

class _ConfigSectionCard extends StatelessWidget {
  const _ConfigSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MixBuildPalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: MixBuildPalette.foreground.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: MixBuildPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 16), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EditorFieldTile extends StatelessWidget {
  const _EditorFieldTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: MixBuildPalette.muted),
          ),
        ),
        child,
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: MixBuildPalette.foreground.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MixBuildPalette.foreground.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _PathSelectorField extends StatelessWidget {
  const _PathSelectorField({
    required this.controller,
    required this.options,
    required this.hintText,
    required this.onPathSelected,
  });

  final TextEditingController controller;
  final List<String> options;
  final String hintText;
  final ValueChanged<String> onPathSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hintText),
          ),
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: AppStrings.of(context).pathLabel,
            onSelected: onPathSelected,
            itemBuilder: (context) {
              return options.map((option) {
                return PopupMenuItem<String>(
                  value: option,
                  child: Text(option, overflow: TextOverflow.ellipsis),
                );
              }).toList(growable: false);
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: MixBuildPalette.foreground.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: MixBuildPalette.foreground.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(Icons.expand_more, color: MixBuildPalette.muted),
            ),
          ),
        ],
      ],
    );
  }
}

class _BranchSelectorField extends StatelessWidget {
  const _BranchSelectorField({
    required this.value,
    required this.options,
    required this.isLoading,
    this.warningMessage,
    required this.onSelected,
    required this.onRefresh,
  });

  final String value;
  final List<String> options;
  final bool isLoading;
  final String? warningMessage;
  final ValueChanged<String> onSelected;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value.trim();
    final normalizedOptions = <String>{
      if (normalizedValue.isNotEmpty) normalizedValue,
      ...options.where((item) => item.trim().isNotEmpty),
    }.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: normalizedOptions.contains(normalizedValue) &&
                        normalizedValue.isNotEmpty
                    ? normalizedValue
                    : (normalizedOptions.isEmpty
                        ? null
                        : normalizedOptions.first),
                decoration: const InputDecoration(isDense: true),
                items: normalizedOptions.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item, overflow: TextOverflow.ellipsis),
                  );
                }).toList(growable: false),
                selectedItemBuilder: (context) {
                  return normalizedOptions.map((item) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(growable: false);
                },
                onChanged: normalizedOptions.isEmpty
                    ? null
                    : (next) {
                        if (next != null) {
                          onSelected(next);
                        }
                      },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                tooltip: AppStrings.of(context).btnRefresh,
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_outlined, size: 18),
              ),
            ),
          ],
        ),
        if (warningMessage != null && warningMessage!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            warningMessage!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: MixBuildPalette.warning),
          ),
        ],
      ],
    );
  }
}

class _ScenarioMetaItem extends StatelessWidget {
  const _ScenarioMetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MixBuildTheme.monoTextStyle(
            fontSize: 12,
            color: MixBuildPalette.foreground,
          ),
        ),
      ],
    );
  }
}

class ScenarioBranchDraft {
  const ScenarioBranchDraft({
    required this.projectName,
    required this.initialBranch,
    required this.icon,
    required this.options,
    this.highlight,
  });

  final String projectName;
  final String initialBranch;
  final IconData icon;
  final List<String> options;
  final Color? highlight;
}

class AddScenarioDialog extends StatefulWidget {
  const AddScenarioDialog({
    super.key,
    required this.mainProject,
    required this.dependencyDrafts,
    this.initialScenario,
    this.title = '',
    this.primaryActionLabel = '',
  });

  final ScenarioBranchDraft mainProject;
  final List<ScenarioBranchDraft> dependencyDrafts;
  final BuildScenario? initialScenario;
  final String title;
  final String primaryActionLabel;

  @override
  State<AddScenarioDialog> createState() => _AddScenarioDialogState();
}

class _AddScenarioDialogState extends State<AddScenarioDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _commandController;
  late final TextEditingController _outputController;
  late final TextEditingController _tagController;
  bool _autoTag = true;
  late Map<String, String> _branches;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialScenario?.name ?? 'Production_v1',
    );
    _commandController = TextEditingController(
      text: widget.initialScenario?.command ?? './gradlew assembleRelease',
    );
    _outputController = TextEditingController(
      text: widget.initialScenario?.outputPath ?? 'output_dir/',
    );
    _tagController = TextEditingController(
      text: widget.initialScenario?.tagPrefix ?? 'release_',
    );
    _autoTag = widget.initialScenario?.autoTag ?? true;
    _branches = {
      widget.mainProject.projectName:
          widget.initialScenario?.mainBranch.trim().isNotEmpty == true
              ? widget.initialScenario!.mainBranch
              : widget.mainProject.initialBranch,
      for (final item in widget.dependencyDrafts)
        item.projectName:
            _scenarioDependencyBranch(item.projectName) ?? item.initialBranch,
    };
  }

  String? _scenarioDependencyBranch(String projectName) {
    final scenario = widget.initialScenario;
    if (scenario == null) {
      return null;
    }
    for (final dependency in scenario.dependencies) {
      if (dependency.name == projectName) {
        return dependency.branch;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _outputController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
          decoration: MixBuildTheme.surfacePanel(radius: 24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_box_outlined,
                      color: MixBuildPalette.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title.isEmpty
                            ? strings.scenarioAddNew
                            : widget.title,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _ConfigSectionCard(
                      title: '基本信息',
                      subtitle: '定义场景名称和实际执行的构建命令',
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: strings.scenarioName,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _commandController,
                            decoration: InputDecoration(
                              labelText: strings.scenarioCommand,
                            ),
                            minLines: 3,
                            maxLines: 3,
                            style: MixBuildTheme.monoTextStyle(
                              fontSize: 13,
                              color: MixBuildPalette.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ConfigSectionCard(
                      title: strings.scenarioMainBranch,
                      subtitle: strings.scenarioMainBranchSubtitle,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: MixBuildPalette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: MixBuildPalette.foreground
                                .withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.mainProject.icon,
                              color: widget.mainProject.highlight ??
                                  MixBuildPalette.tertiary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.mainProject.projectName,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value:
                                    _branches[widget.mainProject.projectName],
                                dropdownColor: MixBuildPalette.surfaceHighest,
                                items: widget.mainProject.options.map((item) {
                                  return DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  );
                                }).toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _branches[widget.mainProject.projectName] =
                                        value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ConfigSectionCard(
                      title: strings.dependencyBranchOverride,
                      subtitle: strings
                          .dependenciesDetected(widget.dependencyDrafts.length),
                      child: Column(
                        children: [
                          for (final dependency in widget.dependencyDrafts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: MixBuildPalette.surfaceHighest,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: MixBuildPalette.foreground
                                        .withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      dependency.icon,
                                      color: dependency.highlight ??
                                          MixBuildPalette.muted,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        dependency.projectName,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value:
                                            _branches[dependency.projectName],
                                        dropdownColor:
                                            MixBuildPalette.surfaceHighest,
                                        items: dependency.options.map((item) {
                                          return DropdownMenuItem<String>(
                                            value: item,
                                            child: Text(item),
                                          );
                                        }).toList(growable: false),
                                        onChanged: (value) {
                                          if (value == null) {
                                            return;
                                          }
                                          setState(() {
                                            _branches[dependency.projectName] =
                                                value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ConfigSectionCard(
                      title: strings.advancedOptions,
                      subtitle: strings.advancedOptionsSubtitle,
                      child: Column(
                        children: [
                          TextField(
                            controller: _outputController,
                            decoration: InputDecoration(
                              labelText: strings.outputPath,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: MixBuildPalette.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: MixBuildPalette.primary.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            strings.autoTagTitle,
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            strings.autoTagDesc,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _autoTag,
                                      onChanged: (value) =>
                                          setState(() => _autoTag = value),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _tagController,
                                  enabled: _autoTag,
                                  decoration: InputDecoration(
                                    labelText: strings.tagPrefix,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(strings.btnCancel),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          BuildScenario(
                            id: widget.initialScenario?.id ??
                                'scenario-${DateTime.now().millisecondsSinceEpoch}',
                            name: _nameController.text.trim().isEmpty
                                ? (widget.initialScenario?.name ??
                                    strings.scenarioDefaultName)
                                : _nameController.text.trim(),
                            subtitle: widget.initialScenario?.subtitle ??
                                strings.scenarioDefaultSubtitle,
                            environment:
                                widget.initialScenario?.environment ?? 'custom',
                            mainBranch:
                                _branches[widget.mainProject.projectName] ??
                                    widget.mainProject.initialBranch,
                            command: _commandController.text.trim(),
                            status: widget.initialScenario?.status ??
                                BuildStatus.idle,
                            progress: widget.initialScenario?.progress ?? 0,
                            logs: widget.initialScenario?.logs ??
                                [
                                  LogEntry(
                                    time: '19:22:10',
                                    level: 'INIT',
                                    message: strings.scenarioCreatedLog,
                                    accent: MixBuildPalette.primary,
                                  ),
                                ],
                            dependencies: widget.dependencyDrafts.map((item) {
                              return DependencyBranch(
                                name: item.projectName,
                                branch: _branches[item.projectName] ??
                                    item.initialBranch,
                                icon: item.icon,
                                isOverride: (_branches[item.projectName] ??
                                        item.initialBranch) !=
                                    item.initialBranch,
                                highlight: item.highlight,
                              );
                            }).toList(),
                            outputPath: _outputController.text.trim(),
                            autoTag: _autoTag,
                            tagPrefix: _tagController.text.trim(),
                          ),
                        );
                      },
                      child: Text(widget.primaryActionLabel.isEmpty
                          ? strings.scenarioConfirmAdd
                          : widget.primaryActionLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
