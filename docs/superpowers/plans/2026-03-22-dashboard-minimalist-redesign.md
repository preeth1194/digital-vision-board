# Dashboard Minimalist Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the dashboard layout to a cleaner, minimalistic arrangement: Mood as full-width lavender banner, Insights + Water in a fixed-height side-by-side row, Rewards as a slim horizontal strip, and Puzzle full-width at the bottom.

**Architecture:** Five widgets are modified independently, then `dashboard_tab.dart` is updated last to wire the new layout. Each widget change is self-contained — test each widget file then integrate. No new files are created.

**Tech Stack:** Flutter/Dart, Material 3, `GlassCard`, `AppColors`/`AppSpacing`/`AppTypography` design tokens, `MoodStorageService`, `AdService`, `SubscriptionService`.

**Spec:** `docs/superpowers/specs/2026-03-22-dashboard-minimalist-redesign.md`

---

## File Map

| File | Change |
|---|---|
| `lib/widgets/dashboard/mood_tracker_card.dart` | Full rewrite — lavender banner, horizontal row layout, 3 states |
| `lib/widgets/dashboard/insights_summary_card.dart` | New centered-column layout |
| `lib/widgets/dashboard/water_intake_card.dart` | Single line: button height 52 → 36 |
| `lib/widgets/dashboard/reward_ads_coin_card.dart` | Full rewrite — slim horizontal row, 3 button states |
| `lib/widgets/dashboard/dashboard_tab.dart` | Reorder children, replace `IntrinsicHeight` rows with fixed `SizedBox(height: 160)` |
| `test/widgets/dashboard/mood_tracker_card_test.dart` | New widget tests |
| `test/widgets/dashboard/reward_ads_coin_card_test.dart` | New widget tests |

---

## Task 1: `WaterIntakeCard` — button height 52 → 36

**Files:**
- Modify: `lib/widgets/dashboard/water_intake_card.dart:417`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/dashboard/water_intake_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_vision_board/widgets/dashboard/water_intake_card.dart';

