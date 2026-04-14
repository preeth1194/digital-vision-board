# Flutter Model Skill

Create a new Dart data model class for the Digital Vision Board (`habitseeding`) app.

## Instructions

### 1. File Location

All models live in `lib/models/`. Use descriptive snake_case filenames ending in `.dart`:
```
lib/models/my_feature.dart          # Single model
lib/models/my_feature_item.dart     # Item within a collection
lib/models/my_feature_book.dart     # Collection/container model
```

### 2. Required Structure

Every model must include:

```dart
class MyModel {
  final String id;
  final String name;
  // ... other fields

  const MyModel({
    required this.id,
    required this.name,
  });

  /// Deserialize from JSON (SharedPreferences or API).
  factory MyModel.fromJson(Map<String, dynamic> json) {
    return MyModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
    );
  }

  /// Serialize to JSON for persistence.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  /// Return a copy with selectively updated fields.
  MyModel copyWith({
    String? id,
    String? name,
  }) {
    return MyModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
```

### 3. ID Generation

Use `DateTime.now().millisecondsSinceEpoch.toString()` for simple IDs, or import `dart:math` for a random suffix:

```dart
static String _generateId() =>
    '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
```

### 4. Nullable `copyWith` Sentinel Pattern

When a field is nullable and must be explicitly clearable, use a sentinel:

```dart
// Sentinel — allows explicit null pass-through in copyWith
static const _unset = Object();

MyModel copyWith({
  Object? completedOn = _unset,
}) {
  return MyModel(
    completedOn: completedOn == _unset
        ? this.completedOn
        : completedOn as DateTime?,
  );
}
```

This pattern is already used in `lib/models/task_and_checklist_models.dart` — follow it for any nullable date/value fields.

### 5. SharedPreferences Persistence Pattern

Models stored in SharedPreferences are JSON-encoded as a list or map:

```dart
// Save list
final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
await prefs.setString('my_feature_v1', encoded);

// Load list
final raw = prefs.getString('my_feature_v1');
if (raw == null) return [];
final decoded = jsonDecode(raw) as List<dynamic>;
return decoded.map((e) => MyModel.fromJson(e as Map<String, dynamic>)).toList();
```

Always version your SharedPreferences key (`_v1`, `_v2`, etc.) to allow future migration.

### 6. Immutability

- All fields must be `final`
- Use `const` constructor where all fields allow it
- Do NOT use mutable state in models — put mutation logic in services

### 7. Imports

```dart
import 'dart:convert';
// Only if needed:
import 'dart:math';
```

No Flutter imports needed for pure data models.

### 8. Doc Comments

Add a brief class-level doc comment:

```dart
/// Represents a single [MyFeature] record stored per user.
class MyModel { ... }
```

---

## Task

Create the data model described in `$ARGUMENTS`.

- State the file path: `lib/models/<name>.dart`
- Write complete Dart code with `fromJson`, `toJson`, `copyWith`
- Apply sentinel pattern for any nullable fields that need explicit clearing
- List any SharedPreferences key names introduced (e.g., `my_feature_v1`)
- Note the corresponding service file that will persist this model (do not implement the service unless asked)
