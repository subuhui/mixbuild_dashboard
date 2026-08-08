import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';
import 'package:yaml/yaml.dart';

class YamlEditorPage extends StatefulWidget {
  const YamlEditorPage({
    super.key,
    required this.initialValue,
    this.title,
    this.onSave,
  });

  final String initialValue;
  final String? title;
  final Future<void> Function(String value)? onSave;

  static Future<String?> show(
    BuildContext context, {
    required String initialValue,
    String? title,
    Future<void> Function(String value)? onSave,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => YamlEditorPage(
          initialValue: initialValue,
          title: title,
          onSave: onSave,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<YamlEditorPage> createState() => _YamlEditorPageState();
}

class _YamlEditorPageState extends State<YamlEditorPage> {
  late final TextEditingController _controller;
  late final ScrollController _lineNumberScrollController;
  late final ScrollController _editorScrollController;
  String? _errorMessage;
  bool _syncingScroll = false;

  bool get _isDirty => _controller.text != widget.initialValue;
  int get _lineCount => _controller.text.split('\n').length;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..addListener(_handleTextChanged);
    _lineNumberScrollController = ScrollController()
      ..addListener(_syncEditorToLineNumbers);
    _editorScrollController = ScrollController()
      ..addListener(_syncLineNumbersToEditor);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _lineNumberScrollController.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (!mounted) return;
    setState(() => _errorMessage = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncLineNumbersToEditor();
    });
  }

  void _syncLineNumbersToEditor() {
    if (_syncingScroll ||
        !_editorScrollController.hasClients ||
        !_lineNumberScrollController.hasClients) {
      return;
    }
    _syncingScroll = true;
    final target = _lineNumberScrollController.offset.clamp(
      0.0,
      _editorScrollController.position.maxScrollExtent,
    );
    _editorScrollController.jumpTo(target);
    _syncingScroll = false;
  }

  void _syncEditorToLineNumbers() {
    if (_syncingScroll ||
        !_editorScrollController.hasClients ||
        !_lineNumberScrollController.hasClients) {
      return;
    }
    _syncingScroll = true;
    final target = _editorScrollController.offset.clamp(
      0.0,
      _lineNumberScrollController.position.maxScrollExtent,
    );
    _lineNumberScrollController.jumpTo(target);
    _syncingScroll = false;
  }

  void _copyYaml() {
    unawaited(Clipboard.setData(ClipboardData(text: _controller.text)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).yamlCopied)));
  }

  Future<void> _save() async {
    final strings = AppStrings.of(context);
    try {
      loadYaml(_controller.text);
      if (widget.onSave != null) {
        await widget.onSave!(_controller.text);
      }
      if (mounted) Navigator.of(context).pop(_controller.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = strings.yamlSaveError('$error');
      });
    }
  }

  Future<void> _attemptClose() async {
    if (!_isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final strings = AppStrings.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('yaml-discard-dialog'),
        title: Text(strings.yamlDiscardTitle),
        content: Text(strings.yamlDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.yamlEditorCancel),
          ),
          FilledButton(
            key: const ValueKey('yaml-discard'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: Text(strings.yamlDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_attemptClose());
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
          const SingleActivator(LogicalKeyboardKey.escape): _attemptClose,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                const DashboardBackground(),
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 840,
                          maxHeight: 820,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: MixBuildTheme.surfacePanel(
                              context,
                              radius: 16,
                            ),
                            child: Column(
                              children: [
                                _buildHeader(theme, strings),
                                Expanded(child: _buildEditor()),
                                if (_errorMessage != null)
                                  Container(
                                    key: const ValueKey('yaml-editor-error'),
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      10,
                                      20,
                                      10,
                                    ),
                                    color: theme.colorScheme.errorContainer,
                                    child: Text(
                                      _errorMessage!,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onErrorContainer,
                                          ),
                                    ),
                                  ),
                                _buildFooter(theme, strings),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: MixBuildPalette.surfaceHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: MixBuildPalette.foreground.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.data_object_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ?? strings.yamlEditorTitle,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  strings.yamlEditorSubtitle,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('yaml-editor-close'),
            onPressed: _attemptClose,
            icon: const Icon(Icons.close),
            tooltip: strings.btnClose,
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      color: MixBuildPalette.surfaceLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: ListView.builder(
              key: const ValueKey('yaml-line-numbers'),
              controller: _lineNumberScrollController,
              padding: const EdgeInsets.only(top: 16),
              itemCount: _lineCount,
              itemBuilder: (context, index) => SizedBox(
                key: ValueKey('yaml-line-number-${index + 1}'),
                height: 20.8,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.right,
                  style: MixBuildTheme.monoTextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: MixBuildPalette.muted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: MixBuildPalette.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: MixBuildPalette.foreground.withValues(
                          alpha: 0.06,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        AppStrings.of(context).yamlEditorFilename,
                        style: MixBuildTheme.monoTextStyle(
                          fontSize: 11,
                          color: MixBuildPalette.muted,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('yaml-editor-copy'),
                        onPressed: _copyYaml,
                        icon: const Icon(Icons.content_copy_outlined, size: 17),
                        tooltip: AppStrings.of(context).yamlCopied,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('yaml-editor-text'),
                    controller: _controller,
                    scrollController: _editorScrollController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    style: MixBuildTheme.monoTextStyle(
                      fontSize: 13,
                      color: MixBuildPalette.foreground,
                      height: 1.6,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: MixBuildPalette.surfaceHighest,
        border: Border(
          top: BorderSide(
            color: MixBuildPalette.foreground.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              strings.yamlEditorFooter,
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: _attemptClose,
            child: Text(strings.yamlEditorCancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const ValueKey('yaml-editor-save'),
            onPressed: _save,
            child: Text(strings.yamlEditorSave),
          ),
        ],
      ),
    );
  }
}
