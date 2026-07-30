import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/app/mixbuild_app.dart';
import 'package:mixbuild_dashboard/mcp/mixbuild_mcp_server.dart';
import 'package:mixbuild_dashboard/services/build_execution_history_store.dart';
import 'package:mixbuild_dashboard/services/mcp_build_service.dart';
import 'package:mixbuild_dashboard/services/mixbuild_command_runner.dart';
import 'package:mixbuild_dashboard/services/mixbuild_engine.dart';
import 'package:mixbuild_dashboard/services/mixbuild_yaml_store.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--mcp')) {
    final runner = ProcessRunCommandRunner();
    final service = McpBuildService(
      const MixbuildYamlStore(),
      MixbuildEngine(runner),
      const BuildExecutionHistoryStore(),
    );
    await MixbuildMcpServer(MixbuildMcpToolHandler(service)).run();
    exit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MixBuildRoot());
}
