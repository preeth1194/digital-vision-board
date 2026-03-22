import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/insights_month_summary.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import '../rituals/habit_form_constants.dart';

/// Card that highlights the most consistent habit for the selected month.
///
/// Shows on the Insights screen when "All" habits is selected.
/// Displays the habit's icon, name, consistency percentage, and current streak.
class InsightsConsistencyCard extends StatelessWidget {
  const InsightsConsistencyCard({
    super.key,
    required this.habits,
    required this.year,
    required this.month,
    required this.onSelect,
  });

  /// All habits to analyze for consistency.
  final List<HabitItem> habits;

  /// Year for the month summary.
  final int year;

  /// Month for the month summary.
  final int month;

  /// Called with the habit's id when the card is tapped.
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Build the month summary.
    final summary = InsightsMonthSummary.forMonth(year, month);

    // Find the most consistent habit.
    HabitItem? mostConsistentHabit;
    double bestRatio = -1;

    for (final habit in habits) {
      final scheduled =
          InsightsMonthSummary.scheduledDaysInMonth(habit, summary);

      // Skip habits with no scheduled days this month.
      if (scheduled == 0) continue;

      final completed =
          InsightsMonthSummary.completedScheduledDaysInMonth(habit, summary);

      final ratio = completed / scheduled;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        mostConsistentHabit = habit;
      }
    }

    // If no eligible habits, return empty.
    if (mostConsistentHabit == null) {
      return const SizedBox.shrink();
    }

    final habit = mostConsistentHabit;
    final scheduled =
        InsightsMonthSummary.scheduledDaysInMonth(habit, summary);
    final completed =
        InsightsMonthSummary.completedScheduledDaysInMonth(habit, summary);
    final pct = (completed / scheduled * 100).round();
    final streak = habit.currentStreakAsOf(LogicalDateService.today());

    // Get habit icon.
    final habitIcon = habitIcons[habit.iconIndex ?? 0].$1;

    return GestureDetector(
      onTap: () => onSelect(habit.id),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Left: Icon circle.
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
              alignment: Alignment.center,
              child: Icon(
                habitIcon,
                size: 22,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Middle: Text content (expanded).
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label.
                  Text(
                    'Most consistent habit',
                    style: AppTypography.caption(context).copyWith(
                      color: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Habit name.
                  Text(
                    habit.name,
                    style: AppTypography.heading3(context).copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Percentage and streak.
                  Row(
                    children: [
                      Text(
                        '$pct% this month',
                        style: AppTypography.caption(context).copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.85),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: Text(
                          '•',
                          style: AppTypography.caption(context).copyWith(
                            color: colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      Text(
                        '${streak}d streak',
                        style: AppTypography.caption(context).copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Right: Chevron icon.
            Icon(
              Icons.chevron_right_rounded,
              color:
                  colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
