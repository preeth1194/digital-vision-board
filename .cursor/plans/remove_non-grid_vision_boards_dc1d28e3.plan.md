---
name: Remove non-grid vision boards
overview: Remove all freeform and goal_canvas vision board types, their screens, widgets, models, and services, keeping only the grid board type. Existing non-grid boards will be deleted on load.
todos:
  - id: phase1-delete-files
    content: Delete 9 exclusively non-grid files (2 screens, 4 widgets, 1 image widget, 2 model files)
    status: pending
  - id: phase2-update-models
    content: Update vision_board_info.dart, vision_components.dart, vision_component_factory.dart, board_template.dart to remove freeform/goal_canvas
    status: pending
  - id: phase3-update-screens
    content: Update dashboard_screen.dart, vision_board_home_widgets.dart, template_gallery_screen.dart, habits_list_screen.dart, global_insights_screen.dart -- remove all non-grid routing and UI
    status: pending
  - id: phase4-update-services
    content: Update boards_storage_service.dart, sync_service.dart, habit_storage_service.dart, affirmation_service.dart, puzzle services, geofence service -- remove non-grid branches
    status: pending
  - id: phase5-update-widgets
    content: Update dashboard_body.dart, habit_tracker_header.dart, add_habit_modal.dart, journal_notes_screen.dart -- remove non-grid code paths
    status: pending
  - id: phase6-cleanup-unused
    content: Clean up _unused/ directory files with canvas references
    status: pending
  - id: phase7-verify
    content: Run flutter analyze, fix lint errors, verify clean build
    status: pending
isProject: false
---

# Remove Non-Grid Vision Board Types

## Context

The app currently has 3 vision board layout types defined in `[lib/models/vision_board_info.dart](lib/models/vision_board_info.dart)`:

- `freeform` (legacy canvas)
- `goal_canvas` (Canva-style drag/resize layers)
- `grid` (template-driven staggered grid -- **the only type to keep**)

In practice, `freeform` and `goal_canvas` share the same editor/viewer. All their code will be removed. Any existing non-grid boards will be deleted on load.

---

## Phase 1: Delete exclusively non-grid files (9 files)

These files have zero grid usage and can be deleted outright:

**Screens:**

- `[lib/screens/goal_canvas_editor_screen.dart](lib/screens/goal_canvas_editor_screen.dart)`
- `[lib/screens/goal_canvas_viewer_screen.dart](lib/screens/goal_canvas_viewer_screen.dart)`

**Widgets:**

- `[lib/widgets/vision_board_builder.dart](lib/widgets/vision_board_builder.dart)`
- `[lib/widgets/manipulable_node.dart](lib/widgets/manipulable_node.dart)`
- `[lib/widgets/editor/layers_sheet.dart](lib/widgets/editor/layers_sheet.dart)`
- `[lib/widgets/editor/background_options_sheet.dart](lib/widgets/editor/background_options_sheet.dart)`
- `[lib/widgets/vision_board/component_image.dart](lib/widgets/vision_board/component_image.dart)`

**Models (canvas-only component types):**

- `[lib/models/text_component.dart](lib/models/text_component.dart)` -- only used by canvas layers
- `[lib/models/zone_component.dart](lib/models/zone_component.dart)` -- only used by canvas layers

---

## Phase 2: Update models (3 files)

### `[lib/models/vision_board_info.dart](lib/models/vision_board_info.dart)`

- Remove `layoutFreeform` and `layoutGoalCanvas` constants
- Update `fromJson` default from `layoutFreeform` to `layoutGrid`
- Update comment to say `'grid'` only

### `[lib/models/vision_components.dart](lib/models/vision_components.dart)`

- Remove `export` of `text_component.dart` and `zone_component.dart`

### `[lib/models/vision_component_factory.dart](lib/models/vision_component_factory.dart)`

- **CAREFUL**: Remove `TextComponent` and `ZoneComponent` deserialization branches, but add a safe fallback (return `null` or skip) for unknown `type` values so that any legacy stored data with `type: "text"` or `type: "zone"` does not crash on load. Callers that iterate components should filter out nulls.
- Keep `ImageComponent` branch (used by grid)

### `[lib/models/board_template.dart](lib/models/board_template.dart)`

- Remove `goal_canvas` kind references; default kind to `'grid'`

---

## Phase 3: Update screens (5 files)

