import 'package:flutter/material.dart';

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
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${completionRate.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            Text(
              '$completedToday of $totalHabits habits completed',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: totalHabits > 0 ? completedToday / totalHabits : 0,
              backgroundColor: Colors.white.withOpacity(0.3),
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

