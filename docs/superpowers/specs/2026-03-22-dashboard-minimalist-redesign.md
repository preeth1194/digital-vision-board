# Dashboard Minimalist Redesign

**Date:** 2026-03-22
**Status:** Approved

---

## Overview

Rethink the layout and sizing of all dashboard cards below `HabitProgressCompletionCard` to create a cleaner, more minimalistic morning-glance experience. The `HabitProgressCompletionCard` (plant growth + percentage + habit list) is explicitly **unchanged**.

---

## Goals

1. Reduce visual clutter — fewer competing elements at equal size.
2. Give Mood its own emotional weight via a full-width banner.
3. Insights becomes a tight centered-stat card paired with the Water card.
4. Rewards shrinks to a slim action row — it's secondary, not a hero.
5. Puzzle returns to full width so the piece grid has room to breathe.

---

## New Layout Order (`DashboardTab`)

```
[HabitProgressCompletionCard]   ← unchanged, full width

[MoodTrackerCard]               ← full width, lavender banner

[InsightsSummaryCard | WaterIntakeCard]   ← half-row, equal flex

[RewardAdsCoinCard]             ← full width, slim horizontal row

[PuzzleSummaryCard]             ← full width
```

All spacing between cards: `12` px (no change from current).
Outer horizontal padding: `16` px (no change from current).

---

## Component Specs

### 1. `MoodTrackerCard` — Full-width banner

**File:** `lib/widgets/dashboard/mood_tracker_card.dart`

**Layout:** Horizontal `Row` inside a `GlassCard` (or plain `Container`).

**Background:** `AppColors.lavenderContainer` (i.e., `Color(0xFFEEEDF8)`) with `AppSpacing.radiusCard` border radius. Use a plain `Container` with this fill color — no `GlassCard` backdrop blur needed here.

**Row children (left → right):**
- Mood emoji / asset: `56` logical px tall. When mood is logged show the real mood widget; when not logged show a neutral placeholder emoji (`😐`).
- Middle `Expanded` column:
  - Label: `"Mood"` in `AppTypography.caption(context)`, color `AppColors.lavenderDew`, uppercase, letter-spacing `0.5`.
  - Body: `"How are you feeling today?"` (not logged) or the mood label text (logged) in `AppTypography.body(context)`, `colorScheme.onSurface`, `fontWeight: FontWeight.w500`.
- Right pill button: `"Log →"` (not logged) or `"Edit →"` (already logged). Style: `AppColors.lavenderDew` at `alpha 0.15` background, `AppColors.lavenderDew` text, `AppSpacing.radiusChip` border radius, `padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs)`.

Tap the entire card → navigate to `MoodDetailScreen` (same as current).

---

### 2. `InsightsSummaryCard` — Centered stat column

**File:** `lib/widgets/dashboard/insights_summary_card.dart`

**Container:** `GlassCard` (unchanged wrapper), `flex: 1` in the half-row.

**Internal layout:** Single `Column`, `crossAxisAlignment: CrossAxisAlignment.center`, `mainAxisAlignment: MainAxisAlignment.center`.

**Children (top → bottom):**
1. `Icon(Icons.insights_rounded)` — size `22`, color `colorScheme.primary`.
2. `SizedBox(height: AppSpacing.xs)`
3. Percentage text — `AppTypography.heading2(context)`, color `colorScheme.primary`.
4. Subtitle — `"X of Y done"` in `AppTypography.caption(context)`, `colorScheme.onSurfaceVariant`.
5. `SizedBox(height: AppSpacing.sm)`
6. `LinearProgressIndicator` — full width, value `completed/total`, `borderRadius: BorderRadius.circular(4)`.
7. `SizedBox(height: AppSpacing.sm)`
8. `"Insights ›"` — `AppTypography.caption(context)`, color `colorScheme.primary.withValues(alpha: 0.5)`.

Empty/no-habits states ("No habits today", "No habits tracked yet") remain as currently implemented, just centered.

Tap → navigate to `GlobalInsightsScreen` (same as current).

---

### 3. `WaterIntakeCard` — Keep wave animation, shrink buttons

**File:** `lib/widgets/dashboard/water_intake_card.dart`

**Change:** Reduce `+`/`−` control button height from `52` → `36` logical px. No other changes to layout, animation, wave painter, or goal editor.

