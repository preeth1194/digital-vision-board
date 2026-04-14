# iOS Native Skill

Add native Swift code to the Digital Vision Board (`habitseeding`) iOS app via Flutter method channels or a new WidgetKit/extension target.

## Instructions

### 1. When to Use This Skill

Use this skill when a feature requires iOS system APIs that Flutter cannot reach via existing plugins:
- **WidgetKit** home/lock screen widgets (already used — see `HabitProgressWidget`)
- **Live Activities** (Dynamic Island / Lock Screen)
- **Siri Shortcuts / App Intents** (iOS 16+)
- **Background App Refresh** (native scheduling)
- **CallKit, HealthKit, CoreMotion** — when no Flutter plugin covers the need

For everything else, check pub.dev first — most capabilities have mature Flutter plugins.

### 2. Existing Infrastructure (reuse these)

| Resource | Location | Purpose |
|---|---|---|
| Method channel | `dvb/habit_progress_widget` | Flutter ↔ iOS native bridge (already registered) |
| App group | `group.habitseeding` | Shared data between app and extensions |
| UserDefaults suite | `UserDefaults(suiteName: "group.habitseeding")` | Cross-boundary key-value storage |
| Widget bundle | `ios/HabitProgressWidget/HabitProgressWidgetBundle.swift` | Entry point for the existing WidgetKit target |
| Widget logic | `ios/HabitProgressWidget/HabitProgressWidget.swift` | Timeline provider, widget views |
| AppDelegate | `ios/Runner/AppDelegate.swift` | Method channel registration + handler setup |

### 3. Adding a New Method Channel Call

**Flutter side** (`lib/services/my_ios_service.dart`):

```dart
import 'package:flutter/services.dart';

class MyIosService {
  static const _channel = MethodChannel('dvb/my_feature');

  static Future<String?> getSomeNativeValue() async {
    try {
      return await _channel.invokeMethod<String>('getSomeNativeValue');
    } on PlatformException catch (e) {
      // Non-fatal — iOS feature unavailable or denied
      debugPrint('MyIosService: ${e.message}');
      return null;
    }
  }
}
```

**Swift side** (`ios/Runner/AppDelegate.swift`) — add inside `application(_:didFinishLaunchingWithOptions:)` after existing channel setup:

```swift
let myFeatureChannel = FlutterMethodChannel(
    name: "dvb/my_feature",
    binaryMessenger: controller.binaryMessenger
)
myFeatureChannel.setMethodCallHandler { call, result in
    switch call.method {
    case "getSomeNativeValue":
        result("Hello from Swift")
    default:
        result(FlutterMethodNotImplemented)
    }
}
```

### 4. Sharing Data via App Group (UserDefaults)

Used to pass data between the Flutter app and an iOS extension (widget, Live Activity, etc.):

```swift
// Write from AppDelegate (app side)
let sharedDefaults = UserDefaults(suiteName: "group.habitseeding")
sharedDefaults?.set(jsonString, forKey: "habit_snapshot")
sharedDefaults?.synchronize()

// Read from extension (widget side)
let sharedDefaults = UserDefaults(suiteName: "group.habitseeding")
let jsonString = sharedDefaults?.string(forKey: "habit_snapshot") ?? ""
```

The Flutter side writes data via method channel → AppDelegate picks it up → writes to shared UserDefaults → extension reads it.

### 5. Adding a New WidgetKit Extension Target

1. In Xcode: File → New → Target → Widget Extension
2. Name it (e.g., `MyNewWidget`)
3. Add to the `group.habitseeding` App Group entitlement
4. Follow the structure of `ios/HabitProgressWidget/`:
   - `MyNewWidgetBundle.swift` — `@main` entry, lists widget types
   - `MyNewWidget.swift` — `TimelineProvider`, `Entry`, `EntryView`, `Widget` conformances
5. Add the target to `ios/Podfile` if it needs CocoaPods dependencies

### 6. Refreshing a Widget from Flutter

After updating shared UserDefaults, trigger a widget timeline reload:

```swift
// In AppDelegate method channel handler
WidgetCenter.shared.reloadTimelines(ofKind: "HabitProgressWidget")
// or reload all:
WidgetCenter.shared.reloadAllTimelines()
```

### 7. Entitlements

The App Groups entitlement is already configured in `ios/Runner/Runner.entitlements`. If adding a new extension target, create `ios/MyNewWidget/MyNewWidget.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.habitseeding</string>
    </array>
</dict>
</plist>
```

### 8. Platform Guard in Flutter

Always guard native calls so the app works on Android/Web:

```dart
import 'dart:io';

if (Platform.isIOS) {
  await MyIosService.getSomeNativeValue();
}
```

Or use `defaultTargetPlatform` in widgets:

```dart
import 'package:flutter/foundation.dart';

if (defaultTargetPlatform == TargetPlatform.iOS) { ... }
```

### 9. Key Files Reference

- `ios/Runner/AppDelegate.swift` — all method channel handlers live here
- `ios/Runner/Runner.entitlements` — App Groups + capabilities
- `ios/Runner/Info.plist` — usage descriptions, URL schemes
- `ios/HabitProgressWidget/` — full working WidgetKit example to follow
- `ios/Podfile` — CocoaPods dependency management

---

## Task

Implement the iOS native feature described in `$ARGUMENTS`.

- State whether this requires a method channel, new extension target, or both
- Provide both the Flutter/Dart side and the Swift side
- Show how data is passed via App Group UserDefaults if applicable
- Wrap all native calls with `Platform.isIOS` guards in Flutter
- Reference the existing `dvb/habit_progress_widget` channel and `HabitProgressWidget` as the established pattern