### `[lib/screens/dashboard_screen.dart](lib/screens/dashboard_screen.dart)`

- Remove `GoalCanvasEditorScreen` and `GoalCanvasViewerScreen` imports
- In `_createBoard()` (line 688):
  - **KEEP** the `'create_wizard'` path (lines 706-715) -- this is the wizard flow that creates grid boards via `CreateBoardWizardScreen`
  - **KEEP or REMOVE** the `'browse_templates'` path (lines 694-703) -- `TemplateGalleryScreen` (will be updated in Phase 3 to be grid-only)
  - **REMOVE** the fallback path (lines 718-753) -- this is the `showNewBoardDialog` + `GoalCanvasEditorScreen` path that creates non-grid boards
- In `_openBoard()`: remove the `switch` default branch that routes to `GoalCanvasEditorScreen`/`GoalCanvasViewerScreen`; always route to `GridEditorScreen`
- In `_openEarnBadges()`: remove the non-grid branch that loads components via `VisionBoardComponentsStorageService`; only use the grid (tiles to ImageComponent) path
- **Add board cleanup on load**: when loading boards via `BoardsStorageService.loadBoards()`, filter out any boards where `layoutType != layoutGrid` and delete their data

### `[lib/screens/vision_board_home_widgets.dart](lib/screens/vision_board_home_widgets.dart)`

- In `VisionBoardHomeFront`: remove the `layoutType` ternary; always use `_GridBoardPreview`
- In `_VisionBoardHomeBackState._load()`: remove the non-grid branch that loads via `VisionBoardComponentsStorageService`; only load tiles
- In `_persistUpdatedComponents`: remove the non-grid branch; only persist via `GridTilesStorageService`
- Delete the entire `_LayerBoardCoverPreview` / `_LayerBoardCoverPreviewState` classes
- Remove `component_image.dart` import

### `[lib/screens/templates/template_gallery_screen.dart](lib/screens/templates/template_gallery_screen.dart)`

- Remove `GoalCanvasEditorScreen` import
- Remove the entire `if (kind == 'goal_canvas')` block in `_useTemplate`
- Filter template list to only show `kind == 'grid'` templates
- Remove `VisionBoardComponentsStorageService` usage for canvas components

### `[lib/screens/habits_list_screen.dart](lib/screens/habits_list_screen.dart)`

- **CAREFUL**: In `_addHabit()`, when `_components.isEmpty`, the code creates a `TextComponent` placeholder to attach the new habit to. Since `TextComponent` is being deleted and grid boards always have tiles (ImageComponents), change this to either:
  - Use an `ImageComponent` placeholder instead, or
  - Show a message asking the user to create a goal tile first (grid always has tiles, so this is an edge case)
- Remove the `TextComponent` import

### `[lib/screens/global_insights_screen.dart](lib/screens/global_insights_screen.dart)`

- Remove `ZoneComponent` filtering (`whereType<ZoneComponent>()`)

---

## Phase 4: Update services (6+ files)

### `[lib/services/boards_storage_service.dart](lib/services/boards_storage_service.dart)`

- Remove canvas-only keys: `boardComponentsKey`, `boardBgColorKey`, `boardImagePathKey`, `boardCanvasWidthKey`, `boardCanvasHeightKey`
- Remove their `p.remove(...)` calls from `deleteBoardData`

### `[lib/services/sync_service.dart](lib/services/sync_service.dart)`

- Bootstrap: remove `else if (componentsRaw is List)` branch; only handle grid tiles
- `_buildBoardSnapshot`: remove the else branch that serializes components; always serialize grid tiles
- `pruneLocalFeedback`: remove the else branch that prunes components; only prune tiles

### `[lib/services/habit_storage_service.dart](lib/services/habit_storage_service.dart)`

- Remove non-grid branch (components path); only use grid tile path

### `[lib/services/affirmation_service.dart](lib/services/affirmation_service.dart)`

- Remove non-grid branch; only load from grid tiles

### `[lib/services/puzzle_service.dart](lib/services/puzzle_service.dart)` and `[lib/services/puzzle_state_service.dart](lib/services/puzzle_state_service.dart)`

- Remove non-grid branches in image collection; only use grid tiles

### `[lib/services/habit_geofence_tracking_service.dart](lib/services/habit_geofence_tracking_service.dart)`

- Remove non-grid branch

### `[lib/services/vision_board_components_storage_service.dart](lib/services/vision_board_components_storage_service.dart)`

