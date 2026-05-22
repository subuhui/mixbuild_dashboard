# MixBuild Dashboard

基于 Flutter Desktop 的多仓库构建编排仪表盘。通过 YAML 配置文件定义、配置和触发主项目及其依赖仓库的构建流水线。

## 功能特性

- **工作区拓扑** — 在单个 YAML 配置中定义主项目和多个依赖仓库
- **构建场景** — 配置 debug、release、hotfix 等场景，支持每个场景单独覆盖依赖分支
- **流水线执行** — 自动化阶段：预检 → Git 同步 → 依赖恢复 → 构建 → 后置钩子
- **实时日志** — 终端风格的构建日志面板，带行号和进度跟踪
- **Git 自动发现** — 递归扫描工作区目录，自动识别 Git 仓库并枚举分支
- **YAML 编辑器** — 支持可视化和原始文本两种方式编辑工作区配置
- **macOS 沙盒** — 通过安全作用域书签持久化目录访问权限
- **明暗主题** — 跟随系统切换，玻璃拟态 UI 风格

## 快速开始

### 环境要求

- Flutter SDK ^3.12.0（推荐通过 [fvm](https://fvm.app/) 管理）
- macOS（主要目标平台）
- Git

### 安装

```bash
# 克隆
git clone https://github.com/subuhui/mixbuild_dashboard.git
cd mixbuild_dashboard

# 安装依赖
fvm flutter pub get

# 运行
fvm flutter run -d macos
```

### 构建

```bash
fvm flutter build macos
```

## 项目结构

```
lib/
  main.dart                            # 入口，书签恢复
  app/
    mixbuild_app.dart                  # MaterialApp + ProviderScope
    mixbuild_theme.dart                # 调色板（明/暗）+ Material 3 主题
  state/
    dashboard_controller.dart          # Riverpod Notifier — 核心业务逻辑
    dashboard_state.dart               # 不可变状态 + copyWith
  data/
    mixbuild_config.dart               # YAML 配置解析
    mixbuild_models.dart               # 领域模型（BuildStatus、ProjectBuild 等）
    mixbuild_repository.dart           # 示例/演示数据
  services/
    mixbuild_engine.dart               # 构建流水线编排器
    mixbuild_command_runner.dart       # 进程执行抽象
    mixbuild_yaml_store.dart           # YAML 文件持久化 + 文件监听
    git_branch_discovery.dart          # Git 分支枚举
    git_project_discovery.dart         # 递归 Git 仓库发现
    workspace_bookmark_service.dart    # macOS 沙盒书签持久化
  ui/
    dashboard_home_page.dart           # 主页 — 侧边栏 + 项目卡片
    dashboard_page.dart                # 备选仪表盘，矩阵布局
    project_detail_page.dart           # 构建详情 — 流水线头部 + 终端日志
    project_editor_page.dart           # 工作区/项目配置编辑器
    yaml_editor_page.dart              # 原始 YAML 文本编辑器
    dashboard_widgets.dart             # 共享可复用组件
```

## 配置说明

工作区配置文件存储在 `~/.config/mixbuild_dashboard/workspaces/`。

### 配置示例

```yaml
workspace:
  name: "my_workspace"
  root_path: "/Users/dev/projects"
main_project:
  name: "my_app"
  path: "./my_app"
  type: "flutter"
  default_branch: "main"
  restore_command: "fvm flutter pub get"
dependencies:
  - name: "shared_ui"
    path: "./shared_ui"
    type: "flutter"
    default_branch: "develop"
    restore_command: "fvm flutter pub get"
build_scenarios:
  - name: "Debug Build"
    main_branch: "develop"
    command: "fvm flutter build macos --debug"
    output_dir: "build/macos/Build/Products/Debug"
    auto_tag: false
    dependency_overrides:
      shared_ui: "feature/new-components"
  - name: "Release Build"
    main_branch: "main"
    command: "fvm flutter build macos --release"
    output_dir: "build/macos/Build/Products/Release"
    auto_tag: true
    tag_prefix: "release_"
```

## 构建流水线阶段

| 阶段 | 说明 |
|---|---|
| **VALIDATING** | 预检 — 工作区根目录、Git 仓库、PATH 中的必要工具 |
| **SYNCING** | `git fetch`、`git reset --hard`、`git clean -fd`、`git checkout <branch>` |
| **RESTORING** | 串行执行各依赖的 `restore_command` |
| **BUILDING** | 执行场景的构建命令（可选 `--clean`） |
| **POST_HOOK** | 自动打标签、打开输出目录、macOS 通知 |

## 状态管理

使用 [Riverpod](https://riverpod.dev/) 的 Notifier 模式：

- `dashboardControllerProvider` — 主状态控制器（`NotifierProvider<DashboardController, DashboardState>`）
- `mixbuildEngineProvider` — 构建流水线引擎
- `mixbuildYamlStoreProvider` — YAML 持久化层
- `mixbuildCommandRunnerProvider` — 进程执行器

## 技术栈

| 层级 | 技术 |
|---|---|
| 框架 | Flutter Desktop (macOS) |
| 状态管理 | Riverpod ^2.6.1 |
| 配置 | YAML ^3.1.3 |
| 进程执行 | process_run ^1.3.3 |
| 字体 | google_fonts ^6.3.0 |
| 沙盒 | macos_secure_bookmarks ^0.2.1 |
| 设计 | Material 3、玻璃拟态 UI、系统明暗主题 |

## 许可证

私有项目 — 不公开发布（`publish_to: 'none'`）。
