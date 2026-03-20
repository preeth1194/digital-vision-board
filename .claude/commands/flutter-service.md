# Flutter Service Skill

Create or extend a Flutter service for the Digital Vision Board (`habitseeding`) app.

## Instructions

### 1. File Location

All services live in `lib/services/`. Use descriptive snake_case filenames ending in `_service.dart`.

### 2. Service Pattern

Services use **static methods** or a **singleton instance**. Choose based on existing patterns in the codebase:

**Static-method pattern** (most common):
```dart
class MyFeatureService {
  MyFeatureService._();

  static Future<void> doSomething({required SharedPreferences prefs}) async {
    // implementation
  }

  static Future<List<MyModel>> loadAll({required SharedPreferences prefs}) async {
    // implementation
  }
}
```

**Singleton pattern** (used by NotificationsService, HabitGeofenceTrackingService, etc.):
```dart
class MyFeatureService {
  MyFeatureService._internal();
  static final MyFeatureService instance = MyFeatureService._internal();

  Future<void> start() async { ... }
  Future<void> stop() async { ... }
}
```

### 3. Storage Rules

- **Persistence** → `SharedPreferences` (key prefix: use a unique, namespaced key like `my_feature_v1`)
- **Cloud sync** → Call `AutoSyncService` after mutations when data should be synced
- **Backup** → Use `BackupService` for Google Drive backup integration
- **Never** write to raw files in `lib/` or store data outside `SharedPreferences` / backend API

### 4. Error Handling

- Throw descriptive exceptions for programming errors
- Return `null` or empty collections for "not found" cases — don't throw
- Wrap Firebase calls in try/catch — Firebase failures are non-fatal
- Use `unawaited(x.catchError((_) {}))` for fire-and-forget best-effort tasks

### 5. Key Services Reference

Avoid re-implementing existing functionality:

| Capability | Use This |
|---|---|
| Auth / user ID | `DvAuthService` |
| Date "today" | `LogicalDateService` |
| Global settings | `AppSettingsService` |
| Push notifications | `NotificationsService` |
| Ads | `AdService` |
| Subscriptions / paywall | `SubscriptionService` |
| Affirmations | `AffirmationService` |
| Wizard AI defaults | `WizardDefaultsService` |
| Background sync | `AutoSyncService` |
| Google Drive backup | `BackupService` |

### 6. SharedPreferences Key Naming

Always version your keys to allow future migration:
```dart
static const String _kMyDataKey = 'my_feature_data_v1';
```

### 7. Backend API Calls

Use `http` package (already in `pubspec.yaml`). Always:
- Read `BASE_URL` from `AppSettingsService` or a config constant
- Handle non-200 responses gracefully
- Parse JSON into model classes, not raw `Map<String, dynamic>` at the call site

### 8. Testing Considerations

Write the service so it can be tested without a running device:
- Accept `SharedPreferences` as a parameter (injected, not hard-singletons) where practical
- Keep business logic in pure functions where possible

---

## Task

Create or extend the service described in `$ARGUMENTS`.

- State the exact file path
- Write complete Dart code with doc comments on public methods
- List any new `SharedPreferences` keys introduced
- Note if any backend endpoint changes are required
