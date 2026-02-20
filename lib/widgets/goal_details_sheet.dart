import 'package:flutter/material.dart';

import '../models/goal_metadata.dart';
import '../utils/app_typography.dart';

Future<void> showGoalDetailsSheet(
  BuildContext context, {
  required GoalMetadata goal,
  ValueChanged<GoalMetadata>? onEdit,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(child: _GoalDetailsSheet(goal: goal, onEdit: onEdit)),
  );
}

class _GoalDetailsSheet extends StatelessWidget {
  final GoalMetadata goal;
  final ValueChanged<GoalMetadata>? onEdit;
  const _GoalDetailsSheet({required this.goal, required this.onEdit});

  Widget _kv(BuildContext context, String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.heading3(context)),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.body(context)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cbt = goal.cbt;
    final plan = goal.actionPlan;
    final weeklyDaysStr = (plan != null && (plan.weeklyDays).isNotEmpty)
        ? plan.weeklyDays
            .map((d) => const {
                  DateTime.monday: 'Mon',
                  DateTime.tuesday: 'Tue',
                  DateTime.wednesday: 'Wed',
                  DateTime.thursday: 'Thu',
                  DateTime.friday: 'Fri',
                  DateTime.saturday: 'Sat',
                  DateTime.sunday: 'Sun',
                }[d])
            .whereType<String>()
            .join(', ')
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title ?? 'Goal details',
                  style: AppTypography.heading2(context),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit goal details',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    Navigator.of(context).pop(); // close details sheet first
                    onEdit?.call(goal);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          _kv(context, 'Category', goal.category),
          _kv(context, 'Deadline', goal.deadline),
          if (cbt != null) ...[
            const Divider(),
            Text('Mindset & coping', style: AppTypography.heading3(context)),
            const SizedBox(height: 10),
            _kv(context, 'Core value', cbt.coreValue),
            _kv(context, 'Visualization', cbt.visualization),
            _kv(context, 'Limiting belief', cbt.limitingBelief),
            _kv(context, 'Reframed truth', cbt.reframedTruth),
            if (cbt.obstacles.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Obstacles', style: AppTypography.heading3(context)),
              const SizedBox(height: 8),
              ...cbt.obstacles.map(
                (o) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.trigger, style: AppTypography.heading3(context)),
                        const SizedBox(height: 6),
                        Text(o.copingStrategy, style: AppTypography.body(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (plan != null) ...[
            const Divider(),
            Text('Action plan', style: AppTypography.heading3(context)),
            const SizedBox(height: 10),
            _kv(context, 'Micro habit', plan.microHabit),
            _kv(context, 'Frequency', plan.frequency),
            if ((weeklyDaysStr ?? '').trim().isNotEmpty) _kv(context, 'Weekly days', weeklyDaysStr),
          ],
        ],
      ),
    );
  }
}

