import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/app/mixbuild_app.dart';
import 'package:mixbuild_dashboard/services/build_trigger_server.dart';
import 'package:mixbuild_dashboard/state/dashboard_controller.dart';
import 'package:mixbuild_dashboard/ui/dashboard_home_page.dart';

void main() {
  testWidgets('dashboard renders key sections', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buildTriggerServerProvider.overrideWithValue(
            BuildTriggerServer(
              port: 0,
              onTrigger: (_) async => const RemoteBuildTriggerResult.rejected(
                statusCode: 503,
                message: 'disabled in widget test',
              ),
            ),
          ),
        ],
        child: const MixBuildApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('MixBuild Dashboard'), findsWidgets);
    expect(find.text('新增项目'), findsOneWidget);
    expect(find.byType(ProjectOverviewCard), findsWidgets);
  });
}
