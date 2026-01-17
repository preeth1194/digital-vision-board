import '../models/habit_item.dart';
import '../models/task_item.dart';

final class ChecklistToggleResult {
  final TaskItem updatedTask;
  final ChecklistItem updatedItem;
  final String isoDate;
  final bool wasItemCompleted;
  final bool isItemCompleted;
  final bool wasTaskComplete;
  final bool isTaskComplete;

  const ChecklistToggleResult({
    required this.updatedTask,
    required this.updatedItem,
    required this.isoDate,
    required this.wasItemCompleted,
    required this.isItemCompleted,
    required this.wasTaskComplete,
    required this.isTaskComplete,
  });
}

final class CompletionMutations {
  CompletionMutations._();

  static String toIsoDate(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    final yyyy = dd.year.toString().padLeft(4, '0');
    final mm = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$day';
  }

  /// Returns true if the habit is allowed to be checked today (scheduled weekly habits only).
  static bool canToggleHabitToday(HabitItem habit, DateTime now) {
    if (!habit.hasWeeklySchedule) return true;
    return habit.isScheduledOnDate(now);
  }

  static bool isTaskFullyComplete(TaskItem t) {
    if (t.checklist.isEmpty) return false;
    return t.checklist.every((c) => c.isCompleted);
  }

  static ChecklistToggleResult toggleChecklistItemForToday(
    TaskItem task,
    ChecklistItem item, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final iso = toIsoDate(current);

    final wasItemDone = item.isCompleted;
    final wasTaskDone = isTaskFullyComplete(task);

    final nextChecklist = task.checklist.map((c) {
      if (c.id != item.id) return c;
      final nextCompletedOn = wasItemDone ? null : iso;
      // If unchecking today, drop today's feedback entry (if any).
      final nextFeedback = Map<String, CompletionFeedback>.from(c.feedbackByDate);
      if (wasItemDone) nextFeedback.remove(iso);
      return c.copyWith(completedOn: nextCompletedOn, feedbackByDate: nextFeedback);
    }).toList();

    var nextTaskFeedback = Map<String, CompletionFeedback>.from(task.completionFeedbackByDate);
    final nextTask = task.copyWith(checklist: nextChecklist);
    final isTaskDone = isTaskFullyComplete(nextTask);

    // If task becomes incomplete today, drop today's task-level feedback.
    if (wasTaskDone && !isTaskDone) {
      nextTaskFeedback.remove(iso);
    }

    final nextTaskWithFeedback = nextTask.copyWith(completionFeedbackByDate: nextTaskFeedback);
    final updatedItem = nextTaskWithFeedback.checklist.firstWhere((c) => c.id == item.id);

    return ChecklistToggleResult(
      updatedTask: nextTaskWithFeedback,
      updatedItem: updatedItem,
      isoDate: iso,
      wasItemCompleted: wasItemDone,
      isItemCompleted: !wasItemDone,
      wasTaskComplete: wasTaskDone,
      isTaskComplete: isTaskDone,
    );
  }

  static TaskItem applyChecklistItemFeedback(
    TaskItem task, {
    required String itemId,
    required String isoDate,
    required CompletionFeedback feedback,
  }) {
    final nextChecklist = task.checklist.map((c) {
      if (c.id != itemId) return c;
      final next = Map<String, CompletionFeedback>.from(c.feedbackByDate);
      next[isoDate] = feedback;
      return c.copyWith(feedbackByDate: next);
    }).toList();
    return task.copyWith(checklist: nextChecklist);
  }

  static TaskItem applyTaskCompletionFeedback(
    TaskItem task, {
    required String isoDate,
    required CompletionFeedback feedback,
  }) {
    final next = Map<String, CompletionFeedback>.from(task.completionFeedbackByDate);
    next[isoDate] = feedback;
    return task.copyWith(completionFeedbackByDate: next);
  }
}

