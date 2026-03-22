import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/insights_month_summary.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

/// A 2×2 grid of stat tiles for the Insights habit detail view.
///
/// Tiles: Seeds this month, Current streak, Best run, Time invested.
class InsightsStatGrid extends StatelessWidget {
  final HabitItem habit;
  final InsightsMonthSummary summary;

  const InsightsStatGrid({
    super.key,
    required this.habit,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final seeds = InsightsMonthSummary.seedsEarnedInMonth(habit, summary);
    final streak = habit.currentStreakAsOf(LogicalDateService.today());
    final bestRun = InsightsMonthSummary.longestCompletionRunInMonth(
      habit,
      summary,
    );
    final minutes = InsightsMonthSummary.estimatedMinutesInvested(
      habit,
      summary,
    );
    final timeValue = minutes != null ? '${minutes}m' : '—';

    final tiles = [
      _StatTileData(
        icon: Icons.eco_outlined,
        iconColor: AppColors.honeyText,
        value: '$seeds',
        label: 'Seeds this month',
      ),
      _StatTileData(
        icon: Icons.local_fire_department,
        iconColor: AppColors.seedGold,
        value: '$streak',
        label: 'Current streak',
      ),
      _StatTileData(
        icon: Icons.emoji_events_outlined,
        iconColor: colorScheme.primary,
        value: '$bestRun',
        label: 'Best run',
      ),
      _StatTileData(
        icon: Icons.timer_outlined,
        iconColor: AppColors.lavenderDew,
        value: timeValue,
        label: 'Time invested',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      children: tiles
          .map((tile) => _StatTile(tile: tile, colorScheme: colorScheme))
          .toList(),
    );
  }
}

class _StatTileData {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatTileData({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
}

class _StatTile extends StatelessWidget {
  final _StatTileData tile;
  final ColorScheme colorScheme;

  const _StatTile({required this.tile, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tile.icon, color: tile.iconColor, size: 20),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tile.value,
            style: AppTypography.heading2(context).copyWith(
              color: tile.iconColor,
            ),
          ),
          Text(
            tile.label,
            style: AppTypography.caption(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
