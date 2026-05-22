import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/ui/dashboard_home_page.dart';

class MixBuildApp extends StatelessWidget {
  const MixBuildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'MixBuild Dashboard',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: MixBuildTheme.lightTheme,
        darkTheme: MixBuildTheme.darkTheme,
        home: const DashboardHomePage(),
      ),
    );
  }
}
