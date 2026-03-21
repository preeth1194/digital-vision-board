# Accessibility (WCAG AA) + Siri/Spotlight Integration — Design Spec

**Date:** 2026-03-21
**Status:** Approved
**Scope:** iOS + Flutter (Android benefits from accessibility work; Spotlight/Siri is iOS-only)
**Min iOS deployment target:** iOS 14 (consistent with existing WidgetKit usage)

---

## 1. Overview

Two parallel workstreams shipped together:

| Workstream | Platform | Primary Benefit |
|------------|----------|----------------|
| A — Accessibility (WCAG AA) | Flutter/Dart | VoiceOver, system a11y prefs, touch targets |
| B — Siri / Spotlight | iOS Swift + Dart | Content searchable in iOS Spotlight; Siri Suggestions |

---

## 2. Workstream A — Accessibility

### 2.1 New Shared Widgets

All three widgets live in `lib/widgets/accessibility/`, exported via a `accessibility.dart` barrel file.

#### `AccessibleIcon`

Wraps `Icon()`. Requires `semanticLabel`. If `isDecorative: true`, wraps in `ExcludeSemantics` — screen readers skip it entirely. Replaces all 515+ bare `Icon()` call sites.

```dart
// Interactive — VoiceOver announces label
AccessibleIcon(
  icon: Icons.eco_outlined,
  semanticLabel: 'Eco icon',
)
// Decorative — VoiceOver skips entirely
AccessibleIcon(
  icon: Icons.chevron_right,
  isDecorative: true,
)
```

#### `AccessibleImage`

Wraps `Image.asset()` / `Image.network()`. Requires `semanticLabel`. `isDecorative: true` wraps in `ExcludeSemantics`. Replaces all 113+ bare `Image.asset()` / `Image.network()` call sites.

```dart
AccessibleImage.asset(
  'assets/images/mood_happy.png',
  semanticLabel: 'Happy mood illustration',
  isDecorative: true,
)
```

#### `MinimumTouchTarget`

Enforces the iOS HIG 44×44pt minimum tap area. Uses `ConstrainedBox(constraints: BoxConstraints(minWidth: 44, minHeight: 44))` — this intentionally expands the widget's layout footprint to meet the minimum. For widgets that must not change visual layout (e.g., a small icon in a dense row), wrap in a `SizedBox` sized to 44×44 with `Align(alignment: Alignment.center)` so the visual icon stays centered but the tap area meets minimum.

```dart
MinimumTouchTarget(
  child: IconButton(icon: AccessibleIcon(...), onPressed: ...),
)
```

### 2.2 `AppAccessibility` Inherited Widget

File: `lib/utils/app_accessibility.dart`

Inserted as the `builder:` parameter of `MaterialApp` in `lib/main.dart`. The existing `MaterialApp` has no `builder:` — add it:

```dart
MaterialApp(
  navigatorKey: navigatorKey,
  // ... existing params ...
  builder: (context, child) => AppAccessibility(child: child!),
)
```

This ensures `AppAccessibility` is available to all descendants, including Navigator-pushed routes.

Exposes typed booleans read from `MediaQuery`:

```dart
class AppAccessibility extends InheritedWidget {
  final bool reduceMotion;   // MediaQuery.disableAnimations
  final bool highContrast;   // MediaQuery.highContrast
  final bool boldText;       // MediaQuery.boldText
  final bool invertColors;   // MediaQuery.invertColors

  static AppAccessibility of(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<AppAccessibility>()!;
}
```

**Usage pattern:**

```dart
final a11y = AppAccessibility.of(context);

AnimatedContainer(
  duration: a11y.reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
)
border: Border.all(
  color: a11y.highContrast ? colorScheme.onSurface : colorScheme.outlineVariant,
  width: a11y.highContrast ? 2 : 1,
)
```

Key screens to update: dashboard, habit tracker, mood log, journal, onboarding steps, vision board, all animated widgets.

### 2.3 `MergeSemantics` on Compound Widgets

Applied to list row widgets so VoiceOver reads the entire row as one announcement:

| Widget | Location |
|--------|----------|
| Habit list row | `lib/widgets/habits/` |
| Journal entry row | `lib/screens/journal/` |
| Mood log item | mood screens |
| Goal card | goal widgets |
| Affirmation card | `lib/widgets/affirmation_card.dart` |

### 2.4 Tooltips on Icon-Only Buttons

Every `IconButton` that has no visible text label gets a `tooltip:` string. Enables VoiceOver hint announcements and long-press tooltips.

