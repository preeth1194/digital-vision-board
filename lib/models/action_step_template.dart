import 'habit_action_step.dart';

enum ActionTemplateCategory { skincare, workout, mealPrep, recipe }

enum ActionTemplateStatus { draft, submitted, approved, rejected }

class ActionStepTemplate {
  final String id;
  final String name;
  final ActionTemplateCategory category;
  final int schemaVersion;
  final int templateVersion;
  final String? setKey;
  final bool isOfficial;
  final ActionTemplateStatus status;
  final String? createdByUserId;
  final List<HabitActionStep> steps;
  final Map<String, dynamic> metadata;

  const ActionStepTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.schemaVersion,
    required this.templateVersion,
    required this.setKey,
    required this.isOfficial,
    required this.status,
    required this.createdByUserId,
    required this.steps,
    this.metadata = const {},
  });

  factory ActionStepTemplate.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final stepsList = (rawSteps is List)
        ? rawSteps.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    return ActionStepTemplate(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Untitled template',
      category: _categoryFromString((json['category'] as String?) ?? ''),
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      templateVersion: (json['templateVersion'] as num?)?.toInt() ?? 1,
      setKey: json['setKey'] as String?,
      isOfficial: (json['isOfficial'] as bool?) ?? false,
      status: _statusFromString((json['status'] as String?) ?? ''),
      createdByUserId: json['createdByUserId'] as String?,
      steps: stepsList.map(HabitActionStep.fromJson).toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
      metadata: (json['metadata'] is Map<String, dynamic>)
          ? (json['metadata'] as Map<String, dynamic>)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': _categoryToString(category),
    'schemaVersion': schemaVersion,
    'templateVersion': templateVersion,
    'setKey': setKey,
    'isOfficial': isOfficial,
    'status': _statusToString(status),
    'createdByUserId': createdByUserId,
    'steps': steps.map((s) => s.toJson()).toList(),
    'metadata': metadata,
  };

  static ActionTemplateCategory _categoryFromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'skincare':
        return ActionTemplateCategory.skincare;
      case 'workout':
        return ActionTemplateCategory.workout;
      case 'meal_prep':
        return ActionTemplateCategory.mealPrep;
      case 'recipe':
        return ActionTemplateCategory.recipe;
      default:
        return ActionTemplateCategory.skincare;
    }
  }

  static String _categoryToString(ActionTemplateCategory category) {
    switch (category) {
      case ActionTemplateCategory.skincare:
        return 'skincare';
      case ActionTemplateCategory.workout:
        return 'workout';
      case ActionTemplateCategory.mealPrep:
        return 'meal_prep';
      case ActionTemplateCategory.recipe:
        return 'recipe';
    }
  }

  static ActionTemplateStatus _statusFromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'draft':
        return ActionTemplateStatus.draft;
      case 'submitted':
        return ActionTemplateStatus.submitted;
      case 'approved':
        return ActionTemplateStatus.approved;
      case 'rejected':
        return ActionTemplateStatus.rejected;
      default:
        return ActionTemplateStatus.approved;
    }
  }

  static String _statusToString(ActionTemplateStatus status) {
    switch (status) {
      case ActionTemplateStatus.draft:
        return 'draft';
      case ActionTemplateStatus.submitted:
        return 'submitted';
      case ActionTemplateStatus.approved:
        return 'approved';
      case ActionTemplateStatus.rejected:
        return 'rejected';
    }
  }
}
