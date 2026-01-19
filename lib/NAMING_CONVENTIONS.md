# Naming Conventions

This document outlines the naming conventions used throughout the Digital Vision Board codebase.

## File Naming

### Screens
- Format: `*_screen.dart`
- Examples: `dashboard_screen.dart`, `habits_list_screen.dart`, `vision_board_editor_screen.dart`

### Widgets
- Format: Descriptive names with appropriate suffix
- Examples: `habit_tracker_sheet.dart`, `goal_details_dialog.dart`, `grid_tile_card.dart`
- Common suffixes: `_sheet.dart`, `_dialog.dart`, `_card.dart`, `_widget.dart`

### Services
- Format: `*_service.dart`
- Examples: `boards_storage_service.dart`, `dv_auth_service.dart`, `image_service.dart`

### Models
- Format: Descriptive names, typically without suffix
- Examples: `vision_board_info.dart`, `habit_item.dart`, `journal_entry.dart`

### Utilities
- Format: `*_utils.dart` or descriptive names
- Examples: `component_label_utils.dart`, `file_image_provider.dart`

## Class Naming

### Screens
- Format: `*Screen` (PascalCase)
- Examples: `DashboardScreen`, `HabitsListScreen`, `VisionBoardEditorScreen`
- State classes: `_*ScreenState` (private, PascalCase with underscore prefix)

### Widgets
- Format: Descriptive PascalCase names
- Examples: `HabitTrackerSheet`, `GoalDetailsDialog`, `GridTileCard`
- State classes: `_*State` (private)

### Services
- Format: `*Service` (PascalCase)
- Examples: `BoardsStorageService`, `DvAuthService`, `ImageService`
- Singleton pattern: Use `instance` getter or static methods

### Models
- Format: Descriptive PascalCase names
- Examples: `VisionBoardInfo`, `HabitItem`, `JournalEntry`

## Variable Naming

### Private Variables
- Format: `_variableName` (lowerCamelCase with underscore prefix)
- Examples: `_loading`, `_boards`, `_activeBoardId`, `_checkedMandatoryLogin`

### Public Variables
- Format: `variableName` (lowerCamelCase)
- Examples: `boardId`, `title`, `initialIsEditing`

### Constants
- Format: `CONSTANT_NAME` (UPPER_SNAKE_CASE) or `kConstantName` (lowerCamelCase with 'k' prefix)
- Examples: `_addWidgetPromptShownKey`, `spacingUnit`, `primaryColor`

### Final Variables
- Format: `variableName` (lowerCamelCase)
- Examples: `final prefs`, `final boards`, `final activeId`

## Method Naming

### Private Methods
- Format: `_methodName` (lowerCamelCase with underscore prefix)
- Examples: `_load()`, `_reload()`, `_maybeShowAuthGatewayIfMandatoryAfterTenDays()`

### Public Methods
- Format: `methodName` (lowerCamelCase)
- Examples: `loadBoards()`, `saveBoards()`, `deleteBoard()`

### Async Methods
- Format: Same as regular methods, typically return `Future<T>`
- Examples: `Future<void> _load() async`, `Future<List<VisionBoardInfo>> loadBoards()`

### Boolean Methods
- Format: `is*`, `has*`, `should*`, or `can*` prefix
- Examples: `isGuestSession()`, `hasWindowFocus`, `shouldShowDialog()`

## Parameter Naming

- Format: `parameterName` (lowerCamelCase)
- Examples: `boardId`, `title`, `initialIsEditing`, `prefs`

### Named Parameters
- Use named parameters for optional parameters or when clarity is needed
- Examples: `{required this.boardId, this.autoImportType}`

## Import Organization

### Order
1. Dart SDK imports
2. Flutter package imports
3. Third-party package imports
4. Local imports (relative paths)
5. Local imports (absolute paths from lib/)

### Example
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../services/board/boards_storage_service.dart';
import '../../widgets/board/grid_tile_card.dart';
```

## Folder and Path Naming

### Folders
- Format: `lowercase_with_underscores` or `lowercase`
- Examples: `screens/`, `widgets/`, `services/`, `board/`, `habits/`

### Feature Folders
- Use singular form for feature names: `habit/` not `habits/`
- Exception: Use plural when it represents a collection: `habits/` for multiple habit screens

## Best Practices

1. **Be Descriptive**: Use clear, descriptive names that indicate purpose
   - Good: `_maybeShowAuthGatewayIfMandatoryAfterTenDays()`
   - Bad: `_check()`

2. **Consistency**: Follow the same pattern throughout the codebase
   - All screen state classes use `_*ScreenState`
   - All services use `*Service` suffix

3. **Private by Default**: Make variables and methods private unless they need to be public
   - Use `_` prefix for private members

4. **Avoid Abbreviations**: Use full words unless abbreviation is widely understood
   - Good: `preferences`, `authentication`
   - Acceptable: `prefs`, `auth` (if used consistently)

5. **Boolean Variables**: Use clear boolean names
   - Good: `_loading`, `_checkedMandatoryLogin`, `isGuest`
   - Bad: `flag`, `check`, `status`

6. **Collections**: Use plural names for lists/collections
   - Good: `_boards`, `_habits`, `items`
   - Bad: `_boardList`, `_habitArray`

## Examples

### Screen Class
```dart
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  List<VisionBoardInfo> _boards = [];
  String? _activeBoardId;
  
  Future<void> _load() async {
    // Implementation
  }
}
```

### Service Class
```dart
final class BoardsStorageService {
  BoardsStorageService._();
  
  static Future<List<VisionBoardInfo>> loadBoards({
    SharedPreferences? prefs,
  }) async {
    // Implementation
  }
}
```

### Widget Class
```dart
class HabitTrackerSheet extends StatelessWidget {
  final String habitId;
  final VoidCallback? onComplete;
  
  const HabitTrackerSheet({
    super.key,
    required this.habitId,
    this.onComplete,
  });
  
  @override
  Widget build(BuildContext context) {
    // Implementation
  }
}
```
