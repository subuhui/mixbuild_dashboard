# Responsive UI Phase 1 Design

## Goal

Eliminate the most common desktop resize overflows by introducing a shared responsive shell layer and migrating the highest-traffic pages onto it without redesigning business flows.

## Problem

The current UI assumes a large desktop canvas:

- page shells rely on fixed-width sidebars and single-row toolbars
- page-level breakpoints are inconsistent and duplicated
- small-window behavior is usually "keep shrinking" instead of "change layout"

This causes RenderFlex overflow and clipped controls when the window width drops below the original design target.

## Phase 1 Scope

Phase 1 focuses on reusable layout infrastructure plus the pages that most often expose overflow:

- app-wide responsive breakpoints and spacing helpers
- dashboard home shell
- shared dashboard top bar
- project detail shell
- project editor shell

Business logic, YAML persistence, and build execution behavior stay unchanged.

## Non-Goals

- full component-library extraction
- visual redesign of cards, colors, or motion
- changing route structure or user flows
- rewriting legacy `dashboard_page.dart`

## Architecture

### 1. Responsive tokens

Create one small app-layer utility that defines:

- width breakpoints
- common shell paddings
- compact/medium/wide flags
- sidebar and panel width guidance

This replaces scattered magic numbers with one source of truth.

### 2. Responsive shell patterns

Phase 1 introduces a small set of repeatable layout behaviors:

- side navigation: rail on wide screens, drawer on narrow screens
- top bar: stacked sections on narrow widths instead of one forced row
- split content: side-by-side on wide screens, stacked on narrow screens
- sticky footer/action rows: wrap when needed instead of overflowing

### 3. Page migration strategy

Pages migrate to the new shell in this order:

1. dashboard home
2. project detail
3. project editor

Each migration uses the same breakpoints and shell rules to make phase 3 extraction straightforward later.

## Page-Level Design

### Dashboard home

- move the fixed left navigation into a drawer-backed experience on compact widths
- keep the main content centered with adaptive outer padding
- allow the top bar to grow vertically when controls need a second row

### Project detail

- replace the permanent 380px sidebar with a stacked layout on medium/narrow widths
- move the HUD overlay into normal document flow on compact widths
- preserve terminal-first focus without forcing the whole page into one wide row

### Project editor

- convert the header into a wrapping layout
- convert workspace controls and footer actions to wrapping rows
- keep the content scroll area intact, but prevent top-level horizontal squeeze

## Testing Strategy

- add widget tests for dashboard home at narrow desktop widths
- add widget tests for project detail and project editor at narrow widths
- assert the key pages render without overflow exceptions

## Phase 2 Follow-Up

Phase 2 can continue from this foundation by extracting validated patterns into reusable components such as:

- `ResponsiveScaffold`
- `AdaptiveHeader`
- `AdaptivePanelGroup`
- `AdaptiveActionBar`
- `AdaptiveFormGrid`
