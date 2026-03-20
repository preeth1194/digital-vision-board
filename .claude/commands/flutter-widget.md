# Flutter Widget Skill

Create a new Flutter widget following the **Morning Garden** design system for the `habitseeding` app.

## Instructions

You are building a Flutter widget for the Digital Vision Board app. Follow every rule below without exception.

### 1. File Location

Place widgets in the correct category under `lib/widgets/`:
- Dashboard summaries → `lib/widgets/dashboard/`
- Habit-related → `lib/widgets/habits/`
- Vision board → `lib/widgets/vision_board/`
- Navigation → `lib/widgets/navigation/`
- Dialogs → `lib/widgets/dialogs/`
- Ads → `lib/widgets/ads/`
- General/reusable → `lib/widgets/` (root)

### 2. Dart Code Rules

- Use `StatelessWidget` unless local mutable state is explicitly required
- If local state is needed, use `StatefulWidget` — never use Riverpod or Bloc
- Accept theme via `Theme.of(context).colorScheme` — never hardcode colours
- Use `const` constructors wherever possible
- Accept `Key? key` in constructor via `super.key`

### 3. Colour Rules (MANDATORY — violations break brand)

| Need | Token to use |
|---|---|
| Page / screen background | `AppColors.skyDecoration(isDark: isDark)` |
| Content card surface | `AppColors.cloudDecoration(isDark: isDark)` |
| Scaffold background colour | `colorScheme.surface` |
| Primary button / FAB | `colorScheme.primary` |
| Bottom nav background | `AppColors.forestDeep` |
| Active nav icon | `AppColors.sproutGreen` |
| Coin / badge icon fill | `AppColors.seedGold` |
| Amber / reward **text** | `AppColors.honeyText` — NEVER `AppColors.seedGold` for text |
| Mood / journal / affirmation | `AppColors.lavenderDew` |
| Chips / selected rows | `AppColors.sageContainer` (background) |
| Error states | `colorScheme.error` |

**Do NOT use raw hex strings.** Always import and use `AppColors` tokens.

### 4. Spacing Rules

Import `AppSpacing` and use its constants. Never hardcode pixel values.

```dart
import '../utils/app_spacing.dart'; // adjust relative path

// Spacing scale
AppSpacing.xs    // 4.0
AppSpacing.sm    // 8.0
AppSpacing.md    // 16.0
AppSpacing.lg    // 24.0
AppSpacing.xl    // 32.0
AppSpacing.xxl   // 48.0

// Border radii
AppSpacing.radiusBadge   // 6.0
AppSpacing.radiusChip    // 8.0
AppSpacing.radiusInput   // 12.0
AppSpacing.radiusDialog  // 20.0
AppSpacing.radiusCard    // 24.0
```

### 5. Typography Rules

Use `Theme.of(context).textTheme.*` for standard styles. Use `AppTypography.*` helpers for semantic names:

```dart
AppTypography.heading1(context)   // 24sp bold — screen titles
AppTypography.heading2(context)   // 20sp semi-bold — section titles
AppTypography.heading3(context)   // 18sp semi-bold — card titles
AppTypography.body(context)       // 16sp — main content
AppTypography.bodySmall(context)  // 14sp — secondary content
AppTypography.caption(context)    // 12sp — hints, metadata
AppTypography.secondary(context)  // 14sp onSurfaceVariant
AppTypography.button(context)     // 16sp medium — button labels
```

Do NOT create standalone `TextStyle` objects with explicit font families.

### 6. Dark Mode

Always detect dark mode with:
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
```
Then pass `isDark` to `AppColors.skyDecoration` / `AppColors.cloudDecoration`.

### 7. Card Pattern

```dart
Container(
  decoration: AppColors.cloudDecoration(isDark: isDark),
  padding: const EdgeInsets.all(AppSpacing.md),
  child: ...,
)
```

### 8. Imports Template

```dart
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
```

---

## Task

Create the widget described in `$ARGUMENTS`.

- State the file path first
- Write complete, production-ready Dart code
- Add a brief doc comment on the class explaining its purpose
- Verify all colour, spacing, and typography rules before finalising
