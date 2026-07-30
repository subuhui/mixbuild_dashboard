import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/app/mixbuild_app.dart';
import 'package:mixbuild_dashboard/ui/dashboard_home_page.dart';

void main() {
  testWidgets('dashboard renders key sections', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MixBuildApp());
    await tester.pumpAndSettle();

    expect(find.text('MixBuild Dashboard v1.0'), findsOneWidget);
    expect(find.text('新增项目'), findsOneWidget);
    expect(find.byType(ProjectOverviewCard), findsWidgets);
  });
}
