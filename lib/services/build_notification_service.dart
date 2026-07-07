/// @Author subuhui
/// @Date 2026/7/7 19:24
/// @Description 构建完成通知的跨平台发送入口
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';

abstract class BuildNotificationService {
  Future<void> notifyBuildFinished({
    required String projectName,
    required String scenarioName,
    required BuildStatus status,
  });
}

class NativeBuildNotificationService implements BuildNotificationService {
  const NativeBuildNotificationService();

  static const MethodChannel _channel =
      MethodChannel('mixbuild_dashboard/build_notifications');

  @override
  Future<void> notifyBuildFinished({
    required String projectName,
    required String scenarioName,
    required BuildStatus status,
  }) async {
    if (!Platform.isMacOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('showBuildNotification', {
        'title': 'MixBuild Dashboard',
        'body':
            '$projectName / $scenarioName 构建状态：${status.name.toUpperCase()}',
      });
    } on MissingPluginException {
      return;
    }
  }
}
