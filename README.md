# MixBuild Dashboard

A Flutter Desktop build orchestration dashboard for managing multi-repository workspaces. Define, configure, and trigger build pipelines across a main project and its dependencies — all driven by YAML configuration files.

## Features

- **Workspace Topology** — Define a main project plus multiple dependency repositories in a single YAML config
- **Build Scenarios** — Configure debug, release, hotfix (and more) scenarios with per-scenario dependency branch overrides
- **Pipeline Execution** — Automated stages: preflight validation → Git sync → dependency restore → build → post-hooks
- **Real-time Logs** — Terminal-style build log panel with line numbers and progress tracking
- **Git Auto-discovery** — Recursively scan workspace directories for Git repos and enumerate branches
- **YAML Editor** — Visual and raw-text editing of workspace configuration files
- **macOS Sandboxing** — Persistent directory access via security-scoped bookmarks
- **Light/Dark Theme** — System-aware theme with glass-panel UI style

## Getting Started

### Prerequisites

- Flutter SDK ^3.12.0 (via [fvm](https://fvm.app/) recommended)
- macOS (primary target platform)
- Git

### Install

```bash
# Clone
git clone https://github.com/subuhui/mixbuild_dashboard.git
cd mixbuild_dashboard

# Install dependencies
fvm flutter pub get

# Run
fvm flutter run -d macos
```

### Build

```bash
fvm flutter build macos
```

## Project Structure

```
lib/
  main.dart                            # Entry point, bookmark restoration
  app/
    mixbuild_app.dart                  # MaterialApp with ProviderScope
    mixbuild_theme.dart                # Color palette (light/dark) + Material 3 theme
  state/
    dashboard_controller.dart          # Riverpod Notifier — main business logic
    dashboard_state.dart               # Immutable state with copyWith
  data/
    mixbuild_config.dart               # YAML config parsing
    mixbuild_models.dart               # Domain models (BuildStatus, ProjectBuild, etc.)
    mixbuild_repository.dart           # Sample/demo data
  services/
    mixbuild_engine.dart               # Build pipeline orchestrator
    mixbuild_command_runner.dart       # Process execution abstraction
    mixbuild_yaml_store.dart           # YAML file persistence + file watching
    git_branch_discovery.dart          # Git branch enumeration
    git_project_discovery.dart         # Recursive Git repo discovery
    workspace_bookmark_service.dart    # macOS sandbox bookmark persistence
  ui/
    dashboard_home_page.dart           # Main landing page — sidebar + project cards
    dashboard_page.dart                # Alternative dashboard with matrix layout
    project_detail_page.dart           # Build detail — pipeline header + terminal log
    project_editor_page.dart           # Workspace/project configuration editor
    yaml_editor_page.dart              # Raw YAML text editor
    dashboard_widgets.dart             # Shared reusable widgets
```

## Configuration

Workspace configs are stored as YAML files at `~/.config/mixbuild_dashboard/workspaces/`.

Project `type` supports `flutter`, `android`, and `ios`.

### Example

```yaml
workspace:
  name: "my_workspace"
  root_path: "/Users/dev/projects"
main_project:
  name: "my_app"
  path: "./my_app"
  type: "flutter"
  restore_command: "fvm flutter pub get"
dependencies:
  - name: "shared_ui"
    path: "./shared_ui"
    type: "flutter"
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

## Build Pipeline Stages

| Stage | Description |
|---|---|
| **VALIDATING** | Pre-flight checks — workspace root, Git repos, required tools in PATH |
| **SYNCING** | `git fetch`, `git reset --hard`, `git clean -fd`, `git checkout <branch>` |
| **RESTORING** | Runs each dependency's `restore_command` serially |
| **BUILDING** | Executes the scenario's build command (with optional `--clean`) |
| **POST_HOOK** | Auto-tag, open output directory, macOS notification |

## Remote Build Trigger (HTTP API)

The dashboard includes a local HTTP server on port `8765` by default. The port can be changed from Settings.

```bash
# Trigger by scenario name
curl -X POST http://127.0.0.1:8765/build \
  -H "Content-Type: application/json" \
  -d '{"scenario": "Release Build", "branch": "release/v1.2"}'

# Trigger by main project or dependency name
curl -X POST http://127.0.0.1:8765/build \
  -H "Content-Type: application/json" \
  -d '{"project": "flutter.module.ui", "branch": "release/v1.2"}'
```

`branch` is required, and at least one of `scenario` or `project` must be supplied. The server returns `202` when the build is queued, `400` for invalid input, `404` when no matching configuration exists, and `409` while another build is running.

## State Management

Uses [Riverpod](https://riverpod.dev/) with the Notifier pattern:

- `dashboardControllerProvider` — Main state controller (`NotifierProvider<DashboardController, DashboardState>`)
- `mixbuildEngineProvider` — Build pipeline engine
- `mixbuildYamlStoreProvider` — YAML persistence layer
- `mixbuildCommandRunnerProvider` — Process execution

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter Desktop (macOS) |
| State | Riverpod ^2.6.1 |
| Config | YAML ^3.1.3 |
| Process | process_run ^1.3.3 |
| Fonts | google_fonts ^6.3.0 |
| Sandbox | macos_secure_bookmarks ^0.2.1 |
| Design | Material 3, glass-panel UI, system light/dark theme |

## License

Private — not published (`publish_to: 'none'`).
