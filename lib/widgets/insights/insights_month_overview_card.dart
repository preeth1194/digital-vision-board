import 'package:flutter/material.dart';
import '../../models/habit_item.dart';
import '../../models/insights_month_summary.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

class InsightsMonthOverviewCard extends StatelessWidget {
  const InsightsMonthOverviewCard({
    super.key,
    required this.habits,
    required this.summary,
  });

  final List<HabitItem> habits;
  final InsightsMonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate stats
    int totalSeeds = 0;
    int totalCompleted = 0;
    int totalScheduled = 0;
    int activeHabits = 0;

    for (final habit in habits) {
      final scheduled =
          InsightsMonthSummary.scheduledDaysInMonth(habit, summary);
      final completed =
          InsightsMonthSummary.completedScheduledDaysInMonth(habit, summary);
      final seeds = InsightsMonthSummary.seedsEarnedInMonth(habit, summary);

      totalSeeds += seeds;
      totalCompleted += completed;
      totalScheduled += scheduled;
      if (scheduled > 0) {
        activeHabits++;
      }
    }

    // Calculate completion percentage
    final completionPercent = totalScheduled > 0
        ? (totalCompleted / totalScheduled * 100).round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'This Month',
            style: AppTypography.heading3(context),
          ),
          SizedBox(height: AppSpacing.md),
          // Stats row
          IntrinsicHeight(
            child: Row(
              children: [
                // Seeds stat
                Expanded(
                  child: _StatItem(
                    icon: Icons.eco_outlined,
                    iconColor: AppColors.honeyText,
                    value: '$totalSeeds',
                    label: 'Seeds earned',
                  ),
                ),
                VerticalDivider(
                  width: AppSpacing.lg,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                // Completion stat
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: colorScheme.primary,
                    value: '$completionPercent%',
                    label: 'Completed',
                  ),
                ),
                VerticalDivider(
                  width: AppSpacing.lg,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                // Active habits stat
                Expanded(
                  child: _StatItem(
                    icon: Icons.track_changes_rounded,
                    iconColor: AppColors.lavenderDew,
                    value: '$activeHabits',
                    label: 'Active habits',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.heading2(context).copyWith(color: iconColor),
        ),
        Text(
          label,
          style: AppTypography.caption(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
