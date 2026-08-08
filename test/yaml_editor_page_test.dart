import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/l10n/app_strings.dart';
import 'package:mixbuild_dashboard/ui/yaml_editor_page.dart';

void main() {
  testWidgets('line numbers follow edits and invalid YAML stays open', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const YamlEditorPage(
          initialValue: 'workspace:\n  name: demo\n  root: /tmp/demo',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('yaml-line-number-3')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('yaml-editor-text')),
      'workspace:\n  name: demo\n  root: /tmp/demo\n  mode: debug',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('yaml-line-number-4')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('yaml-editor-text')),
      'workspace: [',
    );
    await tester.tap(find.byKey(const ValueKey('yaml-editor-save')));
    await tester.pump();

    expect(find.byType(YamlEditorPage), findsOneWidget);
    expect(find.byKey(const ValueKey('yaml-editor-error')), findsOneWidget);
  });

  testWidgets('dirty editor asks before closing and copy is actionable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const YamlEditorPage(initialValue: 'workspace:\n  name: demo')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('yaml-editor-copy')));
    await tester.pump();
    expect(find.text('已复制 YAML 内容'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('yaml-editor-text')),
      'workspace:\n  name: changed',
    );
    await tester.tap(find.byKey(const ValueKey('yaml-editor-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('yaml-discard-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('yaml-discard')));
    await tester.pumpAndSettle();
    expect(find.byType(YamlEditorPage), findsNothing);
  });

  testWidgets('escape closes an unchanged editor', (tester) async {
    await tester.pumpWidget(
      _testApp(const YamlEditorPage(initialValue: 'workspace:\n  name: demo')),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(YamlEditorPage), findsNothing);
  });

  testWidgets('control or command S saves and closes valid YAML', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const YamlEditorPage(initialValue: 'workspace:\n  name: demo')),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byType(YamlEditorPage), findsNothing);
  });

  testWidgets('long YAML keeps line numbers scrollable with the editor', (
    tester,
  ) async {
    final content = List<String>.generate(
      200,
      (index) => 'key_$index: value_$index',
    ).join('\n');
    await tester.pumpWidget(_testApp(YamlEditorPage(initialValue: content)));
    await tester.pumpAndSettle();

    final lineNumbers = find.byKey(const ValueKey('yaml-line-numbers'));
    expect(tester.getSize(lineNumbers).height, greaterThan(0));
    final lineList = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final editor = tester.state<ScrollableState>(find.byType(Scrollable).at(1));
    expect(lineList.position.maxScrollExtent, greaterThan(0));
    expect(editor.position.maxScrollExtent, greaterThan(0));
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
    locale: const Locale('zh', 'CN'),
    home: child,
  );
}
