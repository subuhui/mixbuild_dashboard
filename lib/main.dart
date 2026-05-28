import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/app/mixbuild_app.dart';
import 'package:mixbuild_dashboard/services/workspace_bookmark_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 恢复上次已授权目录的 security-scoped bookmark 访问权限
  await WorkspaceBookmarkService().restoreAll();
  runApp(const MixBuildRoot());
}
