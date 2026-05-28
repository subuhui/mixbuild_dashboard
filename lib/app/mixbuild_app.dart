import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/ui/dashboard_home_page.dart';

/// 应用根 Widget，提供 Riverpod 作用域和 Material 主题配置。
class MixBuildApp extends StatelessWidget {
  const MixBuildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'MixBuild Dashboard',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: MixBuildTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        locale: const Locale('zh', 'CN'),
        home: const DashboardHomePage(),
      ),
    );
  }
}
