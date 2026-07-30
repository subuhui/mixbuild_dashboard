import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/services/theme_preference_store.dart';

final themePreferenceStoreProvider = Provider<ThemePreferenceStore>((ref) {
  return const ThemePreferenceStore();
});

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ref.read(themePreferenceStoreProvider).loadThemeModeSync();
  }

  void setThemeMode(ThemeMode themeMode) {
    if (state == themeMode) {
      return;
    }
    state = themeMode;
    ref.read(themePreferenceStoreProvider).saveThemeModeSync(themeMode);
  }
}
