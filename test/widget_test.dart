import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/app/mixbuild_app.dart';

void main() {
  testWidgets('dashboard renders key sections', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MixBuildApp());
    await tester.pumpAndSettle();

    expect(find.text('MixBuild Dashboard v3.1'), findsOneWidget);
    expect(find.text('New Project'), findsOneWidget);
    expect(find.textContaining('项目 A：'), findsWidgets);
  });
}
