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

[InsightsSummaryCard | WaterIntakeCard]   ← fixed-height row (160 px), equal flex

[RewardAdsCoinCard]             ← full width, slim horizontal row

[PuzzleSummaryCard]             ← full width
```

All spacing between cards: `AppSpacing.sm` (8 px — matches current, no change).
Outer horizontal padding: `AppSpacing.md` (16 px — matches current, no change).

---

## Component Specs

### 1. `MoodTrackerCard` — Full-width banner

**File:** `lib/widgets/dashboard/mood_tracker_card.dart`

**Layout:** Horizontal `Row` inside a plain `Container` (no `GlassCard` backdrop blur).

**Background:** `AppColors.lavenderContainer` — use the token directly, never the raw `Color()` value. Border radius: `AppSpacing.radiusCard`.

**States:**

| State | Emoji/asset | Body text | Pill label |
|---|---|---|---|
| Loading | `SizedBox(width: 52, height: 52)` placeholder (empty box, same size as current) | `"Loading..."` caption | hide pill |
| Not logged | `Image.asset('assets/moods/okay.png', width: 52, height: 52, opacity: AlwaysStoppedAnimation(0.5))` | `"How are you feeling today?"` | `"Log →"` |
| Logged | `Image.asset(moodAssetPath, width: 52, height: 52)` (from `MoodStorageService`, same asset resolution as current) | mood label text (e.g. `"Feeling good"`) | `"Edit →"` |

Do not use Unicode emoji character literals anywhere. Always use `Image.asset` with the existing mood asset paths.

**Row children (left → right):**
- Mood asset/placeholder: fixed `52 × 52` logical px (unchanged from current implementation — see states above).
- `SizedBox(width: AppSpacing.md)`
- Middle `Expanded` column:
  - Label: `"Mood"` in `AppTypography.caption(context).copyWith(color: AppColors.lavenderDew, fontWeight: FontWeight.w600, letterSpacing: 0.5)`.
  - `SizedBox(height: AppSpacing.xs)`
  - Body text (see states above): `AppTypography.body(context).copyWith(fontWeight: FontWeight.w500)`, color `colorScheme.onSurface` (default, no override needed).
- `SizedBox(width: AppSpacing.sm)`
- Right pill (hidden during loading): `Container` with `AppColors.lavenderDew.withValues(alpha: 0.15)` background, `AppSpacing.radiusChip` border radius, `padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs)`. Child: `Text` styled with `AppTypography.caption(context).copyWith(color: AppColors.lavenderDew, fontWeight: FontWeight.w700)`.

Card padding: `EdgeInsets.all(AppSpacing.md)`.
Tap entire card → `MoodDetailScreen` (same as current). Use `GestureDetector` or wrap the `Container` in `Material` + `InkWell` with matching border radius.

---

### 2. `InsightsSummaryCard` — Centered stat column

**File:** `lib/widgets/dashboard/insights_summary_card.dart`

**Container:** `GlassCard` (unchanged wrapper), `flex: 1` in the fixed-height row.

**Internal layout:** `Padding(EdgeInsets.all(AppSpacing.md))` → `Column`, `crossAxisAlignment: CrossAxisAlignment.center`, `mainAxisAlignment: MainAxisAlignment.center`.

**Children (top → bottom):**
1. `Icon(Icons.insights_rounded)` — size `22`, color `colorScheme.primary`.
2. `SizedBox(height: AppSpacing.xs)`
3. Percentage text — `AppTypography.heading2(context).copyWith(color: colorScheme.primary)`.
4. Subtitle — `"X of Y done"` in `AppTypography.caption(context)` (default color `colorScheme.onSurfaceVariant` unchanged).
5. `SizedBox(height: AppSpacing.sm)`
6. `LinearProgressIndicator` — full width, value `completed/total`, `borderRadius: BorderRadius.circular(AppSpacing.xs)`.
7. `SizedBox(height: AppSpacing.sm)`
8. `"Insights ›"` — `AppTypography.caption(context).copyWith(color: colorScheme.primary.withValues(alpha: 0.5))`.

Loading state (`!_loaded`): show a slim `SizedBox(height: AppSpacing.xs, child: LinearProgressIndicator())` centered in the column — same as current implementation.
Empty/no-habits states: when `total == 0`, show a centered `Text` — `"No habits today"` if habits exist but none scheduled, `"No habits tracked yet"` if no habits at all — styled `AppTypography.bodySmall(context).copyWith(color: colorScheme.onSurfaceVariant)`. Layout is centered (same as current implementation).

Tap → `GlobalInsightsScreen` (same as current).

---

### 3. `WaterIntakeCard` — Keep wave animation, shrink buttons

**File:** `lib/widgets/dashboard/water_intake_card.dart`

**Change:** Reduce `+`/`−` control button height from `52` → `36` logical px. No other changes to layout, animation, wave painter, or goal editor.

Specifically change the `SizedBox(height: 52)` inside `_ControlButton.build()` to `SizedBox(height: 36)`.

**Layout note:** The Insights + Water row uses a fixed height of `160` px (see `dashboard_tab.dart` below) instead of `IntrinsicHeight`. This avoids double-layout passes on every frame of the wave animation. `WaterIntakeCard` already uses a `Stack` with `Positioned.fill` so it stretches naturally to the row height.

All existing WaterIntakeCard states (no goal set, partial fill, goal reached, loading) are preserved unchanged — only the `+`/`−` button height changes. Before shipping, verify the card renders without overflow or clipping at `160 px` in each state.

---

### 4. `RewardAdsCoinCard` — Slim horizontal row

**File:** `lib/widgets/dashboard/reward_ads_coin_card.dart`

Collapse from a tall card with a big counter + full-width button into a single horizontal row.

**Container:** `GlassCard`, full width. `Padding(EdgeInsets.all(AppSpacing.md))`.

**Internal layout:** `Row`, `crossAxisAlignment: CrossAxisAlignment.center`.

| Slot | Content |
|---|---|
| Leading icon | `Icon(Icons.ondemand_video_rounded, size: 18, color: colorScheme.primary)` |
| `SizedBox(width: AppSpacing.sm)` | — |
| `Expanded` column | `"Rewards"` label: `AppTypography.caption(context).copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)` · `SizedBox(height: AppSpacing.xs)` · Segment bar (3 segments, height `AppSpacing.xs`, filled color `colorScheme.primary`, unfilled color `colorScheme.surfaceContainerHighest`) · `SizedBox(height: AppSpacing.xs)` · caption `"X of 3 · +20 coins per ad"` when ads enabled; `"Ads disabled"` when ad-free — both in `AppTypography.caption(context)` default style |
| `SizedBox(width: AppSpacing.sm)` | — |
| Watch button | `FilledButton.icon` with `minimumSize: Size(72, 36)`, `shape: StadiumBorder()`, `icon: Icon(Icons.play_arrow_rounded, size: 14)`, `label: Text("Watch")` when ads enabled and not loading; `CircularProgressIndicator` sized 16×16 wrapped in `SizedBox(width: 72, height: 36)` when loading; `FilledButton` with label `"Off"` and `onPressed: null` when ad-free (disabled). |

**Ad-free state:** When `_showAds == false`, button shows `"Off"` and is disabled (`onPressed: null`). Caption shows `"Ads disabled"`. All other row elements remain visible.

Remove from the widget: the large `"0/3"` heading text, the tall `SizedBox(height: 52)` button, and the standalone `"Each ad earns X coins"` text widget.

All existing logic (`_onWatchAdTap`, `_handleRewardEarned`, loading state, snack bars, ad-free check, `coinNotifier`) stays exactly the same — only the visual layout changes.

---

### 5. `PuzzleSummaryCard` — Full width (layout change only)

**File:** `lib/widgets/dashboard/dashboard_tab.dart`

No changes to `PuzzleSummaryCard` internals. Move it to render full-width below `RewardAdsCoinCard` in `dashboard_tab.dart`.

---

## `dashboard_tab.dart` — Updated structure

```dart
SingleChildScrollView(
  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
  child: Column(
    children: [
      // 1. Habit progress (unchanged)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: HabitProgressCompletionCard(...),
      ),
      const SizedBox(height: AppSpacing.sm),

      // 2. Mood banner (full width)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: MoodTrackerCard(),
      ),
      const SizedBox(height: AppSpacing.sm),

      // 3. Insights + Water — fixed height row (avoids IntrinsicHeight + animation perf issue)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: InsightsSummaryCard()),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: WaterIntakeCard()),
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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: PuzzleSummaryCard(),
      ),
    ],
  ),
)
```

The fixed `height: 160` for the Insights+Water row is an intentional exception to the no-hardcoded-values rule — it replaces `IntrinsicHeight` specifically to avoid double-layout passes on every frame of the wave animation. If `AppSpacing` gains a semantic token for this value in future, use it.

---

## Design Tokens

- Mood card background: `AppColors.lavenderContainer` — token only, no raw `Color()` literal.
- Mood pill: `AppColors.lavenderDew.withValues(alpha: 0.15)` background, `AppColors.lavenderDew` text.
- Mood asset: `Image.asset` with paths from `MoodStorageService` — no Unicode emoji strings.
- Insights icon / value / nav link: `colorScheme.primary`.
- Insights subtitle / caption: `colorScheme.onSurfaceVariant`.
- Mood asset size: `52 × 52` px (intentional exception — unchanged from current; applies to both the `Image.asset` and the `SizedBox` loading placeholder).
- Mood pill labels `"Log →"` and `"Edit →"` use the Unicode `→` character as decorative label text in a `Text()` widget — this is a permitted string literal, not a standalone icon replacement.
- Water button height: `36` px (intentional exception — shrinking from `52`).
- Rewards segment bar height / spacers: `AppSpacing.xs` (token, not hardcoded).
- Rewards watch button: `FilledButton.icon` with `Icon(Icons.play_arrow_rounded, size: 14)` — no standalone Unicode `▶` character literals. Icon size `14` is an intentional exception.
- Rewards leading icon: `Icon(Icons.ondemand_video_rounded, size: 18)` — size `18` is an intentional exception.
- Rewards watch button `minimumSize: Size(72, 36)` — `72` px minimum width is an intentional exception (standard compact `FilledButton` minimum width).
- Rewards loading indicator: `SizedBox(width: 16, height: 16)` wrapping `CircularProgressIndicator` — `16` px is an intentional exception (standard small inline spinner size).
- Rewards segment fill: `colorScheme.primary` (unchanged).
- `InsightsSummaryCard` icon: `Icon(Icons.insights_rounded, size: 22)` — size `22` is an intentional exception.
- `InsightsSummaryCard` nav label `"Insights ›"` uses Unicode `›` (U+203A) as decorative chevron text in a `Text()` widget — this is a permitted string literal, not a standalone icon replacement.
- `MoodTrackerCard` label `letterSpacing: 0.5` — intentional exception; `AppSpacing` has no letter-spacing token.
- All other cards: `GlassCard` surface (unchanged).
- No other hardcoded pixel values.

---

## Files Changed

| File | Change |
|---|---|
| `lib/widgets/dashboard/dashboard_tab.dart` | Reorder children, replace `IntrinsicHeight` with fixed `SizedBox(height: 160)` for Insights+Water row |
| `lib/widgets/dashboard/mood_tracker_card.dart` | Redesign as full-width lavender banner with loading/not-logged/logged states |
| `lib/widgets/dashboard/insights_summary_card.dart` | Centered column layout |
| `lib/widgets/dashboard/water_intake_card.dart` | Button height 52 → 36 |
| `lib/widgets/dashboard/reward_ads_coin_card.dart` | Collapse to slim horizontal row, ad-free state mapped |

---

## Out of Scope

- `HabitProgressCompletionCard` — no changes
- `PuzzleSummaryCard` internals — no changes
- `GlassCard` — no changes
- `AffirmationSummaryCard`, `CalorieTrackerCard`, `GoalLogsSummaryCard` — not on default dashboard tab, no changes
- Dark mode theming — existing `GlassCard` and `AppColors` tokens handle it automatically
- Navigation logic — all tap handlers unchanged
