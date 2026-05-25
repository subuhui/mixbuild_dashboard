# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MixBuild Dashboard is a Flutter Desktop (macOS) build orchestration app for managing multi-repository workspaces. It defines, configures, and triggers build pipelines across a main project and its dependencies via YAML configuration files.

## Common Commands

```bash
# Install dependencies
fvm flutter pub get

# Run the app (macOS primary target)
fvm flutter run -d macos

# Build release
fvm flutter build macos

# Run all tests
fvm flutter test

# Run a single test file
fvm flutter test test/mixbuild_engine_test.dart

# Run a single test by name
fvm flutter test --name "tracks remote branch"

# Analyze code
fvm flutter analyze
```

**Always use `fvm flutter` instead of bare `flutter`** — the project uses fvm for SDK version management.

## Architecture

Layered structure under `lib/`:

```
app/          → App shell (theme, MaterialApp with ProviderScope)
state/        → Riverpod Notifier + immutable state
data/         → YAML config parsing, domain models
services/     → Build engine, process runner, YAML persistence, Git discovery
ui/           → Pages and shared widgets
```

### State Management (Riverpod)

Uses the Notifier pattern. Key providers in `lib/state/dashboard_controller.dart`:

- `dashboardControllerProvider` — Main state controller (`NotifierProvider<DashboardController, DashboardState>`)
- `mixbuildEngineProvider` — Build pipeline engine
- `mixbuildYamlStoreProvider` — YAML persistence layer
- `mixbuildCommandRunnerProvider` — Process execution abstraction
- `systemResourceMonitorProvider` — CPU/memory metrics
- `buildExecutionHistoryStoreProvider` — Build history persistence

State is immutable (`DashboardState` with `copyWith`), managed entirely through `DashboardController`.

### Build Pipeline

`MixbuildEngine` (`lib/services/mixbuild_engine.dart`) orchestrates 5 sequential stages:

1. **VALIDATING** — Pre-flight checks (workspace root, Git repos, tools in PATH)
2. **SYNCING** — `git fetch`, `git reset --hard`, `git clean -fd`, `git checkout <branch>`, `git pull --ff-only`
3. **RESTORING** — Serial execution of each dependency's `restore_command`
4. **BUILDING** — Executes scenario's build command (with optional `--clean`)
5. **POST_HOOK** — Auto-tag, open output directory, macOS notification

### Configuration

Workspace YAML files stored at `~/.config/mixbuild_dashboard/workspaces/<slug>.yaml`. Structure:

```yaml
workspace:
  name: "my_workspace"
  root_path: "/Users/dev/projects"
main_project:
  name: "my_app"
  path: "./my_app"
  type: "flutter"          # or "android"
  default_branch: "main"
  restore_command: "fvm flutter pub get"
dependencies:
  - name: "shared_ui"
    path: "./shared_ui"
    type: "flutter"
    default_branch: "develop"
build_scenarios:
  - name: "Debug Build"
    main_branch: "develop"
    command: "fvm flutter build macos --debug"
    dependency_overrides:
      shared_ui: "feature/new-components"
```

### Process Execution

`MixbuildCommandRunner` (`lib/services/mixbuild_command_runner.dart`) abstracts process execution. On macOS/Linux, shell commands run via `/bin/zsh -lc`. Supports live stdout/stderr callbacks and SIGKILL termination.

## Testing Patterns

Tests use fake implementations of `MixbuildCommandRunner` to avoid real process execution:

```dart
class _FakeCommandRunner implements MixbuildCommandRunner {
  // Implement all methods with controlled return values
}
```

Controller tests use `ProviderContainer` with overrides:

```dart
container = ProviderContainer(
  overrides: [
    mixbuildYamlStoreProvider.overrideWithValue(store),
    buildExecutionHistoryStoreProvider.overrideWithValue(historyStore),
    systemResourceMonitorProvider.overrideWithValue(resourceMonitor),
  ],
);
```

## UI Conventions

- Dark-only theme (`ThemeMode.dark`), colors from `MixBuildPalette` constants
- Material 3 with glass-panel style
- System font via `google_fonts` package
- macOS sandboxing via `macos_secure_bookmarks` for persistent directory access

## Key Domain Models

- `MixbuildConfig` — Parsed YAML config (workspace + main_project + dependencies + scenarios)
- `ProjectBuild` — Runtime project with scenarios
- `BuildScenario` — Single build configuration with status, logs, dependencies
- `BuildStatus` — Pipeline lifecycle enum (idle → validating → syncing → restoring → building → postHook → success/failed/interrupted)
- `BuildExecutionRecord` — Persisted build history entry
