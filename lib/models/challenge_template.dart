import 'package:flutter/foundation.dart';

import 'habit_item.dart';

/// Blueprint for a single habit within a challenge template.
/// Users can customize editable fields before the challenge starts.
@immutable
class HabitBlueprint {
  final String defaultName;
  final String category;
  final int iconIndex;
  final String frequency;

  /// Pre-configured timer (null if not applicable).
  final HabitTimeBoundSpec? timeBound;

  /// Pre-configured measurement tracker (null if not applicable).
  final HabitTrackingSpec? trackingSpec;

  /// Suggested start time in minutes since midnight (null = user picks).
  final int? suggestedStartTimeMinutes;

  /// Short description shown in the setup screen.
  final String description;

  const HabitBlueprint({
    required this.defaultName,
    required this.category,
    required this.iconIndex,
    this.frequency = 'Daily',
    this.timeBound,
    this.trackingSpec,
    this.suggestedStartTimeMinutes,
    this.description = '',
  });
}

/// Defines a challenge type (e.g. 75 Hard) with its rules and habit blueprints.
@immutable
class ChallengeTemplate {
  final String id;
  final String name;
  final String subtitle;
  final int durationDays;
  final String description;

  /// The habit blueprints that make up this challenge.
  final List<HabitBlueprint> habits;

  /// Rules displayed to the user before starting.
  final List<String> rules;

  const ChallengeTemplate({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.durationDays,
    required this.description,
    required this.habits,
    this.rules = const [],
  });
}

/// Registry of all available challenge templates.
class ChallengeTemplates {
  ChallengeTemplates._();

  static const ChallengeTemplate seventyFiveHard = ChallengeTemplate(
    id: '75_hard',
    name: '75 Hard',
    subtitle: 'Mental Toughness Challenge',
    durationDays: 75,
    description:
        'A 75-day mental toughness program. Complete all 6 tasks every single day for 75 consecutive days. '
        'If you miss any task on any day, you restart from Day 1.',
    rules: [
      'Complete ALL tasks every single day',
      'No cheat meals, no alcohol',
      'Two 45-minute workouts (one must be outdoors)',
      'Drink 1 gallon (128 oz) of water',
      'Read 10 pages of a non-fiction book',
      'Take a daily progress photo',
      'Miss a task? Restart from Day 1',
    ],
    habits: [
      HabitBlueprint(
        defaultName: 'Follow Diet',
        category: 'Health',
        iconIndex: 10, // Food icon
        description: 'Follow your chosen diet — no cheat meals, no alcohol.',
        suggestedStartTimeMinutes: 7 * 60, // 7:00 AM
      ),
      HabitBlueprint(
        defaultName: 'Outdoor Workout',
        category: 'Fitness',
        iconIndex: 2, // Running icon
        description: '45-minute workout — must be outdoors.',
        suggestedStartTimeMinutes: 6 * 60, // 6:00 AM
        timeBound: HabitTimeBoundSpec(
          enabled: true,
          duration: 45,
          unit: 'minutes',
        ),
      ),
      HabitBlueprint(
        defaultName: 'Second Workout',
        category: 'Fitness',
        iconIndex: 0, // Workout icon
        description: '45-minute workout — can be indoors or outdoors.',
        suggestedStartTimeMinutes: 17 * 60, // 5:00 PM
        timeBound: HabitTimeBoundSpec(
          enabled: true,
          duration: 45,
          unit: 'minutes',
        ),
      ),
      HabitBlueprint(
        defaultName: 'Drink 1 Gallon Water',
        category: 'Health',
        iconIndex: 9, // Water icon
        description: 'Drink at least 1 gallon (128 oz) of water throughout the day.',
        trackingSpec: HabitTrackingSpec(
          enabled: true,
          unitId: 'oz',
          unitLabel: 'oz',
        ),
      ),
      HabitBlueprint(
        defaultName: 'Read 10 Pages',
        category: 'Learning',
        iconIndex: 16, // Read icon
        description: 'Read at least 10 pages of a non-fiction / self-improvement book.',
        suggestedStartTimeMinutes: 21 * 60, // 9:00 PM
      ),
      HabitBlueprint(
        defaultName: 'Progress Photo',
        category: 'Health',
        iconIndex: 47, // Photo icon
        description: 'Take a progress photo to track your physical transformation.',
        suggestedStartTimeMinutes: 8 * 60, // 8:00 AM
      ),
    ],
  );

  static const List<ChallengeTemplate> all = [
    seventyFiveHard,
  ];

  static ChallengeTemplate? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}
