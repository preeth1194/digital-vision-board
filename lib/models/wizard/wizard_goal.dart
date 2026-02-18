import '../habit_item.dart';
import '../task_and_checklist_models.dart';
import '../goal_metadata.dart';

final class WizardGoalDraft {
  final String id;
  final String coreValueId;
  final String name;
  final String category;
  final String whyImportant;
  /// ISO-8601 date string (yyyy-mm-dd) in local time.
  final String? deadline;

  final bool wantsActionPlan;
  final List<HabitItem> habits;
  final List<TaskItem> tasks;
  final List<GoalTodoItem> todoItems;

  const WizardGoalDraft({
    required this.id,
    required this.coreValueId,
    required this.name,
    required this.category,
    required this.whyImportant,
    required this.deadline,
    required this.wantsActionPlan,
    this.habits = const [],
    this.tasks = const [],
    this.todoItems = const [],
  });

  WizardGoalDraft copyWith({
    String? id,
    String? coreValueId,
    String? name,
    String? category,
    String? whyImportant,
    String? deadline,
    bool? wantsActionPlan,
    List<HabitItem>? habits,
    List<TaskItem>? tasks,
    List<GoalTodoItem>? todoItems,
  }) {
    return WizardGoalDraft(
      id: id ?? this.id,
      coreValueId: coreValueId ?? this.coreValueId,
      name: name ?? this.name,
      category: category ?? this.category,
      whyImportant: whyImportant ?? this.whyImportant,
      deadline: deadline ?? this.deadline,
      wantsActionPlan: wantsActionPlan ?? this.wantsActionPlan,
      habits: habits ?? this.habits,
      tasks: tasks ?? this.tasks,
      todoItems: todoItems ?? this.todoItems,
    );
  }
}