void main() {
  testWidgets('control buttons are 36px tall', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WaterIntakeCard())),
    );
    await tester.pump();

    // Find SizedBox with height 36 inside the card (there should be two: + and -)
    final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    final buttonBoxes = sizedBoxes.where((b) => b.height == 36.0).toList();
    expect(buttonBoxes.length, greaterThanOrEqualTo(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/preeth/digital-vision-board
flutter test test/widgets/dashboard/water_intake_card_test.dart -v
```

Expected: FAIL (finds 0 SizedBoxes with height 36)

- [ ] **Step 3: Change button height from 52 to 36**

In `lib/widgets/dashboard/water_intake_card.dart` around line 417, change:
```dart
child: SizedBox(
  height: 52,
```
to:
```dart
child: SizedBox(
  height: 36,
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/widgets/dashboard/water_intake_card_test.dart -v
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/dashboard/water_intake_card.dart test/widgets/dashboard/water_intake_card_test.dart
git commit -m "feat: shrink WaterIntakeCard control buttons from 52 to 36px"
```

---

## Task 2: `MoodTrackerCard` — lavender banner redesign

**Files:**
- Modify: `lib/widgets/dashboard/mood_tracker_card.dart`
- Test: `test/widgets/dashboard/mood_tracker_card_test.dart`

**Context:** `assetForMood(int)` and `labelForMood(int)` are free functions defined in `lib/screens/mood_detail_screen.dart`. Import them. `MoodStorageService.getMoodsForRange` returns `List<MoodEntry>` with `.dateKey` (String `"YYYY-MM-DD"`) and `.value` (int 1–5). The current widget uses `GlassCard` — the new design uses a plain `Container` with `AppColors.lavenderContainer` background (no `GlassCard`). The card is tappable — wrap in `Material` + `InkWell`.

- [ ] **Step 1: Write the failing tests**

Create `test/widgets/dashboard/mood_tracker_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_vision_board/widgets/dashboard/mood_tracker_card.dart';

void main() {
  testWidgets('loading state: pill is hidden, no Log or Edit text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodTrackerCard())),
    );
    // Don't pump async — widget is in loading state before getMoodsForRange completes
    expect(find.text('Log →'), findsNothing);
    expect(find.text('Edit →'), findsNothing);
    expect(find.text('Loading...'), findsOneWidget);
  });

  testWidgets('card is tappable — InkWell is present in the widget tree', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodTrackerCard())),
    );
    // The new design wraps the card in Material+InkWell — old design used GlassCard.onTap
    // This test FAILS before the rewrite because GlassCard uses its own InkWell internally,
    // but after the rewrite there is an InkWell at the root level with borderRadius.
    final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
    expect(inkWells.isNotEmpty, isTrue);
  });

  testWidgets('shows Mood label text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodTrackerCard())),
    );
    expect(find.text('Mood'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify the key tests fail before rewrite**

```bash
flutter test test/widgets/dashboard/mood_tracker_card_test.dart -v
```

Expected: "loading state: pill is hidden" FAIL (old card shows emoji/text in loading, not 'Loading...'); "card is tappable via InkWell" may pass or fail; "shows Mood label" passes (old card has 'Mood'). Confirm at least one RED test before proceeding.

- [ ] **Step 3: Rewrite `mood_tracker_card.dart`**

Replace the entire file content:

```dart
import 'package:flutter/material.dart';

import '../../models/mood_entry.dart';
import '../../screens/mood_detail_screen.dart';
import '../../services/mood_storage_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

class MoodTrackerCard extends StatefulWidget {
  const MoodTrackerCard({super.key});

  @override
  State<MoodTrackerCard> createState() => _MoodTrackerCardState();
}

class _MoodTrackerCardState extends State<MoodTrackerCard> {
  int? _todayMood;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final moods = await MoodStorageService.getMoodsForRange(start, end);
    final todayEntry = moods.where((e) => e.dateKey == todayKey).toList();
    if (mounted) {
      setState(() {
        _todayMood = todayEntry.isNotEmpty ? todayEntry.first.value : null;
        _loaded = true;
      });
    }
  }

  Future<void> _openMoodDetail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MoodDetailScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Pill label — hidden during loading
    final String? pillLabel = !_loaded
        ? null
        : (_todayMood != null ? 'Edit →' : 'Log →');

    // Mood asset widget
    final Widget moodAsset = !_loaded
        ? const SizedBox(width: 52, height: 52)
        : _todayMood != null
            ? Image.asset(assetForMood(_todayMood!), width: 52, height: 52)
            : Image.asset(
                'assets/moods/okay.png',
                width: 52,
                height: 52,
                opacity: const AlwaysStoppedAnimation(0.5),
              );

    // Body text
    final String bodyText = !_loaded
        ? 'Loading...'
        : (_todayMood != null
            ? labelForMood(_todayMood!)
            : 'How are you feeling today?');

    return Material(
      color: Colors.transparent, // Flutter layout idiom — not a design color token
      child: InkWell(
        onTap: _openMoodDetail,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.lavenderContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                moodAsset,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mood',
                        style: AppTypography.caption(context).copyWith(
                          color: AppColors.lavenderDew,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        bodyText,
                        style: AppTypography.body(context)
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (pillLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderDew.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                    ),
                    child: Text(
                      pillLabel,
                      style: AppTypography.caption(context).copyWith(
                        color: AppColors.lavenderDew,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/widgets/dashboard/mood_tracker_card_test.dart -v
```

Expected: All PASS

- [ ] **Step 5: Verify no analysis errors**

```bash
flutter analyze lib/widgets/dashboard/mood_tracker_card.dart
```

Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/dashboard/mood_tracker_card.dart test/widgets/dashboard/mood_tracker_card_test.dart
git commit -m "feat: redesign MoodTrackerCard as lavender banner with 3-state row layout"
```

---

## Task 3: `InsightsSummaryCard` — centered stat column

**Files:**
- Modify: `lib/widgets/dashboard/insights_summary_card.dart`

**Context:** The existing card uses `GlassCard` wrapper, loads habits via `HabitStorageService.loadAll()`, tracks `_loaded` bool and `_habits` list. Keep all state logic. Only the visual layout inside the `GlassCard` changes to a centered column: icon → percentage → subtitle → progress bar → "Insights ›" link.

- [ ] **Step 1: Write the failing test**

Create `test/widgets/dashboard/insights_summary_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_vision_board/widgets/dashboard/insights_summary_card.dart';

void main() {
  // These tests inspect the loading state (before async _loadHabits completes),
  // which is deterministic without mocking HabitStorageService.
  testWidgets('loading state: shows LinearProgressIndicator, no old heading row', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InsightsSummaryCard())),
    );
    // No pump() — widget is in loading state (_loaded == false)
    // Old card had a heading Row with 'Insights' text and chevron icon
    // New card shows a slim LinearProgressIndicator in loading state
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    // Old layout had 'Insights' as a heading3 text in a Row — new layout has no heading
    expect(find.text('Insights'), findsNothing);
  });

  testWidgets('loading state: does NOT show insights_rounded icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InsightsSummaryCard())),
    );
    // Icon only appears in the loaded+data state — not during loading
    expect(find.byIcon(Icons.insights_rounded), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/widgets/dashboard/insights_summary_card_test.dart -v
```

Expected: "loading state: does NOT show insights_rounded icon" — may currently PASS (old card has no such icon either) but "shows LinearProgressIndicator, no old heading row" will FAIL because old card shows the 'Insights' heading text during loading.

- [ ] **Step 3: Rewrite the `build` method of `InsightsSummaryCard`**

Replace the `build` method body in `lib/widgets/dashboard/insights_summary_card.dart`. Keep all `import` statements, the class declaration, state fields, `initState`, `dispose`, `activate`, `didChangeAppLifecycleState`, `_loadHabits`, and `_openInsights` unchanged. Only replace the `build` method:

```dart
@override
Widget build(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  final now = LogicalDateService.now();
  final today = DateTime(now.year, now.month, now.day);
  final todaysHabits = _habits.where((h) => h.isScheduledOnDate(today)).toList();
  final completed = todaysHabits.where((h) => h.isCompletedOnDate(today)).length;
  final total = todaysHabits.length;
  final rate = total > 0 ? completed / total : 0.0;
  final pct = (rate * 100).toStringAsFixed(0);

  return GlassCard(
    onTap: _openInsights,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_loaded) ...[
            SizedBox(
              height: AppSpacing.xs,
              child: LinearProgressIndicator(
                backgroundColor:
                    colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              ),
            ),
          ] else if (total == 0) ...[
            Text(
              _habits.isEmpty ? 'No habits tracked yet' : 'No habits today',
              style: AppTypography.bodySmall(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Icon(Icons.insights_rounded, size: 22, color: colorScheme.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$pct%',
              style: AppTypography.heading2(context)
                  .copyWith(color: colorScheme.primary),
            ),
            Text(
              '$completed of $total done',
              style: AppTypography.caption(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: rate,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Insights ›',
              style: AppTypography.caption(context).copyWith(
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
```

Also add the missing import at the top of the file if not already present:
```dart
import '../../utils/app_spacing.dart';
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/widgets/dashboard/insights_summary_card_test.dart -v
```

Expected: PASS

- [ ] **Step 5: Verify no analysis errors**

```bash
flutter analyze lib/widgets/dashboard/insights_summary_card.dart
```

Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/dashboard/insights_summary_card.dart test/widgets/dashboard/insights_summary_card_test.dart
git commit -m "feat: redesign InsightsSummaryCard as centered stat column"
```

---

## Task 4: `RewardAdsCoinCard` — slim horizontal row

**Files:**
- Modify: `lib/widgets/dashboard/reward_ads_coin_card.dart`
- Test: `test/widgets/dashboard/reward_ads_coin_card_test.dart`

**Context:** All state logic (`_onWatchAdTap`, `_handleRewardEarned`, `_isLoading`, `_watchedInCycle`, `_showAds`, `coinNotifier`, and the inline state-loading code in `initState`) stays exactly the same. Only the `build` method changes. Remove: `heading1` counter text, `SizedBox(height: 52)` button, `"Each ad earns X coins"` text. The new layout is a single `Row` inside `GlassCard`.

The card is **not** tappable as a whole — only the Watch button triggers `_onWatchAdTap`.

- [ ] **Step 1: Write the failing tests**

Create `test/widgets/dashboard/reward_ads_coin_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_vision_board/widgets/dashboard/reward_ads_coin_card.dart';

void main() {
  testWidgets('shows Rewards label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RewardAdsCoinCard())),
    );
    await tester.pump();
    expect(find.text('Rewards'), findsOneWidget);
  });

  testWidgets('shows Watch button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RewardAdsCoinCard())),
    );
    await tester.pump();
    expect(find.text('Watch'), findsOneWidget);
  });

  testWidgets('does NOT show large 0/3 counter text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RewardAdsCoinCard())),
    );
    await tester.pump();
    // Old layout had a heading1-styled "0/3" counter; new layout has no such widget
    final heading1Texts = tester.widgetList<Text>(find.byType(Text))
        .where((t) => t.data != null && RegExp(r'^\d/\d$').hasMatch(t.data!))
        .toList();
    expect(heading1Texts, isEmpty);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/widgets/dashboard/reward_ads_coin_card_test.dart -v
```

Expected: "shows Watch button" FAIL (current label is "Watch ad"), "does NOT show large 0/3 counter" FAIL (it currently shows "0/3" as heading1)

- [ ] **Step 3: Replace the `build` method**

Replace just the `build` method in `lib/widgets/dashboard/reward_ads_coin_card.dart`. Keep all other code (imports, class, state, constants, logic methods) unchanged:

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  // Segment bar
  final segmentBar = Row(
    children: List.generate(_adsPerReward, (i) {
      final isFilled = i < _watchedInCycle;
      return Expanded(
        child: Container(
          height: AppSpacing.xs,
          margin: EdgeInsets.only(right: i < _adsPerReward - 1 ? AppSpacing.xs : 0),
          decoration: BoxDecoration(
            color: isFilled ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.xs),
          ),
        ),
      );
    }),
  );

  // Watch button — three states
  Widget watchButton;
  if (_isLoading) {
    watchButton = SizedBox(
      width: 72,
      height: 36,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      ),
    );
  } else if (!_showAds) {
    watchButton = FilledButton(
      onPressed: null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(72, 36),
        shape: const StadiumBorder(),
      ),
      child: const Text('Off'),
    );
  } else {
    watchButton = FilledButton.icon(
      onPressed: _onWatchAdTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size(72, 36),
        shape: const StadiumBorder(),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 14),
      label: const Text('Watch'),
    );
  }

  return GlassCard(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.ondemand_video_rounded, size: 18, color: cs.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rewards',
                  style: AppTypography.caption(context).copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                segmentBar,
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _showAds
                      ? '$_watchedInCycle of $_adsPerReward · +$_coinsPerAd coins per ad'
                      : 'Ads disabled',
                  style: AppTypography.caption(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          watchButton,
        ],
      ),
    ),
  );
}
```

Also add the missing import if not already present:
```dart
import '../../utils/app_spacing.dart';
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/widgets/dashboard/reward_ads_coin_card_test.dart -v
```

Expected: All PASS

- [ ] **Step 5: Verify no analysis errors**

```bash
flutter analyze lib/widgets/dashboard/reward_ads_coin_card.dart
```

Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/dashboard/reward_ads_coin_card.dart test/widgets/dashboard/reward_ads_coin_card_test.dart
git commit -m "feat: collapse RewardAdsCoinCard to slim horizontal row"
```

---

## Task 5: `dashboard_tab.dart` — new layout structure

**Files:**
- Modify: `lib/widgets/dashboard/dashboard_tab.dart`

**Context:** Replace the current layout (Insights|Mood row, then Water|Rewards row with `IntrinsicHeight`) with the new order: HabitProgress → Mood (full width) → Insights+Water (fixed `SizedBox(height: 160)` row, no `IntrinsicHeight`) → Rewards (full width) → Puzzle (full width). Use `AppSpacing.md` for horizontal padding, `AppSpacing.sm` for inter-card spacing, `AppSpacing.md` for vertical padding — matching existing values.

Note: The existing file uses hardcoded `16`, `12` values. Replace them with `AppSpacing.md` and `AppSpacing.sm` tokens during this rewrite.

- [ ] **Step 1: Write the failing test**

Create `test/widgets/dashboard/dashboard_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_vision_board/widgets/dashboard/dashboard_tab.dart';
import 'package:digital_vision_board/widgets/dashboard/mood_tracker_card.dart';
import 'package:digital_vision_board/widgets/dashboard/insights_summary_card.dart';
import 'package:digital_vision_board/widgets/dashboard/water_intake_card.dart';
import 'package:digital_vision_board/widgets/dashboard/reward_ads_coin_card.dart';
import 'package:digital_vision_board/widgets/dashboard/puzzle_summary_card.dart';

void main() {
  Widget buildTab() => MaterialApp(
        home: Scaffold(
          body: DashboardTab(
            boards: const [],
            activeBoardId: null,
            routines: const [],
            activeRoutineId: null,
            onCreateBoard: () {},
            onOpenEditor: (_) {},
            onOpenViewer: (_) {},
            onDeleteBoard: (_) {},
          ),
        ),
      );

  testWidgets('renders all 5 card types', (tester) async {
    await tester.pumpWidget(buildTab());
    await tester.pump();
    expect(find.byType(MoodTrackerCard), findsOneWidget);
    expect(find.byType(InsightsSummaryCard), findsOneWidget);
    expect(find.byType(WaterIntakeCard), findsOneWidget);
    expect(find.byType(RewardAdsCoinCard), findsOneWidget);
    expect(find.byType(PuzzleSummaryCard), findsOneWidget);
  });

  testWidgets('Insights and Water are in a fixed-height SizedBox(160)', (tester) async {
    await tester.pumpWidget(buildTab());
    await tester.pump();

    // Should find a SizedBox with height 160
    final boxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    final has160 = boxes.any((b) => b.height == 160.0);
    expect(has160, isTrue);
  });

  testWidgets('no IntrinsicHeight widget in the tree', (tester) async {
    await tester.pumpWidget(buildTab());
    await tester.pump();
    expect(find.byType(IntrinsicHeight), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/widgets/dashboard/dashboard_tab_test.dart -v
```

Expected: "no IntrinsicHeight" FAIL (current code has 2 IntrinsicHeight), "Insights and Water in 160" FAIL

- [ ] **Step 3: Replace `dashboard_tab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../models/routine.dart';
import '../../utils/app_spacing.dart';
import 'habit_progress_completion_card.dart';
import 'puzzle_summary_card.dart';
import 'insights_summary_card.dart';
import 'mood_tracker_card.dart';
import 'reward_ads_coin_card.dart';
import 'water_intake_card.dart';

class DashboardTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final String? activeBoardId;
  final List<Routine> routines;
  final String? activeRoutineId;
  final SharedPreferences? prefs;
  final int dataVersion;
  final ValueNotifier<int>? coinNotifier;
  final VoidCallback onCreateBoard;
  final ValueChanged<VisionBoardInfo> onOpenEditor;
  final ValueChanged<VisionBoardInfo> onOpenViewer;
  final ValueChanged<VisionBoardInfo> onDeleteBoard;
  final VoidCallback? onStartChallenge;
  final VoidCallback? onViewHabits;

  const DashboardTab({
    super.key,
    required this.boards,
    required this.activeBoardId,
    required this.routines,
    required this.activeRoutineId,
    this.prefs,
    this.dataVersion = 0,
    this.coinNotifier,
    required this.onCreateBoard,
    required this.onOpenEditor,
    required this.onOpenViewer,
    required this.onDeleteBoard,
    this.onStartChallenge,
    this.onViewHabits,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          // 1. Habit progress (unchanged)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: HabitProgressCompletionCard(
              onTap: onViewHabits,
              onStartChallenge: onStartChallenge,
              dataVersion: dataVersion,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 2. Mood banner (full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: const MoodTrackerCard(),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 3. Insights + Water — fixed height row
          // Fixed height avoids IntrinsicHeight + double-layout on every wave animation frame
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: InsightsSummaryCard()),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(child: WaterIntakeCard()),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 4. Rewards slim row (full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: RewardAdsCoinCard(coinNotifier: coinNotifier),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 5. Puzzle (full width)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: PuzzleSummaryCard(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/widgets/dashboard/dashboard_tab_test.dart -v
```

Expected: All PASS

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: All pass (or same pass rate as before this change).

- [ ] **Step 6: Verify no analysis errors**

```bash
flutter analyze lib/widgets/dashboard/dashboard_tab.dart
```

Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/dashboard/dashboard_tab.dart test/widgets/dashboard/dashboard_tab_test.dart
git commit -m "feat: reorder dashboard layout — mood banner, fixed Insights+Water row, slim Rewards, full-width Puzzle"
```

---

## Task 6: Manual smoke test + design-check

- [ ] **Step 1: Run static analysis on all changed files**

```bash
cd /Users/preeth/digital-vision-board
flutter analyze lib/widgets/dashboard/mood_tracker_card.dart lib/widgets/dashboard/insights_summary_card.dart lib/widgets/dashboard/water_intake_card.dart lib/widgets/dashboard/reward_ads_coin_card.dart lib/widgets/dashboard/dashboard_tab.dart
```

Expected: No issues found.

- [ ] **Step 2: Run app and visually verify**

```bash
flutter run
```

Navigate to Dashboard tab. Verify:
- Mood card spans full width with lavender background
- Insights and Water sit side-by-side in equal-width columns (approx 160px tall)
- Rewards shows as a single slim horizontal row with a compact Watch button
- Puzzle is full-width at the bottom
- No overflow indicators (yellow/black stripes)
- Water wave animation plays without jank

- [ ] **Step 3: Verify WaterIntakeCard at 160px doesn't overflow in all states**

Test with: zero glasses logged, partial glasses, goal reached. All should render cleanly at 160px height.

- [ ] **Step 4: Final commit if any touch-ups needed**

```bash
git add -p
git commit -m "fix: dashboard smoke test touch-ups"
```
