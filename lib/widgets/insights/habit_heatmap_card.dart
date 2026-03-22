import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/insights_month_summary.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

class HabitHeatmapCard extends StatelessWidget {
  const HabitHeatmapCard({
    super.key,
    required this.habit,
    required this.habits,
    required this.year,
    required this.month,
    this.today,
  });

  final HabitItem? habit;
  final List<HabitItem> habits;
  final int year;
  final int month;

  /// Override today for testing; defaults to LogicalDateService.today().
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveToday = today ?? LogicalDateService.today();
    final summary = InsightsMonthSummary.forMonth(year, month);

    final int offsetCells = DateTime(year, month, 1).weekday % 7;
    final int totalCells = offsetCells + summary.daysInMonth;

    // Progress bar values
    final int scheduledTotal;
    final int completedTotal;
    if (habit != null) {
      scheduledTotal =
          InsightsMonthSummary.scheduledDaysInMonth(habit!, summary);
      completedTotal =
          InsightsMonthSummary.completedScheduledDaysInMonth(habit!, summary);
    } else if (habits.isEmpty) {
      scheduledTotal = 0;
      completedTotal = 0;
    } else {
      scheduledTotal = habits.fold(
        0,
        (s, h) => s + InsightsMonthSummary.scheduledDaysInMonth(h, summary),
      );
      completedTotal = habits.fold(
        0,
        (s, h) =>
            s + InsightsMonthSummary.completedScheduledDaysInMonth(h, summary),
      );
    }
    final progressValue =
        scheduledTotal > 0 ? completedTotal / scheduledTotal : 0.0;
    final pct = (progressValue * 100).round();

    // Aggregate completions per day (only used in aggregate mode)
    final List<int> aggregate = habit == null && habits.isNotEmpty
        ? InsightsMonthSummary.aggregateCompletionsPerDay(habits, summary)
        : const [];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (habit != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      habit!.name,
                      style: AppTypography.heading3(context),
                    ),
                  ),
                  Image.asset(
                    'assets/icon/app_icon.png',
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Habit Seeding',
                    style: AppTypography.caption(context).copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          // Day-of-week headers
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: AppTypography.caption(context).copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < offsetCells) return const SizedBox.shrink();
              final dayIndex = index - offsetCells; // 0-based
              final date = summary.days[dayIndex];
              return _buildCell(
                colorScheme: colorScheme,
                date: date,
                dayIndex: dayIndex,
                today: effectiveToday,
                aggregate: aggregate,
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          // Legend (single habit mode only)
          if (habit != null) _buildLegend(context, colorScheme),
          if (habit != null) const SizedBox(height: AppSpacing.sm),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completedTotal of $scheduledTotal scheduled days',
                  style: AppTypography.caption(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: AppTypography.caption(context).copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progressValue,
            backgroundColor: colorScheme.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildCell({
    required ColorScheme colorScheme,
    required DateTime date,
    required int dayIndex,
    required DateTime today,
    required List<int> aggregate,
  }) {
    final isFuture = date.isAfter(today);
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    Color bgColor;
    Border? border;

    if (habit != null) {
      // Single habit mode
      if (isFuture) {
        bgColor = colorScheme.surfaceContainerHigh;
        border = Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        );
      } else if (habit!.isScheduledOnDate(date) &&
          habit!.isCompletedOnDate(date)) {
        bgColor = colorScheme.primary;
      } else if (habit!.isScheduledOnDate(date) &&
          !habit!.isCompletedOnDate(date)) {
        bgColor = AppColors.missedHabitCell.withValues(alpha: 0.7);
      } else {
        bgColor = colorScheme.surfaceContainerHigh;
      }
    } else {
      // Aggregate mode
      if (aggregate.isEmpty || isFuture) {
        bgColor = colorScheme.surfaceContainerHigh;
      } else {
        final count = aggregate[dayIndex];
        final total = habits.length;
        if (count == 0) {
          bgColor = colorScheme.surfaceContainerHigh;
        } else if (count >= total) {
          bgColor = colorScheme.primary;
        } else {
          bgColor = colorScheme.primary.withValues(
            alpha: (count / total * 0.7 + 0.2).clamp(0.0, 1.0),
          );
        }
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
        border: isToday
            ? Border.all(color: colorScheme.primary, width: 1.5)
            : border,
      ),
    );
  }

  Widget _buildLegend(BuildContext context, ColorScheme colorScheme) {
    final items = [
      (colorScheme.primary, null as double?, 'Done'),
      (AppColors.missedHabitCell, 0.7, 'Missed'),
      (colorScheme.surfaceContainerHigh, null as double?, 'Future / not scheduled'),
    ];
    return Wrap(
      spacing: 12,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.$2 != null
                    ? item.$1.withValues(alpha: item.$2!)
                    : item.$1,
                borderRadius: BorderRadius.circular(2),
                border: item.$2 == null &&
                        item.$1 == colorScheme.surfaceContainerHigh
                    ? Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                        width: 1,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              item.$3,
              style: AppTypography.caption(context).copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
