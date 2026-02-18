import 'cbt_enhancements.dart';

/// A task with checklist items, used inside the tracker.
///
/// Stored inside a VisionComponent so tasks are scoped per goal/zone.

final class CompletionFeedback {
  final int rating; // 1..5
  final String? note;

  const CompletionFeedback({required this.rating, required this.note});

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'note': note,
      };

  factory CompletionFeedback.fromJson(Map<String, dynamic> json) => CompletionFeedback(
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        note: json['note'] as String?,
      );
}

final class ChecklistItem {
  final String id;
  final String text;
  /// Optional due date (YYYY-MM-DD).
  final String? dueDate;
  /// Completion date (YYYY-MM-DD) when checked off.
  final String? completedOn;
  /// Optional CBT enhancements for this checklist item.
  final CbtEnhancements? cbtEnhancements;
  /// Optional completion feedback keyed by ISO date (YYYY-MM-DD).
  final Map<String, CompletionFeedback> feedbackByDate;

  const ChecklistItem({
    required this.id,
    required this.text,
    this.dueDate,
    this.completedOn,
    this.cbtEnhancements,
    this.feedbackByDate = const {},
  });

  bool get isCompleted => (completedOn ?? '').trim().isNotEmpty;

  static const Object _unset = Object();

  /// Use `_unset` so callers can explicitly clear nullable fields by passing `null`.
  ChecklistItem copyWith({
    String? id,
    String? text,
    Object? dueDate = _unset,
    Object? completedOn = _unset,
    Object? cbtEnhancements = _unset,
    Map<String, CompletionFeedback>? feedbackByDate,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as String?,
      completedOn: identical(completedOn, _unset) ? this.completedOn : completedOn as String?,
      cbtEnhancements: identical(cbtEnhancements, _unset)
          ? this.cbtEnhancements
          : cbtEnhancements as CbtEnhancements?,
      feedbackByDate: feedbackByDate ?? this.feedbackByDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'dueDate': dueDate,
        'completedOn': completedOn,
        'cbtEnhancements': cbtEnhancements?.toJson(),
        'feedbackByDate': feedbackByDate.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    final feedbackRaw = (json['feedbackByDate'] as Map<String, dynamic>?) ??
        (json['feedback_by_date'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final fb = <String, CompletionFeedback>{};
    for (final entry in feedbackRaw.entries) {
      final v = entry.value;
      if (v is Map<String, dynamic>) {
        fb[entry.key] = CompletionFeedback.fromJson(v);
      }
    }

    return ChecklistItem(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      dueDate: json['dueDate'] as String?,
      completedOn: json['completedOn'] as String?,
      cbtEnhancements: (json['cbtEnhancements'] is Map<String, dynamic>)
          ? CbtEnhancements.fromJson(json['cbtEnhancements'] as Map<String, dynamic>)
          : (json['cbt_enhancements'] is Map<String, dynamic>)
              ? CbtEnhancements.fromJson(json['cbt_enhancements'] as Map<String, dynamic>)
              : null,
      feedbackByDate: fb,
    );
  }
}

final class TaskItem {
  final String id;
  final String title;
  final List<ChecklistItem> checklist;
  /// Optional CBT enhancements for this task.
  final CbtEnhancements? cbtEnhancements;
  /// Optional completion feedback keyed by ISO date (YYYY-MM-DD) for when the task becomes fully complete.
  final Map<String, CompletionFeedback> completionFeedbackByDate;

  const TaskItem({
    required this.id,
    required this.title,
    this.checklist = const [],
    this.cbtEnhancements,
    this.completionFeedbackByDate = const {},
  });

  TaskItem copyWith({
    String? id,
    String? title,
    List<ChecklistItem>? checklist,
    CbtEnhancements? cbtEnhancements,
    Map<String, CompletionFeedback>? completionFeedbackByDate,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      checklist: checklist ?? this.checklist,
      cbtEnhancements: cbtEnhancements ?? this.cbtEnhancements,
      completionFeedbackByDate: completionFeedbackByDate ?? this.completionFeedbackByDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'checklist': checklist.map((c) => c.toJson()).toList(),
        'cbtEnhancements': cbtEnhancements?.toJson(),
        'completionFeedbackByDate': completionFeedbackByDate.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final completionFeedbackRaw = (json['completionFeedbackByDate'] as Map<String, dynamic>?) ??
        (json['completion_feedback_by_date'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final completionFb = <String, CompletionFeedback>{};
    for (final entry in completionFeedbackRaw.entries) {
      final v = entry.value;
      if (v is Map<String, dynamic>) {
        completionFb[entry.key] = CompletionFeedback.fromJson(v);
      }
    }

    return TaskItem(
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
      completionFeedbackByDate: completionFb,
    );
  }
}

