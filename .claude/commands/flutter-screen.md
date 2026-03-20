# Flutter Screen Skill

Create a new Flutter screen for the Digital Vision Board (`habitseeding`) app following all architecture and design conventions.

## Instructions

### 1. File Location

All screens live under `lib/screens/`. Place the file in the relevant sub-directory:

| Feature | Path |
|---|---|
| Auth | `lib/screens/auth/` |
| Onboarding | `lib/screens/onboarding/` |
| Dashboard | `lib/screens/dashboard_screen.dart` |
| Wizard | `lib/screens/wizard/` |
| Journal | `lib/screens/journal/` |
| Presets (skincare/meals/workout) | `lib/screens/presets/` |
| Templates | `lib/screens/templates/` |
| New feature | `lib/screens/<feature_name>/` |

### 2. Screen Scaffold Pattern

```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final colorScheme = Theme.of(context).colorScheme;

  return Scaffold(
    backgroundColor: colorScheme.surface,
    appBar: AppBar(
      title: Text('Screen Title', style: AppTypography.heading2(context)),
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    body: Container(
      decoration: AppColors.skyDecoration(isDark: isDark),
      child: SafeArea(
        child: /* screen content */,
      ),
    ),
  );
}
```

### 3. Orientation

The app is **portrait-only**. Do not add any landscape-specific logic or layouts.

### 4. State Management

- Use `StatefulWidget` + `setState` for local screen state
- Use `SharedPreferences` (via services) for persistence
- **No Riverpod, Bloc, or GetX** — Provider only if already present in the file

### 5. Navigation

Use `Navigator.of(context).push(MaterialPageRoute(...))` — no named routes unless already established in `main.dart`.

### 6. Service Access Pattern

Call service static methods or singletons, never instantiate services directly in the widget:
```dart
// Good
final prefs = await SharedPreferences.getInstance();
await AppSettingsService.load(prefs: prefs);

// Also fine (singleton)
final result = await DvAuthService.signInWithGoogle();
```

### 7. Colour Rules (MANDATORY)

| Context | Token |
|---|---|
| Scaffold background | `colorScheme.surface` |
| Page gradient/decoration | `AppColors.skyDecoration(isDark: isDark)` |
| Content cards | `AppColors.cloudDecoration(isDark: isDark)` |
| Primary actions | `colorScheme.primary` |
| Amber reward text | `AppColors.honeyText` (NEVER `AppColors.seedGold`) |
| Mood/affirmations | `AppColors.lavenderDew` |
| Error states | `colorScheme.error` |

### 8. Spacing & Typography

- All padding/margin/gaps → `AppSpacing.*` constants
- All text styles → `AppTypography.*` or `Theme.of(context).textTheme.*`
- Never hardcode pixel values or hex colours

### 9. Non-fatal Async Calls

Wrap any optional/best-effort async work with `unawaited()` and `.catchError((_) {})`:
```dart
unawaited(SomeService.refresh().catchError((_) {}));
```

---

## Task

Create the screen described in `$ARGUMENTS`.

- State the exact file path
- Write complete, working Dart code
- Follow all conventions above
- If the screen needs a new service method, note it but don't implement the service (focus on the screen)
