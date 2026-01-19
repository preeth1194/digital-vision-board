# Digital Vision Board

A gamified digital vision board app built with Flutter that helps users create vision boards, set goals, and track habits and tasks.

## Features

- **Multiple Board Types**:
  - Freeform Vision Board (Canva-like editor)
  - Goal Canvas (freeform layers over optional background)
  - Physical Board (photo background + goal overlays)
  - Grid Board (structured tile layout)

- **Goal Tracking**:
  - Attach habits and tasks to goals
  - Daily/weekly habit scheduling
  - Task checklists with completion tracking
  - Progress insights and analytics

- **User Experience**:
  - Material Design 3 UI
  - Light/Dark theme support
  - Customizable colors and typography
  - Intuitive navigation and workflows

## Project Structure

The codebase is organized using a **feature-based architecture** for better maintainability and scalability.

### Key Directories

```
lib/
├── config/              # Centralized configuration (theme, constants)
├── screens/             # Feature-based screen organization
│   ├── board/          # Vision board screens
│   ├── habits/         # Habit tracking screens
│   ├── journal/        # Journal/notes screens
│   ├── todos/          # Todo list screens
│   ├── dashboard/      # Dashboard and overview screens
│   ├── settings/       # Settings screen
│   ├── auth/           # Authentication screens
│   ├── wizard/         # Board creation wizard
│   └── ...
├── widgets/             # Feature-based widget organization
│   ├── board/          # Board-related widgets
│   ├── habits/         # Habit tracking widgets
│   ├── dashboard/      # Dashboard widgets
│   ├── common/         # Shared widgets (dialogs, editor, etc.)
│   └── ...
├── services/            # Domain-based service organization
│   ├── board/          # Board-related services
│   ├── habits/         # Habit tracking services
│   ├── journal/        # Journal services
│   ├── auth/           # Authentication services
│   ├── image/          # Image processing services
│   ├── sync/           # Sync and backup services
│   └── ...
├── models/              # Data models
└── utils/               # Utility functions
```

### Documentation

- **`lib/CODE_ORGANIZATION.md`** - Detailed folder structure and organization guide
- **`lib/NAMING_CONVENTIONS.md`** - Naming conventions and best practices
- **`AI_CONTEXT.txt`** - Comprehensive context for AI assistants and onboarding

## Getting Started

### Prerequisites

- Flutter SDK (3.10.7 or higher)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- For Android builds: Android SDK
- For iOS builds: Xcode (macOS only)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/preeth1194/digital-vision-board.git
cd digital-vision-board
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Configuration

#### Theme Customization

The app uses a centralized theme configuration in `lib/config/app_theme.dart`. To customize:

1. **Colors**: Edit color constants in `app_theme.dart`:
```dart
static const Color primaryColor = Color(0xFF6B46C1);
static const Color secondaryColor = Color(0xFF9333EA);
```

2. **Fonts**: Update font family constants:
```dart
static const String primaryFontFamily = 'Roboto';
```

3. **Spacing**: Adjust spacing constants:
```dart
static const double spacingM = 16.0;
```

#### Firebase (Optional)

Firebase is optional at runtime. To enable:
1. Add `google-services.json` (Android) to `android/app/`
2. Add `GoogleService-Info.plist` (iOS) to `ios/Runner/`
3. Configure Firebase in your project

## Development Guidelines

### Code Organization

- **Screens**: Organized by feature in `lib/screens/{feature}/`
- **Widgets**: Organized by feature in `lib/widgets/{feature}/`
- **Services**: Organized by domain in `lib/services/{domain}/`
- **Models**: Located in `lib/models/`

### Naming Conventions

- **Screens**: `*_screen.dart` (e.g., `dashboard_screen.dart`)
- **Classes**: `*Screen` (e.g., `DashboardScreen`)
- **Services**: `*_service.dart` (e.g., `boards_storage_service.dart`)
- **Private members**: `_variableName` or `_methodName()`

See `lib/NAMING_CONVENTIONS.md` for complete guidelines.

### Import Patterns

- Use relative imports for files in the same feature/domain
- Use absolute imports (from `lib/`) for cross-feature imports
- Example:
```dart
// Same feature
import '../widgets/board/grid_tile_card.dart';

// Cross-feature
import '../../services/board/boards_storage_service.dart';
```

### Adding New Features

When adding a new feature:

1. Create feature folders:
   - `lib/screens/{feature_name}/`
   - `lib/widgets/{feature_name}/`
   - `lib/services/{feature_name}/` (if needed)

2. Follow naming conventions (see `lib/NAMING_CONVENTIONS.md`)

3. Update documentation:
   - Add to `lib/CODE_ORGANIZATION.md`
   - Update `AI_CONTEXT.txt` if it's a major feature

## CI/CD: Android Build + Deployment

This repo includes a GitHub Actions workflow (`.github/workflows/android_release.yml`) that runs on pushes to `master` (including PR merges) and:

- Builds **release AAB** and **release APK**
- Uploads them as workflow artifacts
- Optionally deploys:
  - **Google Play (internal track)** from the AAB
  - **Firebase App Distribution** from the APK

### Required Secrets (only if you want signed release builds)
- **ANDROID_KEYSTORE_BASE64**: base64 of your `*.jks`
- **ANDROID_KEYSTORE_PASSWORD**
- **ANDROID_KEY_ALIAS**
- **ANDROID_KEY_PASSWORD**

### Optional Secrets (enable real deployment)
- **Google Play**
  - **PLAY_SERVICE_ACCOUNT_JSON**
  - **PLAY_PACKAGE_NAME**
- **Firebase App Distribution**
  - **FIREBASE_APP_ID**
  - **FIREBASE_TOKEN**
  - (optional) **FIREBASE_TESTERS**, **FIREBASE_GROUPS**

## Architecture Overview

### Board Types

The app supports multiple board types, each with different storage mechanisms:

1. **Freeform Vision Board**: Canva-like editor
   - Storage: `VisionBoardComponentsStorageService`
   - Screen: `lib/screens/board/vision_board_editor_screen.dart`

2. **Goal Canvas**: Freeform layers over optional background
   - Storage: `VisionBoardComponentsStorageService`
   - Screens: `lib/screens/board/goal_canvas_editor_screen.dart`, `goal_canvas_viewer_screen.dart`

3. **Physical Board**: Photo background + goal overlays
   - Storage: `VisionBoardComponentsStorageService` + background image path
   - Screens: `lib/screens/board/physical_board_editor_screen.dart`, `physical_board_viewer_screen.dart`

4. **Grid Board**: Structured tile layout
   - Storage: `GridTilesStorageService`
   - Screens: `lib/screens/board/grid_editor_screen.dart`, `grid_goal_viewer_screen.dart`

### Data Models

- **VisionComponent**: Base type for nodes on freeform canvases
- **GridTileModel**: Tiles for grid boards
- **HabitItem**: Habit tracking with completion dates and streaks
- **TaskItem**: Tasks with checklists and completion feedback

### Key Services

- **BoardsStorageService**: Board list and metadata
- **VisionBoardComponentsStorageService**: Components for freeform boards
- **GridTilesStorageService**: Tiles for grid boards
- **HabitCompletionApplier**: Habit completion logic
- **ImageService**: Image processing and persistence

## Contributing

1. Follow the code organization structure
2. Adhere to naming conventions
3. Update documentation for new features
4. Write clear commit messages
5. Test your changes before submitting

## License

[Add your license information here]

## Support

For questions or issues, please open an issue on GitHub.
