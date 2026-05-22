import 'package:flutter/material.dart';
import 'package:mixbuild_dashboard/app/mixbuild_theme.dart';
import 'package:mixbuild_dashboard/data/mixbuild_models.dart';

/// 静态示例数据仓库，提供开发/演示用的项目、指标和全局配置。
///
/// 生产环境由 [DashboardController] 从 YAML 文件动态加载数据。
class MixBuildRepository {
  static List<ProjectBuild> projects() {
    return [
      ProjectBuild(
        id: 'project-a',
        emoji: '🚚',
        name: '项目 A：物流核心平台',
        description: '隔离打包区',
        branch: 'release/v3.1',
        scenarios: [
          BuildScenario(
            id: 'a-debug',
            name: '常规测试包 (Debug)',
            subtitle: '本地快速构建',
            environment: 'production (debug)',
            mainBranch: 'release/v3.1',
            command: './gradlew assembleDebug',
            status: BuildStatus.idle,
            progress: 0,
            outputPath: 'build/app/outputs/flutter-apk/',
            autoTag: false,
            tagPrefix: 'debug_',
            yamlOverride:
                'dependencies:\n  analytics_sdk:\n    branch: develop\n',
            dependencies: [
              DependencyBranch(
                  name: 'common_ui',
                  branch: 'develop',
                  icon: Icons.layers_outlined),
              DependencyBranch(
                  name: 'net_bridge',
                  branch: 'master',
                  icon: Icons.hub_outlined),
            ],
            logs: [
              LogEntry(
                time: '14:30:05',
                level: 'INIT',
                message: 'Ready to receive build command for project: 物流核心平台',
                accent: MixBuildPalette.primary,
              ),
              LogEntry(
                time: '14:30:06',
                level: 'INFO',
                message: 'Workspace cache is warm. No sync required.',
                accent: MixBuildPalette.success,
              ),
            ],
          ),
          BuildScenario(
            id: 'a-release',
            name: 'FVM 生产发布包 (Release)',
            subtitle: '云端隔离构建',
            environment: 'production (release-v3.1)',
            mainBranch: 'release/v3.1',
            command: 'fvm flutter build ipa --release',
            status: BuildStatus.restoring,
            progress: 0.41,
            outputPath: 'output/releases/ios/',
            autoTag: true,
            tagPrefix: 'release_',
            yamlOverride:
                'dependencies:\n  react:\n    env:\n      NODE_ENV: production\n',
            dependencies: [
              DependencyBranch(
                  name: 'common_ui',
                  branch: 'release/3.1',
                  icon: Icons.layers_outlined),
              DependencyBranch(
                name: 'analytics_sdk',
                branch: 'feature/perf',
                icon: Icons.analytics_outlined,
                isOverride: true,
                highlight: MixBuildPalette.warning,
              ),
              DependencyBranch(
                  name: 'net_bridge',
                  branch: 'master',
                  icon: Icons.hub_outlined),
            ],
            logs: [
              LogEntry(
                time: '17:50:56',
                level: 'INFO',
                message: 'Running restore command: fvm flutter pub get',
                accent: MixBuildPalette.warning,
              ),
              LogEntry(
                time: '17:51:05',
                level: 'INFO',
                message:
                    'common_ui restored successfully. Waiting for analytics_sdk',
                accent: MixBuildPalette.warning,
              ),
              LogEntry(
                time: '17:51:11',
                level: 'WARN',
                message:
                    'analytics_sdk missing same-name branch, fallback to default_branch',
                accent: MixBuildPalette.warning,
              ),
              LogEntry(
                time: '17:51:38',
                level: 'INFO',
                message:
                    'Restore queue remains serial to avoid cache lock conflicts.',
                accent: MixBuildPalette.warning,
              ),
            ],
          ),
        ],
      ),
      ProjectBuild(
        id: 'project-b',
        emoji: '🛒',
        name: '项目 B：供应链管理系统',
        description: '依赖扫描中',
        branch: 'develop',
        scenarios: [
          BuildScenario(
            id: 'b-auto-test',
            name: '自动化测试加固包',
            subtitle: '依赖安全检查',
            environment: 'staging (supply-chain)',
            mainBranch: 'develop',
            command: './gradlew app:assembleQa',
            status: BuildStatus.syncing,
            progress: 0.23,
            outputPath: 'output/qa/',
            autoTag: false,
            tagPrefix: 'qa_',
            dependencies: [
              DependencyBranch(
                name: 'react',
                branch: 'feature/v18-support',
                icon: Icons.code_outlined,
                highlight: MixBuildPalette.warning,
              ),
              DependencyBranch(
                name: 'webpack',
                branch: '覆写',
                icon: Icons.settings_applications_outlined,
                isOverride: true,
                highlight: MixBuildPalette.error,
              ),
              DependencyBranch(
                  name: 'terser-webpack',
                  branch: '跟随',
                  icon: Icons.compress_outlined),
            ],
            logs: [
              LogEntry(
                time: '17:51:02',
                level: 'INFO',
                message: 'Fetching external dependencies: 112/480',
                accent: MixBuildPalette.tertiary,
              ),
              LogEntry(
                time: '17:51:08',
                level: 'INFO',
                message:
                    'Dependency graph diff completed, 2 overrides detected',
                accent: MixBuildPalette.tertiary,
              ),
              LogEntry(
                time: '17:51:20',
                level: 'WARN',
                message:
                    'webpack branch missing remotely, fallback to default_branch=main',
                accent: MixBuildPalette.warning,
              ),
            ],
          ),
          BuildScenario(
            id: 'b-patch',
            name: '热修复回归包',
            subtitle: '等待审批',
            environment: 'release/hotfix',
            mainBranch: 'develop',
            command: './build.sh --hotfix',
            status: BuildStatus.failed,
            progress: 0,
            outputPath: 'output/hotfix/',
            autoTag: true,
            tagPrefix: 'hotfix_',
            dependencies: [
              DependencyBranch(
                name: 'common_ui',
                branch: 'hotfix/button-alignment',
                icon: Icons.layers_outlined,
                isOverride: true,
                highlight: MixBuildPalette.primary,
              ),
            ],
            logs: [
              LogEntry(
                time: '13:18:20',
                level: 'ERROR',
                message:
                    'Pre-flight failed: required tool `fvm` was not found in PATH',
                accent: MixBuildPalette.error,
              ),
            ],
          ),
        ],
      ),
    ];
  }

  static List<ResourceMetric> metrics() {
    return [
      ResourceMetric(
          label: 'CPU',
          value: '12%',
          progress: 0.12,
          color: MixBuildPalette.tertiary),
      ResourceMetric(
          label: 'MEM',
          value: '4.2GB',
          progress: 0.35,
          color: MixBuildPalette.warning),
      ResourceMetric(
          label: 'Queue',
          value: '3 Jobs',
          progress: 0.58,
          color: MixBuildPalette.primary),
    ];
  }

  static GlobalConfig globalConfig() {
    return const GlobalConfig(
      workspaceRoot: '/Users/admin/Dev/mixbuild_workspace',
      activeProjectName: '项目A (物流)',
      bindings: [
        WorkspaceBinding(projectName: 'MainRunner', path: './core/app'),
        WorkspaceBinding(projectName: 'GatewayShell', path: './modules/shared'),
        WorkspaceBinding(
            projectName: 'BuildScripts', path: './tooling/build_scripts'),
        WorkspaceBinding(
            projectName: 'ArtifactStore', path: './infra/artifacts'),
      ],
    );
  }
}