Specifically change the `SizedBox(height: 52)` inside `_ControlButton.build()` to `SizedBox(height: 36)`.

---

### 4. `RewardAdsCoinCard` — Slim horizontal row

**File:** `lib/widgets/dashboard/reward_ads_coin_card.dart`

Collapse from a tall card with a big counter + full-width button into a single horizontal row.

**Container:** `GlassCard`, full width.

**Internal layout:** `Padding(AppSpacing.md)` → `Row`:

| Slot | Content |
|---|---|
| Leading icon | `Icon(Icons.ondemand_video_rounded, size: 18, color: colorScheme.primary)` |
| `SizedBox(width: AppSpacing.sm)` | — |
| `Expanded` column | Tag `"Rewards"` (caption style) · `SizedBox(height: 3)` · Segment bar (3 segments, height 3 px, same colors as current) · `SizedBox(height: 3)` · `"X of 3 · +20 coins per ad"` caption |
| `SizedBox(width: AppSpacing.sm)` | — |
| Watch button | `FilledButton` (or `ElevatedButton.icon`) label `"▶ Watch"`, compact: `minimumSize: Size(72, 36)` |

Remove: the large `"0/3"` heading text, the tall `SizedBox(height: 52)` ElevatedButton.icon, and the `"Each ad earns X coins"` full line (fold it into the row caption above).

All existing logic (`_onWatchAdTap`, `_handleRewardEarned`, loading state, snack bars, ad-free check) stays exactly the same — only the visual layout changes.

---

### 5. `PuzzleSummaryCard` — Full width (layout change only)

**File:** `lib/widgets/dashboard/puzzle_summary_card.dart`
**File:** `lib/widgets/dashboard/dashboard_tab.dart`

No changes to `PuzzleSummaryCard` itself. In `dashboard_tab.dart`, move it so it renders full-width below `RewardAdsCoinCard`, not in a row with any other card.

---

## `dashboard_tab.dart` — Updated structure

```dart
SingleChildScrollView(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Column(
    children: [
      // 1. Habit progress (unchanged)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: HabitProgressCompletionCard(...),
      ),
      const SizedBox(height: 12),

      // 2. Mood banner (full width)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: MoodTrackerCard(),
      ),
      const SizedBox(height: 12),

      // 3. Insights + Water (half-row)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: InsightsSummaryCard()),
              const SizedBox(width: 12),
              Expanded(child: WaterIntakeCard()),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // 4. Rewards slim row (full width)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: RewardAdsCoinCard(coinNotifier: coinNotifier),
      ),
      const SizedBox(height: 12),

      // 5. Puzzle (full width)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PuzzleSummaryCard(),
      ),
    ],
  ),
)
```

---

## Design Tokens

- Card backgrounds: `GlassCard` (existing) for Insights, Water, Rewards, Puzzle.
- Mood card background: plain `Container` with `AppColors.lavenderContainer`, radius `AppSpacing.radiusCard`.
- Mood pill: `AppColors.lavenderDew` tint background, `AppColors.lavenderDew` text.
- Insights icon/value/link: `colorScheme.primary`.
- Insights subtitle / caption: `colorScheme.onSurfaceVariant`.
- Rewards segment fill: `colorScheme.primary` (unchanged).
- No hardcoded pixel values except existing wave animation math and the button height change (`36`).
- No emoji strings — Mood emoji asset from `MoodStorageService` (existing pattern).

---

## Files Changed

| File | Change |
|---|---|
| `lib/widgets/dashboard/dashboard_tab.dart` | Reorder children per new layout |
| `lib/widgets/dashboard/mood_tracker_card.dart` | Redesign as full-width lavender banner |
| `lib/widgets/dashboard/insights_summary_card.dart` | Centered column layout |
| `lib/widgets/dashboard/water_intake_card.dart` | Button height 52 → 36 |
| `lib/widgets/dashboard/reward_ads_coin_card.dart` | Collapse to slim horizontal row |

---

## Out of Scope

- `HabitProgressCompletionCard` — no changes
- `PuzzleSummaryCard` internals — no changes
- `GlassCard` — no changes
- `AffirmationSummaryCard`, `CalorieTrackerCard`, `GoalLogsSummaryCard` — not on default dashboard tab, no changes
- Dark mode theming — existing `GlassCard` and `AppColors` tokens handle it automatically
- Navigation logic — all tap handlers unchanged
