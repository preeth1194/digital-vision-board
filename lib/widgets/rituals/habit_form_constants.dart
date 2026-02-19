import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

// ============================================================================
// Data Models & Constants
// ============================================================================

const List<String> kHabitCategories = [
  'Health',
  'Fitness',
  'Productivity',
  'Mindfulness',
  'Learning',
  'Relationships',
  'Finance',
  'Creativity',
  'Other',
];

/// Common daily routines used as default options in the habit-stacking picker.
const List<String> kDefaultStackingHabits = [
  'Brush teeth',
  'Morning coffee',
  'Shower',
  'Breakfast',
  'Lunch',
  'Dinner',
  'Wake up',
  'Go to bed',
  'Morning walk',
  'Evening walk',
  'Commute to work',
  'Commute home',
  'Workout',
  'Meditation',
  'Journaling',
  'Reading',
];

/// Curated habit icons by category. Each category maps to thematically relevant icons only.
/// Fitness: sports/workout only (no Nature, Goal, Sunlight). Categories may have 10+ icons.
const List<(IconData, String)> habitIcons = [
  // Fitness (0-8): sports and workout only
  (Icons.fitness_center, 'Workout'),
  (Icons.directions_bike, 'Cycling'),
  (Icons.directions_run, 'Running'),
  (Icons.directions_walk, 'Walking'),
  (Icons.sports_gymnastics, 'Stretch'),
  (Icons.sports_basketball, 'Basketball'),
  (Icons.sports_soccer, 'Soccer'),
  (Icons.sports_tennis, 'Tennis'),
  (Icons.pool, 'Swimming'),
  // Health (9-15): medical, nutrition, sleep, wellness
  (Icons.water_drop, 'Water'),
  (Icons.restaurant, 'Food'),
  (Icons.bedtime, 'Sleep'),
  (Icons.favorite, 'Heart'),
  (Icons.local_hospital, 'Medical'),
  (Icons.psychology, 'Mental'),
  (Icons.spa, 'Spa'),
  // Productivity (16-23): tasks, time, focus, work
  (Icons.menu_book, 'Read'),
  (Icons.coffee, 'Morning'),
  (Icons.schedule, 'Schedule'),
  (Icons.check_circle, 'Task'),
  (Icons.work, 'Work'),
  (Icons.bolt, 'Focus'),
  (Icons.track_changes, 'Goal'),
  (Icons.alarm, 'Alarm'),
  // Mindfulness + Learning + Relationships + Finance + Creativity (24-48)
  (Icons.self_improvement, 'Meditation'),
  (Icons.mood, 'Calm'),
  (Icons.eco, 'Nature'),
  (Icons.school, 'Study'),
  (Icons.lightbulb, 'Idea'),
  (Icons.code, 'Code'),
  (Icons.auto_stories, 'Books'),
  (Icons.calculate, 'Math'),
  (Icons.people, 'People'),
  (Icons.favorite_border, 'Love'),
  (Icons.handshake, 'Connect'),
  (Icons.group, 'Group'),
  (Icons.attach_money, 'Money'),
  (Icons.savings, 'Savings'),
  (Icons.account_balance_wallet, 'Wallet'),
  (Icons.account_balance, 'Bank'),
  (Icons.trending_up, 'Growth'),
  (Icons.paid, 'Paid'),
  (Icons.credit_card, 'Card'),
  (Icons.brush, 'Brush'),
  (Icons.palette, 'Palette'),
  (Icons.design_services, 'Design'),
  (Icons.music_note, 'Music'),
  (Icons.photo_camera, 'Photo'),
  (Icons.create, 'Create'),
];

/// Maps each category to global icon indices from habitIcons.
/// Only thematically relevant icons per category. Fitness: sports/workout only (no Nature, Goal, Sunlight).
const Map<String, List<int>> categoryToIconIndices = {
  'Fitness': [0, 1, 2, 3, 4, 5, 6, 7, 8], // Workout, Cycling, Running, Walking, Stretch, Basketball, Soccer, Tennis, Swimming
  'Health': [9, 10, 11, 12, 13, 14, 15], // Water, Food, Sleep, Heart, Medical, Mental, Spa
  'Productivity': [16, 17, 18, 19, 20, 21, 22, 23], // Read, Morning, Schedule, Task, Work, Focus, Goal, Alarm
  'Mindfulness': [24, 15, 14, 11, 25, 26], // Meditation, Spa, Mental, Sleep, Calm, Nature
  'Learning': [16, 27, 14, 28, 29, 30, 31], // Read, Study, Mental, Idea, Code, Books, Math
  'Relationships': [32, 12, 33, 34, 35, 25], // People, Heart, Love, Connect, Group, Calm
  'Finance': [36, 37, 38, 39, 40, 41, 42], // Money, Savings, Wallet, Bank, Growth, Paid, Card
  'Creativity': [43, 44, 45, 46, 47, 48], // Brush, Palette, Design, Music, Photo, Create
  'Other': [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
    40, 41, 42, 43, 44, 45, 46, 47, 48,
  ],
};

