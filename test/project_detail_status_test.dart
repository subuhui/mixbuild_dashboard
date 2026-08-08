import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';
import 'package:mixbuild_dashboard/ui/project_detail_page.dart';

void main() {
  test('pipeline sequence includes restoring and terminal states', () {
    expect(
      pipelineStatusesFor(BuildStatus.restoring),
      contains(BuildStatus.restoring),
    );
    expect(pipelineStatusesFor(BuildStatus.success).last, BuildStatus.success);
    expect(pipelineStatusesFor(BuildStatus.failed).last, BuildStatus.failed);
    expect(
      pipelineStatusesFor(BuildStatus.interrupted).last,
      BuildStatus.interrupted,
    );
  });
}
