import 'package:flutter/material.dart';

import '../../models/habit_item.dart';

enum OffScheduleCompletionChoice { cancel, oneTime, changeSchedule }

Future<OffScheduleCompletionChoice> showOffScheduleCompletionDialog({
  required BuildContext context,
  required HabitItem habit,
}) async {
  final scheduledDays = habit.hasWeeklySchedule
      ? habit.weeklyDays
          .map(
            (d) => const {
              DateTime.monday: 'Mon',
              DateTime.tuesday: 'Tue',
              DateTime.wednesday: 'Wed',
              DateTime.thursday: 'Thu',
              DateTime.friday: 'Fri',
              DateTime.saturday: 'Sat',
              DateTime.sunday: 'Sun',
            }[d],
          )
          .whereType<String>()
          .join(', ')
      : '';

  final message = scheduledDays.isEmpty
      ? 'This habit is not scheduled for today. Do you want to complete it one time, or update its schedule?'
      : 'This habit is scheduled on $scheduledDays. Do you want to complete it one time for today, or update its schedule?';

  final choice = await showDialog<OffScheduleCompletionChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Off-schedule habit'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(OffScheduleCompletionChoice.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(OffScheduleCompletionChoice.changeSchedule),
          child: const Text('Change schedule'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(OffScheduleCompletionChoice.oneTime),
          child: const Text('One-time completion'),
        ),
      ],
    ),
  );

  return choice ?? OffScheduleCompletionChoice.cancel;
}
