import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';

class YamlEditorPage extends StatefulWidget {
  const YamlEditorPage({
    super.key,
    required this.initialValue,
    this.title,
  });

  final String initialValue;
  final String? title;

  static Future<String?> show(
    BuildContext context, {
    required String initialValue,
    String? title,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => YamlEditorPage(
          initialValue: initialValue,
          title: title,
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final lineCount = _controller.text.split('\n').length.clamp(12, 200);
    return Scaffold(
      body: Stack(
        children: [
          const DashboardBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 760, maxHeight: 760),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: MixBuildTheme.surfacePanel(radius: 24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: MixBuildPalette.surfaceHighest,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24)),
                              border: Border(
                                bottom: BorderSide(
                                    color:
                                        Colors.black.withValues(alpha: 0.08)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.data_object_outlined,
                                  color: MixBuildPalette.muted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.title ?? strings.yamlEditorTitle,
                                        style: theme.textTheme.headlineMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        strings.yamlEditorSubtitle,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              color: MixBuildPalette.surfaceLow,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    width: 52,
                                    padding: const EdgeInsets.only(
                                        top: 16, right: 10),
                                    decoration: BoxDecoration(
                                      color: MixBuildPalette.surfaceHighest,
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.black
                                              .withValues(alpha: 0.08),
                                        ),
                                      ),
                                    ),
                                    child: ListView.builder(
                                      itemCount: lineCount,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Text(
                                            '${index + 1}',
                                            textAlign: TextAlign.right,
                                            style: MixBuildTheme.monoTextStyle(
                                              fontSize: 12,
                                              color: MixBuildPalette.muted
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 10, 16, 10),
                                          decoration: BoxDecoration(
                                            color: MixBuildPalette.surface,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.black
                                                    .withValues(alpha: 0.06),
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                strings.yamlEditorFilename,
                                                style:
                                                    MixBuildTheme.monoTextStyle(
                                                  fontSize: 11,
                                                  color: MixBuildPalette.muted,
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(
                                                Icons.content_copy_outlined,
                                                size: 16,
                                                color: MixBuildPalette.muted
                                                    .withValues(alpha: 0.8),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _controller,
                                            expands: true,
                                            maxLines: null,
                                            minLines: null,
                                            keyboardType:
                                                TextInputType.multiline,
                                            style: MixBuildTheme.monoTextStyle(
                                              fontSize: 13,
                                              color: MixBuildPalette.foreground,
                                              height: 1.6,
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.all(16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: MixBuildPalette.surfaceHighest,
                              border: Border(
                                top: BorderSide(
                                    color:
                                        Colors.black.withValues(alpha: 0.08)),
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
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(strings.yamlEditorCancel),
                                ),
                                const SizedBox(width: 12),
                                FilledButton(
                                  onPressed: () => Navigator.of(context)
                                      .pop(_controller.text),
                                  child: Text(strings.yamlEditorSave),
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
          ),
        ],
      ),
    );
  }
}
