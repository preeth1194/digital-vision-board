import 'cbt_enhancements.dart';

/// A task with checklist items, used inside the tracker.
///
/// Stored inside a VisionComponent so tasks are scoped per goal/zone.

final class ChecklistItem {
  final String id;
  final String text;
  /// Optional due date (YYYY-MM-DD).
  final String? dueDate;
  /// Completion date (YYYY-MM-DD) when checked off.
  final String? completedOn;
  /// Optional CBT enhancements for this checklist item.
  final CbtEnhancements? cbtEnhancements;

  const ChecklistItem({
    required this.id,
    required this.text,
    this.dueDate,
    this.completedOn,
    this.cbtEnhancements,
  });

  bool get isCompleted => (completedOn ?? '').trim().isNotEmpty;

  ChecklistItem copyWith({
    String? id,
    String? text,
    String? dueDate,
    String? completedOn,
    CbtEnhancements? cbtEnhancements,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      dueDate: dueDate ?? this.dueDate,
      completedOn: completedOn ?? this.completedOn,
      cbtEnhancements: cbtEnhancements ?? this.cbtEnhancements,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'dueDate': dueDate,
        'completedOn': completedOn,
        'cbtEnhancements': cbtEnhancements?.toJson(),
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        dueDate: json['dueDate'] as String?,
        completedOn: json['completedOn'] as String?,
        cbtEnhancements: (json['cbtEnhancements'] is Map<String, dynamic>)
            ? CbtEnhancements.fromJson(json['cbtEnhancements'] as Map<String, dynamic>)
            : (json['cbt_enhancements'] is Map<String, dynamic>)
                ? CbtEnhancements.fromJson(json['cbt_enhancements'] as Map<String, dynamic>)
                : null,
      );
}

final class TaskItem {
  final String id;
  final String title;
  final List<ChecklistItem> checklist;
  /// Optional CBT enhancements for this task.
  final CbtEnhancements? cbtEnhancements;

  const TaskItem({
    required this.id,
    required this.title,
    this.checklist = const [],
    this.cbtEnhancements,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    List<ChecklistItem>? checklist,
    CbtEnhancements? cbtEnhancements,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      checklist: checklist ?? this.checklist,
      cbtEnhancements: cbtEnhancements ?? this.cbtEnhancements,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'cbtEnhancements': cbtEnhancements?.toJson(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        checklist: (json['checklist'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ChecklistItem.fromJson)
            .toList(),
        cbtEnhancements: (json['cbtEnhancements'] is Map<String, dynamic>)
            ? CbtEnhancements.fromJson(json['cbtEnhancements'] as Map<String, dynamic>)
            : (json['cbt_enhancements'] is Map<String, dynamic>)
                ? CbtEnhancements.fromJson(json['cbt_enhancements'] as Map<String, dynamic>)
                : null,
      );
}

