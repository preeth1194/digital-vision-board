/// CBT + action-plan metadata attached to a goal layer.
///
/// This is intentionally lightweight and nullable everywhere so older boards
/// (and users who skip filling this in) keep working.
final class GoalObstacle {
  final String trigger;
  final String copingStrategy;

  const GoalObstacle({required this.trigger, required this.copingStrategy});

  Map<String, dynamic> toJson() => {
        'trigger': trigger,
        'coping_strategy': copingStrategy,
      };

  factory GoalObstacle.fromJson(Map<String, dynamic> json) => GoalObstacle(
        trigger: (json['trigger'] as String?) ?? '',
        copingStrategy: (json['coping_strategy'] as String?) ?? '',
      );
}

final class GoalCbtMetadata {
  final String? coreValue;
  final String? visualization;
  final String? limitingBelief;
  final String? reframedTruth;
  final List<GoalObstacle> obstacles;

  const GoalCbtMetadata({
    this.coreValue,
    this.visualization,
    this.limitingBelief,
    this.reframedTruth,
    this.obstacles = const [],
  });

  Map<String, dynamic> toJson() => {
        'core_value': coreValue,
        'visualization': visualization,
        'limiting_belief': limitingBelief,
        'reframed_truth': reframedTruth,
        'obstacles': obstacles.map((o) => o.toJson()).toList(),
      };

  factory GoalCbtMetadata.fromJson(Map<String, dynamic> json) => GoalCbtMetadata(
        coreValue: json['core_value'] as String?,
        visualization: json['visualization'] as String?,
        limitingBelief: json['limiting_belief'] as String?,
        reframedTruth: json['reframed_truth'] as String?,
        obstacles: (json['obstacles'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GoalObstacle.fromJson)
            .toList(),
      );
}

final class GoalActionPlan {
  final String? microHabit;
  final String? frequency;
  /// When frequency is weekly, user can optionally pick the weekdays (1=Mon..7=Sun).
  final List<int> weeklyDays;

  const GoalActionPlan({
    this.microHabit,
    this.frequency,
    this.weeklyDays = const [],
  });

  Map<String, dynamic> toJson() => {
        'micro_habit': microHabit,
        'frequency': frequency,
        'weekly_days': weeklyDays,
      };

  factory GoalActionPlan.fromJson(Map<String, dynamic> json) => GoalActionPlan(
        microHabit: json['micro_habit'] as String?,
        frequency: _normalizeFrequency(
          json['frequency'] as String?,
          (json['weekly_days'] as List<dynamic>? ?? const [])
              .whereType<num>()
              .map((n) => n.toInt())
              .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
              .toList(),
        ),
        weeklyDays: _normalizeWeeklyDays(
          json['frequency'] as String?,
          (json['weekly_days'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((n) => n.toInt())
            .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
            .toList(),
        ),
      );

  static String? _normalizeFrequency(String? raw, List<int> weeklyDays) {
    final f = (raw ?? '').trim();
    if (f.isEmpty) return null;
    final lower = f.toLowerCase();
    if (lower == 'weekly' && weeklyDays.toSet().length >= 7) return 'Daily';
    if (lower == 'daily') return 'Daily';
    if (lower == 'weekly') return 'Weekly';
    return f;
  }

  static List<int> _normalizeWeeklyDays(String? rawFrequency, List<int> weeklyDays) {
    final f = (rawFrequency ?? '').trim().toLowerCase();
    final unique = weeklyDays.toSet();
    if (f == 'weekly' && unique.length >= 7) return const <int>[];
    return weeklyDays;
  }
}

/// A lightweight per-goal todo item that can optionally link to a Habit and/or Task.
///
/// Stored inside `GoalMetadata` so it persists with the goal itself.
final class GoalTodoItem {
  final String id;
  final String text;
  final bool isCompleted;
  final int? completedAtMs;
  final String? habitId;
  final String? taskId;

  const GoalTodoItem({
    required this.id,
    required this.text,
    required this.isCompleted,
    required this.completedAtMs,
    required this.habitId,
    required this.taskId,
  });

  static const Object _unset = Object();

  GoalTodoItem copyWith({
    String? id,
    String? text,
    bool? isCompleted,
    Object? completedAtMs = _unset,
    Object? habitId = _unset,
    Object? taskId = _unset,
  }) {
    return GoalTodoItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAtMs: identical(completedAtMs, _unset) ? this.completedAtMs : completedAtMs as int?,
      habitId: identical(habitId, _unset) ? this.habitId : habitId as String?,
      taskId: identical(taskId, _unset) ? this.taskId : taskId as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'is_completed': isCompleted,
        'completed_at_ms': completedAtMs,
        'habit_id': habitId,
        'task_id': taskId,
      };

  factory GoalTodoItem.fromJson(Map<String, dynamic> json) => GoalTodoItem(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        isCompleted: (json['is_completed'] as bool?) ?? (json['isCompleted'] as bool?) ?? false,
        completedAtMs: (json['completed_at_ms'] as num?)?.toInt() ?? (json['completedAtMs'] as num?)?.toInt(),
        habitId: json['habit_id'] as String? ?? json['habitId'] as String?,
        taskId: json['task_id'] as String? ?? json['taskId'] as String?,
      );
}

final class GoalMetadata {
  final String? title;
  /// ISO-8601 date string (yyyy-mm-dd) in local time.
  final String? deadline;
  final String? category;
  final GoalCbtMetadata? cbt;
  final GoalActionPlan? actionPlan;
  final List<GoalTodoItem> todoItems;

  const GoalMetadata({
    this.title,
    this.deadline,
    this.category,
    this.cbt,
    this.actionPlan,
    this.todoItems = const [],
  });

  static const Object _unset = Object();

  GoalMetadata copyWith({
    Object? title = _unset,
    Object? deadline = _unset,
    Object? category = _unset,
    Object? cbt = _unset,
    Object? actionPlan = _unset,
    List<GoalTodoItem>? todoItems,
  }) {
    return GoalMetadata(
      title: identical(title, _unset) ? this.title : title as String?,
      deadline: identical(deadline, _unset) ? this.deadline : deadline as String?,
      category: identical(category, _unset) ? this.category : category as String?,
      cbt: identical(cbt, _unset) ? this.cbt : cbt as GoalCbtMetadata?,
      actionPlan: identical(actionPlan, _unset) ? this.actionPlan : actionPlan as GoalActionPlan?,
      todoItems: todoItems ?? this.todoItems,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'deadline': deadline,
        'category': category,
        'cbt_metadata': cbt?.toJson(),
        'action_plan': actionPlan?.toJson(),
        'todo_items': todoItems.map((t) => t.toJson()).toList(),
      };

  factory GoalMetadata.fromJson(Map<String, dynamic> json) => GoalMetadata(
        title: json['title'] as String?,
        deadline: json['deadline'] as String?,
        category: json['category'] as String?,
        cbt: (json['cbt_metadata'] is Map<String, dynamic>)
            ? GoalCbtMetadata.fromJson(json['cbt_metadata'] as Map<String, dynamic>)
            : null,
        actionPlan: (json['action_plan'] is Map<String, dynamic>)
            ? GoalActionPlan.fromJson(json['action_plan'] as Map<String, dynamic>)
            : null,
        todoItems: (json['todo_items'] as List<dynamic>? ?? json['todoItems'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GoalTodoItem.fromJson)
            .toList(),
      );
}

