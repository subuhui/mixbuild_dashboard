# Responsive UI Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a shared responsive shell layer and migrate the main desktop pages so narrow window sizes no longer overflow.

**Architecture:** Introduce one app-level responsive token helper, then migrate dashboard home, project detail, and project editor to common shell behaviors: adaptive navigation, stacked toolbars, stacked split panes, and wrapping action rows. Keep business logic unchanged and validate the refactor with narrow-width widget tests.

**Tech Stack:** Flutter, Material 3, flutter_test, Riverpod

---

### Task 1: Add Responsive Regression Tests

**Files:**
- Create: `test/responsive_layout_test.dart`
- Test: `test/responsive_layout_test.dart`

- [ ] **Step 1: Write the failing tests**

Add widget tests that pump:

- `MixBuildApp` at `Size(780, 1100)`
- `ProjectDetailPage` at `Size(920, 1100)`
- `ProjectEditorPage` at `Size(860, 1100)`

Each test should render the page, pump settled frames, and assert that `tester.takeException()` returns `null`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/Users/xxz/developer/flutter/bin/flutter test test/responsive_layout_test.dart`
Expected: at least one failure caused by overflow or layout assertions under narrow widths.

- [ ] **Step 3: Implement only the minimum test helpers**

Create shared test helpers for:

- pumping a `MaterialApp`
- seeding dashboard state through `mixbuildYamlStoreProvider`
- resetting `tester.view`

- [ ] **Step 4: Run the tests again**

Run: `/Users/xxz/developer/flutter/bin/flutter test test/responsive_layout_test.dart`
Expected: tests still fail, but only because production layout has not been fixed yet.

### Task 2: Add Shared Responsive Tokens

**Files:**
- Create: `lib/app/responsive_layout.dart`
- Modify: `lib/ui/dashboard_home_page.dart`
- Modify: `lib/ui/dashboard_widgets.dart`
- Modify: `lib/ui/project_detail_page.dart`
- Modify: `lib/ui/project_editor_page.dart`
- Test: `test/responsive_layout_test.dart`

- [ ] **Step 1: Write the failing usage expectation**

Use the tests from Task 1 as the failing safety net. Do not add production code before confirming they fail.

- [ ] **Step 2: Add the token helper**

Add a compact app utility that exposes:

- `isCompact`
- `isMedium`
- `isWide`
- `shellPadding`
- `contentPadding`

- [ ] **Step 3: Run the narrow-width tests**

Run: `/Users/xxz/developer/flutter/bin/flutter test test/responsive_layout_test.dart`
Expected: still failing because pages have not been migrated yet.

### Task 3: Migrate Dashboard Home and Shared Top Bar

**Files:**
- Modify: `lib/ui/dashboard_home_page.dart`
- Modify: `lib/ui/dashboard_widgets.dart`
- Test: `test/responsive_layout_test.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Implement adaptive navigation shell**

Change dashboard home so:

- wide widths show the existing left rail
- compact widths move the rail content into a drawer
- the app bar area exposes a menu button when the drawer is used

- [ ] **Step 2: Implement adaptive top bar behavior**

Change the shared top bar so:

- wide widths keep the single-row layout
- medium widths move the workspace selector onto its own row
- compact widths use icon actions and allow vertical growth instead of fixed height

- [ ] **Step 3: Run dashboard-focused tests**

Run: `/Users/xxz/developer/flutter/bin/flutter test test/responsive_layout_test.dart test/widget_test.dart`
Expected: dashboard narrow-width tests pass.

### Task 4: Migrate Project Detail Shell

**Files:**
- Modify: `lib/ui/project_detail_page.dart`
- Test: `test/responsive_layout_test.dart`

- [ ] **Step 1: Implement stacked detail layout**

Change project detail so:

- wide widths keep sidebar + terminal layout
- medium and compact widths stack the sidebar above the terminal panel
- the HUD overlay becomes an in-flow section on compact widths

- [ ] **Step 2: Make sidebar width adaptive**

Replace the fixed-width sidebar assumption with max-width constraints that work in both stacked and side-by-side layouts.

- [ ] **Step 3: Run detail-page tests**

Run: `/Users/xxz/developer/flutter/bin/flutter test test/responsive_layout_test.dart`
Expected: detail-page narrow-width test passes.

### Task 5: Migrate Project Editor Shell

**Files:**
- Modify: `lib/ui/project_editor_page.dart`
- Test: `test/project_editor_page_test.dart`
- Test: `test/responsive_layout_test.dart`

- [ ] **Step 1: Convert header and footer rows to wrapping layouts**

Make the top title/input row and bottom action row wrap cleanly under reduced width.

- [ ] **Step 2: Convert workspace controls to adaptive wrapping**

Make the workspace path field and action buttons wrap vertically when needed.

- [ ] **Step 3: Run editor tests**

Run: `/Users/xxz/developer/flutter/bin/flutter test test/project_editor_page_test.dart test/responsive_layout_test.dart`
Expected: editor narrow-width test passes and existing editor tests remain green.

### Task 6: Verify Phase 1 End-to-End

**Files:**
- Modify: `docs/superpowers/specs/2026-05-24-responsive-ui-phase1-design.md`
- Modify: `docs/superpowers/plans/2026-05-24-responsive-ui-phase1.md`

- [ ] **Step 1: Run targeted verification**

Run:

- `/Users/xxz/developer/flutter/bin/flutter test test/responsive_layout_test.dart test/widget_test.dart test/project_editor_page_test.dart`
- `/Users/xxz/developer/flutter/bin/flutter analyze`

Expected: tests pass and analyzer reports no issues.

- [ ] **Step 2: Update the docs if implementation diverged**

Document any scope changes or deferred follow-ups directly in the spec and plan files.
