/// @Author subuhui
/// @Date 2026/7/3 13:54
/// @Description 本地构建服务端口配置的状态控制器
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixbuild_dashboard/services/server_preference_store.dart';

final serverPreferenceStoreProvider = Provider<ServerPreferenceStore>((ref) {
  return const ServerPreferenceStore();
});

final buildTriggerPortControllerProvider =
    NotifierProvider<BuildTriggerPortController, int>(
  BuildTriggerPortController.new,
);

class BuildTriggerPortController extends Notifier<int> {
  @override
  int build() {
    return ref.read(serverPreferenceStoreProvider).loadPortSync();
  }

  void setPort(int port) {
    if (state == port) {
      return;
    }
    state = port;
    ref.read(serverPreferenceStoreProvider).savePortSync(port);
  }
}
