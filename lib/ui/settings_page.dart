import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/state/theme_controller.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeControllerProvider);
    final controller = ref.read(themeModeControllerProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          const DashboardBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: MixBuildTheme.surfacePanel(
                          context,
                          radius: 20,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_ios_new),
                              tooltip: strings.btnBack,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.navSettings,
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  strings.settingsAppearanceSubtitle,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: MixBuildTheme.surfacePanel(
                          context,
                          radius: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.palette_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(
                                strings.settingsAppearanceTitle,
                                style: theme.textTheme.titleLarge,
                              ),
                              subtitle: Text(
                                strings.settingsAppearanceSubtitle,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color:
                                    MixBuildTheme.surfaceChromeColor(context),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strings.settingsAppearanceTitle,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    strings.settingsThemeSectionNote,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 16),
                                  SegmentedButton<ThemeMode>(
                                    showSelectedIcon: false,
                                    segments: <ButtonSegment<ThemeMode>>[
                                      ButtonSegment<ThemeMode>(
                                        value: ThemeMode.system,
                                        label:
                                            Text(strings.settingsThemeSystem),
                                        icon: const Icon(Icons.brightness_auto),
                                      ),
                                      ButtonSegment<ThemeMode>(
                                        value: ThemeMode.light,
                                        label: Text(strings.settingsThemeLight),
                                        icon: const Icon(
                                          Icons.light_mode_outlined,
                                        ),
                                      ),
                                      ButtonSegment<ThemeMode>(
                                        value: ThemeMode.dark,
                                        label: Text(strings.settingsThemeDark),
                                        icon: const Icon(
                                          Icons.dark_mode_outlined,
                                        ),
                                      ),
                                    ],
                                    selected: <ThemeMode>{themeMode},
                                    onSelectionChanged: (selection) {
                                      if (selection.isNotEmpty) {
                                        controller
                                            .setThemeMode(selection.first);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DataManagementPanel(),
                    ],
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

class _DataManagementPanel extends ConsumerWidget {
  const _DataManagementPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: MixBuildTheme.surfacePanel(
        context,
        radius: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.folder_zip_outlined,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              strings.settingsDataTitle,
              style: theme.textTheme.titleLarge,
            ),
            subtitle: Text(
              strings.settingsDataSubtitle,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DataActionCard(
                  icon: Icons.upload_file_outlined,
                  title: strings.settingsExport,
                  subtitle: strings.settingsExportDesc,
                  onTap: () => _handleExport(context, ref),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DataActionCard(
                  icon: Icons.download_outlined,
                  title: strings.settingsImport,
                  subtitle: strings.settingsImportDesc,
                  onTap: () => _handleImport(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final strings = AppStrings.of(context);
    try {
      final count = await ref
          .read(dashboardControllerProvider.notifier)
          .exportConfigToZip();
      if (context.mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.exportSuccess(count))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.exportError('$e'))),
        );
      }
    }
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.settingsImportConfirmTitle),
        content: Text(strings.settingsImportConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.btnConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final count = await ref
          .read(dashboardControllerProvider.notifier)
          .importConfigFromZip();
      if (context.mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.importSuccess(count))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.importError('$e'))),
        );
      }
    }
  }
}

class _DataActionCard extends StatelessWidget {
  const _DataActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: MixBuildTheme.surfaceChromeColor(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
