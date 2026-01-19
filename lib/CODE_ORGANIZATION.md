# Code Organization Guide

This document describes the organization structure of the Digital Vision Board Flutter application.

## Folder Structure

### `/lib/config/`
**Purpose**: Centralized configuration files

- `app_theme.dart` - Theme configuration with colors, fonts, spacing, and Material 3 theme builders
  - Easily configurable primary, secondary, tertiary colors
  - Typography definitions
  - Spacing and border radius constants
  - Light and dark theme builders

### `/lib/screens/`
**Purpose**: Feature-based screen organization

Screens are organized by feature/domain:

- **`/board/`** - Vision board related screens
  - `vision_board_home_screen.dart`
  - `vision_board_editor_screen.dart`
  - `goal_canvas_editor_screen.dart`
  - `goal_canvas_viewer_screen.dart`
  - `grid_editor.dart`
  - `grid_board_editor.dart`
  - `grid_goal_viewer_screen.dart`
  - `physical_board_editor_screen.dart`
  - `physical_board_viewer_screen.dart`
  - `vision_board_home_widgets.dart`

- **`/habits/`** - Habit tracking screens
  - `habits_list_screen.dart`
  - `habit_timer_screen.dart`

- **`/journal/`** - Journal/notes screens
  - `journal_notes_screen.dart`

- **`/todos/`** - Todo list screens
  - `todos_list_screen.dart`

- **`/dashboard/`** - Dashboard and overview screens
  - `dashboard_screen.dart`
  - `daily_overview_screen.dart`
  - `global_insights_screen.dart`

- **`/settings/`** - Settings screen
  - `settings_screen.dart`

- **`/auth/`** - Authentication screens
  - `auth_gateway_screen.dart`
  - `login_screen.dart`
  - `phone_auth_screen.dart`
  - `signup_screen.dart`

- **`/wizard/`** - Board creation wizard screens
  - `create_board_wizard_screen.dart`
  - `wizard_step1_board_setup.dart`
  - `wizard_step_goals_for_core_value.dart`
  - `wizard_step3_generate_grid_preview.dart`
  - `wizard_step4_customize_grid.dart`

- **`/templates/`** - Template gallery
  - `template_gallery_screen.dart`

- **`/admin/`** - Admin screens
  - `templates_admin_screen.dart`

- **`/onboarding/`** - Onboarding screens
  - `onboarding_carousel_screen.dart`

### `/lib/widgets/`
**Purpose**: Feature-based widget organization

Widgets are organized by feature/domain:

- **`/board/`** - Board-related widgets
  - Grid widgets (tiles, cards, dialogs)
  - Vision board builder
  - Hotspot widgets
  - Physical board widgets
  - Goal details sheet

- **`/habits/`** - Habit tracking widgets
  - Habit tracker components
  - Habit-related dialogs

- **`/dashboard/`** - Dashboard widgets
  - Dashboard body
  - Dashboard tabs
  - Insights widgets (stat cards, progress cards, etc.)

- **`/common/`** - Shared/common widgets
  - Dialogs (confirm, text input, goal picker, etc.)
  - Editor widgets (text editor, layers, background options)
  - Manipulable widgets (resize handles, nodes)
  - Flip cards

- **`/todos/`** - Todo-related widgets
  - Todo tabs and components

- **`/archive/`** - Unused/deprecated widgets
  - Components that may be reused later or moved to another repo

### `/lib/services/`
**Purpose**: Domain-based service organization

Services are organized by domain:

- **`/board/`** - Board-related services
  - `boards_storage_service.dart`
  - `vision_board_components_storage_service.dart`
  - `grid_tiles_storage_service.dart`
  - `board_scan_service.dart` (and platform variants)
  - `wizard_board_builder.dart`
  - `wizard_defaults_service.dart`
  - `wizard_recommendations_service.dart`
  - `templates_service.dart`
  - `grid_board_editor_flows.dart`

- **`/habits/`** - Habit tracking services
  - `habit_geofence_tracking_service.dart`
  - `habit_timer_state_service.dart`
  - `habit_completion_applier.dart`
  - `habit_progress_widget_*.dart` (widget-related habit services)

- **`/journal/`** - Journal services
  - `journal_storage_service.dart`

