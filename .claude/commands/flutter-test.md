# Flutter Test Skill

Write Flutter unit, widget, or integration tests for the Digital Vision Board (`habitseeding`) app.

## Instructions

### 1. File Locations

| Test type | Directory | Naming convention |
|---|---|---|
| Unit tests (models, services, utils) | `test/models/`, `test/services/`, `test/data/` | `<file_under_test>_test.dart` |
| Widget tests | `test/widgets/` | `<widget_name>_test.dart` |
| Integration tests | `integration_test/` | `app_test.dart` (main entry) |

### 2. Unit Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habitseeding/models/my_model.dart';
import 'package:habitseeding/services/my_service.dart';

void main() {
  group('MyModel', () {
    test('fromJson round-trips through toJson', () {
      final original = MyModel(id: '1', name: 'Test');
      final restored = MyModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
    });

    test('copyWith only updates specified fields', () {
      final original = MyModel(id: '1', name: 'Original');
      final copy = original.copyWith(name: 'Updated');
      expect(copy.id, '1');
      expect(copy.name, 'Updated');
    });
  });

  group('MyService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('saveAll and loadAll round-trip', () async {
      final items = [MyModel(id: '1', name: 'A')];
      await MyService.saveAll(items, prefs: prefs);
      final loaded = await MyService.loadAll(prefs: prefs);
      expect(loaded.length, 1);
      expect(loaded.first.name, 'A');
    });
  });
}
```

### 3. Widget Test Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitseeding/widgets/my_widget.dart';
import 'package:habitseeding/utils/app_colors.dart';

void main() {
  group('MyWidget', () {
    testWidgets('renders title correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: MyWidget(title: 'Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyWidget(
              title: 'Tap me',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(MyWidget));
      expect(tapped, isTrue);
    });
  });
}
```

### 4. SharedPreferences Mocking

Always call this in `setUp` before any service test that uses SharedPreferences:

```dart
SharedPreferences.setMockInitialValues({});
prefs = await SharedPreferences.getInstance();
```

Pre-populate with existing data:

```dart
SharedPreferences.setMockInitialValues({
  'my_feature_v1': jsonEncode([{'id': '1', 'name': 'Existing'}]),
});
```

### 5. Firebase / External Service Tests

Firebase is non-fatal and optional — tests must NOT require a running Firebase instance. If a service calls Firebase:
- Test only the non-Firebase code paths
- Wrap Firebase calls in try/catch in the service itself (already established pattern)
- Do not mock Firebase in unit tests — skip those specific behaviours

### 6. Test Run Commands

```bash
# Run all tests
flutter test

# Run a specific file
flutter test test/models/my_model_test.dart

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Run integration tests (requires connected device/emulator)
flutter test integration_test/app_test.dart
```

### 7. Existing Test Patterns (reference these)

- `test/models/` — model serialization tests
- `test/services/` — service CRUD with mocked SharedPreferences
- `test/data/` — data layer / seed data tests
- `integration_test/app_test.dart` — end-to-end flows

### 8. What to Test

**Always test:**
- `fromJson` / `toJson` round-trip for every new model
- `copyWith` only mutates the specified field
- Service `save` + `load` round-trip with mocked SharedPreferences
- Edge cases: empty list, missing JSON key (defaults), null fields

**Widget tests — focus on:**
- Correct text/widget renders given props
- Tap callbacks fire
- Conditional rendering (e.g., shows empty state when list is empty)

---

## Task

Write tests for `$ARGUMENTS`.

- State the file path: `test/<category>/<name>_test.dart`
- Cover: serialization round-trips, copyWith, service CRUD, widget rendering
- Use `SharedPreferences.setMockInitialValues({})` for service tests
- Do not require Firebase or network — tests must pass offline
- Run `flutter test <file>` mentally and ensure no imports are missing
