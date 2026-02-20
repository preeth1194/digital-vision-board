import 'package:flutter/material.dart';

import '../../utils/app_typography.dart';

class TodayProgressCard extends StatelessWidget {
  final double completionRate;
  final int completedToday;
  final int totalHabits;

  const TodayProgressCard({
    super.key,
    required this.completionRate,
    required this.completedToday,
    required this.totalHabits,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Today\'s Progress',
              style: AppTypography.body(context).copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${completionRate.toStringAsFixed(0)}%',
              style: AppTypography.heading1(context).copyWith(
                fontSize: 48,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              '$completedToday of $totalHabits habits completed',
              style: AppTypography.bodySmall(context).copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: totalHabits > 0 ? completedToday / totalHabits : 0,
              backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