- **`/auth/`** - Authentication services
  - `dv_auth_service.dart`

- **`/image/`** - Image processing services
  - `image_service.dart`
  - `image_persistence.dart` (and platform variants)
  - `image_region_cropper.dart` (and platform variants)
  - `stock_images_service.dart`
  - `category_images_service.dart`
  - `canva_import_service.dart`

- **`/sync/`** - Sync and backup services
  - `sync_service.dart`
  - `google_drive_backup_service.dart`

- **`/widgets/`** - Home screen widget services
  - `widget_deeplink_service.dart`
  - `habit_progress_widget_snapshot_service.dart`
  - `habit_progress_widget_action_queue_service.dart`
  - `habit_progress_widget_native_bridge.dart`

- **`/utils/`** - Utility services
  - `app_settings_service.dart`
  - `logical_date_service.dart`
  - `daily_overview_service.dart`
  - `reminder_summary_service.dart`
  - `notifications_service.dart`

### `/lib/models/`
**Purpose**: Data models

Models remain at the root level but are organized logically:
- Board-related models (vision_board_info, grid_template, etc.)
- Component models (vision_component, text_component, image_component, etc.)
- Feature models (habit_item, journal_entry, task_item, etc.)
- Wizard models (in `/wizard/` subfolder)

### `/lib/utils/`
**Purpose**: Utility functions and helpers

- `component_label_utils.dart`
- `file_image_provider.dart` (and platform variants)

### `/lib/archive/`
**Purpose**: Unused or deprecated code

Components that are not currently in use but may be:
- Reused in the future
- Moved to another repository
- Referenced for historical context

## Naming Conventions

### Files
- **Screens**: `*_screen.dart` (e.g., `dashboard_screen.dart`)
- **Widgets**: `*_widget.dart` or descriptive names (e.g., `habit_tracker_sheet.dart`)
- **Services**: `*_service.dart` (e.g., `boards_storage_service.dart`)
- **Models**: Descriptive names (e.g., `vision_board_info.dart`)

### Classes
- **Screens**: `*Screen` (e.g., `DashboardScreen`)
- **Widgets**: Descriptive names (e.g., `HabitTrackerSheet`)
- **Services**: `*Service` (e.g., `BoardsStorageService`)
- **Models**: Descriptive names (e.g., `VisionBoardInfo`)

### Variables
- Use descriptive names with appropriate prefixes:
  - Private: `_variableName`
  - Public: `variableName`
  - Constants: `CONSTANT_NAME` or `kConstantName`

## Theme Configuration

The app uses a centralized theme configuration in `/lib/config/app_theme.dart`.

### Customizing Colors
Edit the color constants at the top of `app_theme.dart`:
```dart
static const Color primaryColor = Color(0xFF6B46C1);
static const Color secondaryColor = Color(0xFF9333EA);
```

### Customizing Fonts
Edit the font family constants:
```dart
static const String primaryFontFamily = 'Roboto';
static const String secondaryFontFamily = 'Roboto';
```

### Using Theme Values
Access theme values in widgets:
```dart
Theme.of(context).colorScheme.primary
Theme.of(context).textTheme.titleLarge
AppTheme.spacingM
AppTheme.radiusM
```

## Import Guidelines

### Relative Imports
- Use relative imports for files in the same feature/domain
- Use absolute imports (from `lib/`) for cross-feature imports

### Example
```dart
// Same feature
import '../widgets/board/grid_tile_card.dart';

// Cross-feature
import '../../services/board/boards_storage_service.dart';
import '../../models/vision_board_info.dart';
```

## Adding New Features

When adding a new feature:

1. **Create screen folder**: `/lib/screens/feature_name/`
2. **Create widget folder**: `/lib/widgets/feature_name/`
3. **Create service folder**: `/lib/services/feature_name/`
4. **Add models**: In `/lib/models/` or create subfolder if needed
5. **Update this document**: Add the new feature to the appropriate sections

## Migration Notes

This structure was reorganized from a flat structure. Key changes:
- Screens grouped by feature instead of type
- Widgets grouped by feature instead of type
- Services grouped by domain instead of flat list
- Centralized theme configuration
- Archive folder for unused code
