import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
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
