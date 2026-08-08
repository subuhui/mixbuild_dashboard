import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/ui/dashboard_widgets.dart';

void main() {
  test('light and dark input hints meet normal text contrast', () {
    for (final theme in <ThemeData>[
      MixBuildTheme.lightTheme,
      MixBuildTheme.darkTheme,
    ]) {
      final foreground = theme.inputDecorationTheme.hintStyle!.color!;
      final background = theme.inputDecorationTheme.fillColor!;
      expect(_contrastRatio(foreground, background), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('status pulse stops when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN')],
          home: const Scaffold(body: StatusChip(status: BuildStatus.building)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('BUILDING'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance();
  final darker = background.computeLuminance();
  final max = lighter > darker ? lighter : darker;
  final min = lighter > darker ? darker : lighter;
  return (max + 0.05) / (min + 0.05);
}