List<Color> hueSpectrumColors = [
  AppColors.hueRed,
  AppColors.hueYellow,
  AppColors.hueGreen,
  AppColors.hueCyan,
  AppColors.hueBlue,
  AppColors.hueMagenta,
  AppColors.hueRed,
];

final List<(String, List<Color>)> habitColors = [
  ('Red', [AppColors.habitRedLight, AppColors.habitRedDark]),
  ('Orange', [AppColors.habitOrangeLight, AppColors.habitOrangeDark]),
  ('Yellow', [AppColors.habitYellowLight, AppColors.habitYellowDark]),
  ('Green', [AppColors.habitGreenLight, AppColors.habitGreenDark]),
  ('Blue', [AppColors.habitBlueLight, AppColors.habitBlueDark]),
  ('Indigo', [AppColors.habitIndigoLight, AppColors.habitIndigoDark]),
  ('Violet', [AppColors.habitVioletLight, AppColors.habitVioletDark]),
];

const double kControlSpacing = 20.0;
const double kSectionSpacing = 10.0;

/// Alert dropdown options: minutes before start time (5 mins to 1 hour)
const List<int> kReminderMinutesBeforeOptions = [5, 10, 15, 20, 25, 30, 45, 60];

/// Built-in notification sound presets: (id, display label, icon).
const List<(String, String, IconData)> kNotificationSoundOptions = [
  ('default', 'Default', Icons.notifications_active_outlined),
  ('chime', 'Chime', Icons.music_note_outlined),
  ('bell', 'Bell', Icons.notifications_outlined),
  ('gentle', 'Gentle', Icons.waves_outlined),
  ('alert', 'Alert', Icons.warning_amber_outlined),
  ('none', 'None', Icons.notifications_off_outlined),
];

/// Vibration type options: (id, display label).
const List<(String, String)> kVibrateTypeOptions = [
  ('none', 'None'),
  ('default', 'Default'),
  ('short', 'Short'),
  ('long', 'Long'),
];

/// Returns the display label for a notification sound id.
/// Falls back to 'Custom' for file-path values.
String notificationSoundLabel(String? id) {
  if (id == null) return 'Default';
  for (final opt in kNotificationSoundOptions) {
    if (opt.$1 == id) return opt.$2;
  }
  return 'Custom';
}

/// Returns the display label for a vibration type id.
String vibrateTypeLabel(String? id) {
  if (id == null) return 'Default';
  for (final opt in kVibrateTypeOptions) {
    if (opt.$1 == id) return opt.$2;
  }
  return 'Default';
}

/// Milestone preset for the Commitment Goal section.
class MilestonePreset {
  final String id;
  final int? days; // null means "no end date"
  final String label;
  final String subtitle;
  final bool isRecommended;

  const MilestonePreset({
    required this.id,
    required this.days,
    required this.label,
    required this.subtitle,
    this.isRecommended = false,
  });
}

const List<MilestonePreset> kMilestonePresets = [
  MilestonePreset(id: '21', days: 21, label: '21 Days', subtitle: 'Kickstart'),
  MilestonePreset(id: '66', days: 66, label: '66 Days', subtitle: 'Autopilot', isRecommended: true),
  MilestonePreset(id: '90', days: 90, label: '90 Days', subtitle: 'Lifestyle'),
  MilestonePreset(id: 'none', days: null, label: '\u221E', subtitle: 'No End Date'),
];

/// Theme-aware styling for CupertinoListSection.insetGrouped
BoxDecoration habitSectionDecoration(ColorScheme colorScheme) => BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    );

Color habitSectionSeparatorColor(ColorScheme colorScheme) =>
    colorScheme.outlineVariant.withValues(alpha: 0.5);

Color contrastColor(Color background) {
  return background.computeLuminance() > 0.5
      ? AppColors.darkest
      : Colors.white;
}