- **Evaluate after all above changes**: if no remaining caller uses it, delete entirely. If some grid code still depends on it (e.g., dashboard_body, some services), keep it but remove canvas-specific comments/logic.

---

## Phase 5: Update widgets (4 files)

### `[lib/widgets/dashboard/dashboard_body.dart](lib/widgets/dashboard/dashboard_body.dart)`

- Remove layoutType checks for non-grid boards; grid-only load/save

### `[lib/widgets/habits/habit_tracker_header.dart](lib/widgets/habits/habit_tracker_header.dart)`

- **CAREFUL**: Remove `component is ZoneComponent` check (line ~25) that provides the "Open Link" button. Set `link = null` since ZoneComponent is canvas-only. Grid boards use ImageComponent which does not have a link field. No habit data is lost -- only the link button disappears (it was never available on grid boards anyway).

### `[lib/widgets/rituals/add_habit_modal.dart](lib/widgets/rituals/add_habit_modal.dart)`

- Remove freeform comment and any non-grid branch in grid check

### `[lib/screens/journal/journal_notes_screen.dart](lib/screens/journal/journal_notes_screen.dart)`

- Remove non-grid branch that loads components

---

## Phase 6: Clean up unused files

### Check `lib/_unused/` directory

- `[lib/_unused/screens/admin/templates_admin_screen.dart](lib/_unused/screens/admin/templates_admin_screen.dart)` -- remove goal_canvas references
- `[lib/_unused/services/canva_import_service.dart](lib/_unused/services/canva_import_service.dart)` -- candidate for deletion
- `[lib/_unused/widgets/vision_board/component_constraints.dart](lib/_unused/widgets/vision_board/component_constraints.dart)` -- candidate for deletion
- `[lib/_unused/widgets/dashboard/vision_board_preview_card.dart](lib/_unused/widgets/dashboard/vision_board_preview_card.dart)` -- remove canvas references

---

## Phase 7: Verify and fix

- Run `flutter analyze` to catch missing imports, dead references, and type errors
- Fix any lint errors introduced by the removals
- Verify the app builds cleanly

---

## Habit flow safety

The grid habit flow is: `GridTileModel` (habits) <-> `ImageComponent` (synthetic, built from tiles) <-> `HabitStorageService` (flat list, source of truth). None of this depends on canvas-only files.

**Verified safe (no changes needed):**

- `HabitItem` model -- pure data, no VisionComponent references
- `HabitStorageService.syncComponentsHabits` -- uses abstract `VisionComponent` interface (id + habits), grid callers always pass `ImageComponent`
- `HabitTrackerSheet` -- only uses `VisionComponent` and `ImageComponent`, no Text/Zone
- `AllBoardsHabitsTab` -- aggregates from `HabitStorageService.loadAll()`, backward-compat sync uses abstract `VisionComponent` list (filled from tiles for grid)
- `DashboardBody` -- grid branch loads tiles -> ImageComponents; save maps back to tiles. Grid flow intact after removing non-grid branch.
- `GridGoalViewerScreen` / `GridBoardEditor` -- pure grid, no canvas references in habit handling

**3 spots needing careful changes (called out in phases above):**

1. `habits_list_screen.dart` -- `TextComponent` placeholder in `_addHabit()` when components empty -> replace with `ImageComponent` placeholder or guard
2. `habit_tracker_header.dart` -- `ZoneComponent` check for "Open Link" -> remove (grid never has zones)
3. `vision_component_factory.dart` -- Text/Zone deserialization branches -> return null for unknown types to avoid crash on legacy data

---

## Key decisions

- **Wizard flow is fully preserved** -- `CreateBoardWizardScreen`, `WizardBoardBuilderService`, `WizardStep1BoardSetup`, and `WizardStepGoalsForCoreValue` are 100% grid-only and require zero changes. The dashboard `_createBoard()` path for `'create_wizard'` is kept intact.
- **VisionComponent / ImageComponent models are KEPT** -- grid boards convert tiles to `ImageComponent` for habits/todos/insights
- **VisionBoardComponentsStorageService** -- kept or deleted depending on whether grid code still references it after cleanup; will evaluate in Phase 4
- **Existing non-grid boards** -- deleted on load in `dashboard_screen.dart` (filter + delete data)
- **Template gallery** -- only shows grid templates; goal_canvas templates from backend are filtered out