### 2.5 Focus Order

`FocusTraversalGroup` + `OrderedTraversalPolicy` applied to:
- Onboarding step screens (logical top-to-bottom order)
- Dashboard tab content (tab bar → content → FAB)
- Wizard/form screens (field order matches visual layout)

### 2.6 Migration Strategy

1. Create the three wrapper widgets and barrel export
2. Add `AppAccessibility` via `MaterialApp.builder` in `main.dart`
3. Migrate `Icon()` → `AccessibleIcon` screen-by-screen
4. Migrate `Image.asset()` / `Image.network()` → `AccessibleImage`
5. Wrap `MergeSemantics` around compound list rows
6. Add `tooltip:` to `IconButton` instances
7. Add `MinimumTouchTarget` where visual size is below 44×44pt
8. Apply `AppAccessibility.of(context)` flags in animation and styling code

---

## 3. Workstream B — Siri / Spotlight

### 3.1 Architecture Overview

```
Dart (Flutter)                       Swift (iOS)
────────────────────────────────     ──────────────────────────────────────────
SpotlightService                     SpotlightPlugin
  .indexHabit(...)           ──►     CSSearchableIndex.default().indexSearchableItems(...)
  .indexJournal(...)
  .indexGoal(...)
  .indexAffirmation(...)
  .indexVisionBoard(...)
  .removeItem(id)            ──►     CSSearchableIndex.default().deleteSearchableItems(...)
  .reindexAll(items)         ──►     deleteAll → indexSearchableItems(all items)
  .donateActivity(...)       ──►     NSUserActivity.becomeCurrent()

AppDelegate.swift                    Routes Spotlight taps + Siri activity continuations
  CSSearchableItemActionType  ──►    Extract dvb:// URL → WidgetDeepLinkService
  NSUserActivity continuation ──►    Extract dvb:// from userInfo → WidgetDeepLinkService
```

Method channel name: `com.habitseeding.spotlight`

### 3.2 `SpotlightService` (Dart)

File: `lib/services/spotlight_service.dart`

Platform guard: use `defaultTargetPlatform == TargetPlatform.iOS` (safe on web, consistent with `HabitProgressWidgetNativeBridge`). All methods return silently on non-iOS platforms.

```dart
final class SpotlightService {
  SpotlightService._();
  static const _channel = MethodChannel('com.habitseeding.spotlight');

  static Future<void> indexHabit({
    required String id,
    required String name,
    required String description,
    String? category,
  }) => _invoke('indexItem', {
    'type': 'habit', 'id': id, 'title': name,
    'description': description, 'keywords': ['habit', 'streak', category ?? ''],
    'domainIdentifier': 'habits',
  });

  static Future<void> indexJournal({
    required String id,
    required String title,
    required String snippet, // first 120 chars of body
    required String dateIso,
  }) => _invoke('indexItem', {
    'type': 'journal', 'id': id, 'title': title,
    'description': snippet, 'keywords': ['journal', 'entry', dateIso],
    'domainIdentifier': 'journals',
  });

  static Future<void> indexGoal({required String id, required String name, required String description}) =>
    _invoke('indexItem', {'type': 'goal', 'id': id, 'title': name, 'description': description, 'keywords': ['goal', 'progress'], 'domainIdentifier': 'goals'});

  static Future<void> indexAffirmation({required String id, required String text}) =>
    _invoke('indexItem', {'type': 'affirmation', 'id': id, 'title': text, 'description': '', 'keywords': ['affirmation', 'mindset'], 'domainIdentifier': 'affirmations'});

  static Future<void> indexVisionBoard({required String id, required String name}) =>
    _invoke('indexItem', {'type': 'visionboard', 'id': id, 'title': name, 'description': '', 'keywords': ['vision', 'board', 'goal'], 'domainIdentifier': 'visionboards'});

  static Future<void> removeItem(String id) =>
    _invoke('removeItem', {'id': id});

  /// Full reindex. Dart collects all items and sends as a list of the same
  /// Map structure used by indexItem. Swift deletes all then re-indexes.
  /// items: List<Map<String, dynamic>> — each map matches indexItem payload above.
  static Future<void> reindexAll(List<Map<String, dynamic>> items) =>
    _invoke('reindexAll', {'items': items});

  /// Donates an NSUserActivity. deepLink must be a dvb:// URL string.
  static Future<void> donateActivity({
    required String activityType, // e.g. 'com.habitseeding.view-habit'
    required String title,
    required String deepLink,     // e.g. 'dvb://habit/abc123'
  }) => _invoke('donateActivity', {
    'activityType': activityType, 'title': title, 'deepLink': deepLink,
  });

  static Future<void> _invoke(String method, Map<String, dynamic> args) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod(method, args);
    } catch (_) { /* non-fatal */ }
  }
}
```

