import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/ui/project_editor_page.dart';

void main() {
  testWidgets('scenario dialog keeps an initial branch in dropdown options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
        home: Scaffold(
          body: AddScenarioDialog(
            mainProject: const ScenarioBranchDraft(
              projectName: 'main_project',
              initialBranch: 'main',
              icon: Icons.flutter_dash,
              options: <String>['main', 'master'],
            ),
            dependencyDrafts: const <ScenarioBranchDraft>[],
            initialScenario: const BuildScenario(
              id: 'release',
              name: 'Release',
              subtitle: 'Release build',
              environment: 'workspace',
              mainBranch: 'feat/curl-build-trigger',
              command: 'flutter build macos',
              status: BuildStatus.idle,
              progress: 0,
              logs: <LogEntry>[],
              dependencies: <DependencyBranch>[],
              outputPath: 'build/macos',
              autoTag: true,
              tagPrefix: 'release_',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AddScenarioDialog), findsOneWidget);
  });
}