### 3.3 `SpotlightPlugin` (Swift)

File: `ios/Runner/SpotlightPlugin.swift`

Registered in `AppDelegate.swift` inside `didInitializeImplicitFlutterEngine` (matching the existing `_registerHabitProgressChannel` pattern), using `engineBridge.applicationRegistrar.messenger()`:

```swift
// In AppDelegate.swift — didInitializeImplicitFlutterEngine:
SpotlightPlugin.register(with: engineBridge.applicationRegistrar.messenger())
```

`CSSearchableItemAttributeSet` uses `itemContentType: UTType.text.identifier` (iOS 14+ UTType API, consistent with min deployment target).

`domainIdentifier` is set on each `CSSearchableItem` enabling efficient bulk deletion via `deleteSearchableItems(withDomainIdentifiers:)` during `reindexAll`.

Method dispatch:

| Method | Swift Action |
|--------|-------------|
| `indexItem` | Build `CSSearchableItemAttributeSet(contentType: .text)`, set `title`, `contentDescription`, `keywords`. `uniqueIdentifier` = `dvb://{type}/{id}`. Call `CSSearchableIndex.default().indexSearchableItems([item])` |
| `removeItem` | `CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["dvb://..."])` |
| `reindexAll` | `CSSearchableIndex.default().deleteAll { _ in /* then index all items */ }` |
| `donateActivity` | Create `NSUserActivity(activityType:)`, set `title`, `userInfo: ["deepLink": deepLink]`, `isEligibleForSearch = true`, `isEligibleForPrediction = true`, call `becomeCurrent()` |

### 3.4 `NSUserActivity` Donations

Activity types declared in `ios/Runner/Info.plist`:

```xml
<key>NSUserActivityTypes</key>
<array>
  <string>com.habitseeding.view-habit</string>
  <string>com.habitseeding.view-journal</string>
  <string>com.habitseeding.view-goal</string>
  <string>com.habitseeding.view-affirmation</string>
  <string>com.habitseeding.view-visionboard</string>
</array>
```

`SpotlightService.donateActivity()` is called from `didChangeDependencies` (not `initState`) on each detail screen. `didChangeDependencies` is the consistent lifecycle hook across all screens.

### 3.5 Spotlight Tap + Siri Continuation Routing

Tapping a Spotlight result delivers `NSUserActivity` of type `CSSearchableItemActionType` to `AppDelegate`. The `dvb://` identifier is in `userInfo[CSSearchableItemActivityIdentifier]`. Tapping a Siri Suggestion delivers the activity type registered in Info.plist with `userInfo["deepLink"]`.

Both are handled in `AppDelegate.swift`:

```swift
override func application(
  _ application: UIApplication,
  continue userActivity: NSUserActivity,
  restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
) -> Bool {
  var deepLink: String? = nil

  if userActivity.activityType == CSSearchableItemActionType {
    // Spotlight tap — identifier is the dvb:// URL
    deepLink = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
  } else if let dl = userActivity.userInfo?["deepLink"] as? String {
    // Siri Suggestion tap
    deepLink = dl
  }

  if let deepLink, let url = URL(string: deepLink) {
    // Route through app_links — same path as widget deep links
    AppLinks.shared.handleAppLink(url: url)
  }
  return true
}
```

This routes through `app_links` (already used by `WidgetDeepLinkService`), so the existing `start()` listener picks it up automatically.

### 3.6 `WidgetDeepLinkService` Extension

The existing `handle()` function returns early if `uri.host != 'widget'`. Extend with new host patterns. Navigation uses `DigitalVisionBoardApp.navigatorKey` (already a `GlobalKey<NavigatorState>` in `main.dart`):

| URL | host | pathSegments[0] | Navigates To |
|-----|------|-----------------|-------------|
| `dvb://habit/{id}` | `habit` | id | Habit detail screen |
| `dvb://journal/{id}` | `journal` | id | Journal entry screen |
| `dvb://goal/{id}` | `goal` | id | Goal detail screen |
| `dvb://affirmation/{id}` | `affirmation` | id | Affirmation screen |
| `dvb://visionboard/{id}` | `visionboard` | id | Vision board screen |

Each handler loads the item from `SharedPreferences` by ID before pushing the screen. If the item is not found (deleted), the handler navigates to the relevant tab root instead of showing an error.

### 3.7 Journal Content Scope

The app has `JournalBookStorageService` (books) and `JournalStorageService` (entries). **Both are indexed:**
- `indexJournal` covers individual entries (`dvb://journal/{entryId}`)
- `indexVisionBoard` is reused conceptually — journal books are NOT separately indexed as a distinct type to keep the Spotlight result set manageable. Books are discoverable by finding their entries.

### 3.8 Index Lifecycle

| Event | Action |
|-------|--------|
| Create item | `SpotlightService.index*()` called from the relevant service after save |
| Update item | `SpotlightService.index*()` — overwrites by same `uniqueIdentifier` |
| Delete item | `SpotlightService.removeItem(id)` called from service before/after delete |
| App launch | `unawaited(SpotlightService.reindexAll(allItems).catchError((_) {}))` in `main()` — `allItems` assembled by reading all content from SharedPreferences |
| View detail screen | `SpotlightService.donateActivity(...)` in `didChangeDependencies` |

---

## 4. Files Changed / Created

### New Files

| File | Purpose |
|------|---------|
| `lib/widgets/accessibility/accessible_icon.dart` | `AccessibleIcon` widget |
| `lib/widgets/accessibility/accessible_image.dart` | `AccessibleImage` widget |
| `lib/widgets/accessibility/minimum_touch_target.dart` | `MinimumTouchTarget` widget |
| `lib/widgets/accessibility/accessibility.dart` | Barrel export |
| `lib/utils/app_accessibility.dart` | `AppAccessibility` InheritedWidget |
| `lib/services/spotlight_service.dart` | Dart method channel client |
| `ios/Runner/SpotlightPlugin.swift` | Swift CoreSpotlight + NSUserActivity |

### Modified Files

| File | Change |
|------|--------|
| `ios/Runner/AppDelegate.swift` | Register `SpotlightPlugin`; add `application(_:continue:restorationHandler:)` handler |
| `ios/Runner/Info.plist` | Add `NSUserActivityTypes` |
| `lib/main.dart` | Add `AppAccessibility` via `MaterialApp.builder`; call `SpotlightService.reindexAll()` at launch |
| `lib/services/widget_deeplink_service.dart` | Extend `handle()` to route new `dvb://` host patterns |
| All screens/widgets with `Icon()` | Migrate to `AccessibleIcon` |
| All screens/widgets with `Image.asset()` | Migrate to `AccessibleImage` |
| Compound list row widgets | Wrap in `MergeSemantics` |
| `IconButton` instances | Add `tooltip:` |
| Key detail screens | Call `SpotlightService.donateActivity()` in `didChangeDependencies` |
| Services (HabitService, JournalService, GoalService, etc.) | Call `SpotlightService.index*()` / `removeItem()` on save/delete |

---

## 5. Verification Checklist

### Accessibility
- [ ] VoiceOver reads every interactive element with a meaningful label
- [ ] Decorative icons/images are silent to VoiceOver
- [ ] All compound rows read as a single VoiceOver announcement
- [ ] `reduceMotion: true` → all animations use `Duration.zero`
- [ ] `highContrast: true` → borders and text use stronger contrast
- [ ] `boldText: true` → text renders with system bold
- [ ] All touch targets ≥ 44×44pt (verified with Xcode Accessibility Inspector)
- [ ] All icon-only buttons show tooltip on long press
- [ ] Tab/keyboard focus order is logical top-to-bottom on all screens

### Siri / Spotlight
- [ ] Creating a habit → appears in iOS Spotlight search within seconds
- [ ] Updating a habit name → Spotlight result title updates
- [ ] Deleting a habit → Spotlight result removed
- [ ] Tapping Spotlight result for a habit → app opens directly to that habit detail
- [ ] Tapping Spotlight result for a journal entry → opens that entry
- [ ] Same for goals, affirmations, vision boards
- [ ] Viewing habit detail repeatedly → Siri suggests it in Siri Suggestions
- [ ] App re-launch → `reindexAll` refreshes Spotlight without duplicates
- [ ] On Android → all `SpotlightService` methods return silently (no crash)
- [ ] Siri Suggestion tap → navigates to correct screen (not just home screen)
- [ ] Missing item deep link (item deleted) → navigates to tab root gracefully
