import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/cbt_enhancements.dart';
import '../../models/habit_item.dart';
import '../../utils/app_typography.dart';

// ============================================================================
// Data Models & Constants
// ============================================================================

const List<String> _kHabitCategories = [
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
const List<String> _kDefaultStackingHabits = [
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
const List<(IconData, String)> _habitIcons = [
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

/// Maps each category to global icon indices from _habitIcons.
/// Only thematically relevant icons per category. Fitness: sports/workout only (no Nature, Goal, Sunlight).
const Map<String, List<int>> _categoryToIconIndices = {
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

const List<Color> _hueSpectrumColors = [
  Color(0xFFFF0000), // red
  Color(0xFFFFFF00), // yellow
  Color(0xFF00FF00), // green
  Color(0xFF00FFFF), // cyan
  Color(0xFF0000FF), // blue
  Color(0xFFFF00FF), // magenta
  Color(0xFFFF0000), // red
];

final List<(String, List<Color>)> _habitColors = [
  ('Red', [const Color(0xFFEF4444), const Color(0xFFB91C1C)]),
  ('Orange', [const Color(0xFFF97316), const Color(0xFFC2410C)]),
  ('Yellow', [const Color(0xFFEAB308), const Color(0xFFA16207)]),
  ('Green', [const Color(0xFF22C55E), const Color(0xFF15803D)]),
  ('Blue', [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]),
  ('Indigo', [const Color(0xFF6366F1), const Color(0xFF4338CA)]),
  ('Violet', [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]),
];

const double _kControlSpacing = 20.0;
const double _kSectionSpacing = 24.0;

/// Alert dropdown options: minutes before start time (5 mins to 1 hour)
const List<int> _kReminderMinutesBeforeOptions = [5, 10, 15, 20, 25, 30, 45, 60];

/// Theme-aware styling for CupertinoListSection.insetGrouped
BoxDecoration _sectionDecoration(ColorScheme colorScheme) => BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    );

Color _sectionSeparatorColor(ColorScheme colorScheme) =>
    colorScheme.outlineVariant.withValues(alpha: 0.5);

Color _contrastColor(Color background) {
  return background.computeLuminance() > 0.5
      ? const Color(0xFF1C1B1F)
      : Colors.white;
}

/// Shows an iOS-style time picker with scroll wheels (hours, minutes, AM/PM).
Future<TimeOfDay?> showCupertinoTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  final now = DateTime.now();
  DateTime selected = DateTime(
    now.year,
    now.month,
    now.day,
    initialTime.hour,
    initialTime.minute,
  );
  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(TimeOfDay.fromDateTime(selected)),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: isDark ? Brightness.dark : Brightness.light,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: selected,
                  use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                  minuteInterval: 1,
                  onDateTimeChanged: (v) => selected = v,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ============================================================================
// Main Entry Function
// ============================================================================

/// Shows the Add Habit modal with a slide-in animation from the right.
/// Returns a [HabitCreateRequest] if the user creates a habit, null otherwise.
/// This is the unified entry point for all habit add/edit flows.
Future<HabitCreateRequest?> showAddHabitModal(
  BuildContext context, {
  required List<HabitItem> existingHabits,
  HabitItem? initialHabit,
  String? initialName,
  String? suggestedGoalDeadline,
}) {
  return Navigator.of(context).push<HabitCreateRequest?>(
    PageRouteBuilder<HabitCreateRequest?>(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _CreateHabitPage(
          existingHabits: existingHabits,
          initialHabit: initialHabit,
          initialName: initialName,
          suggestedGoalDeadline: suggestedGoalDeadline,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

// ============================================================================
// Main Scrollable Page Widget
// ============================================================================

class _CreateHabitPage extends StatefulWidget {
  final List<HabitItem> existingHabits;
  final HabitItem? initialHabit;
  final String? initialName;
  final String? suggestedGoalDeadline;

  const _CreateHabitPage({
    required this.existingHabits,
    this.initialHabit,
    this.initialName,
    this.suggestedGoalDeadline,
  });

  @override
  State<_CreateHabitPage> createState() => _CreateHabitPageState();
}

class _CreateHabitPageState extends State<_CreateHabitPage>
    with TickerProviderStateMixin {
  // --- FORM DATA STATE ---

  // Identity
  final TextEditingController _habitNameController = TextEditingController();
  int _selectedIconIndex = 0;

  // Aesthetics
  int _selectedColorIndex = 0;
  final Map<int, (Color, Color)> _customizedPresets = {};
  bool _colorPickerExpanded = false;
  bool _customizeExpanded = false;
  final GlobalKey _colorSectionKey = GlobalKey();

  String? _category;

  List<(String, List<Color>)> get _allColors {
    return List.generate(7, (i) {
      final override = _customizedPresets[i];
      if (override != null) return ('Custom', [override.$1, override.$2]);
      return _habitColors[i];
    });
  }

  /// Icons filtered by current category. Returns (globalIndex, IconData, label).
  /// When category is null, returns all icons. When set, returns only icons for that category.
  List<(int, IconData, String)> get _iconsForCurrentCategory {
    if (_category == null) {
      return List.generate(
        _habitIcons.length,
        (i) => (i, _habitIcons[i].$1, _habitIcons[i].$2),
      );
    }
    final indices = _categoryToIconIndices[_category];
    if (indices == null || indices.isEmpty) {
      return List.generate(
        _habitIcons.length,
        (i) => (i, _habitIcons[i].$1, _habitIcons[i].$2),
      );
    }
    return indices
        .map((i) => (i, _habitIcons[i].$1, _habitIcons[i].$2))
        .toList();
  }

  // Rhythm (Frequency) - all 7 days selected by default (daily logic)
  final Set<int> _weekdays = {0, 1, 2, 3, 4, 5, 6};

  // Triggers (Time & Location)
  TimeOfDay? _selectedTime;
  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;
  int? _reminderMinutesBefore; // 5, 10, 15, 20, 25, 30, 45, 60 mins before start

  bool _locationEnabled = false;
  double? _locationLat;
  double? _locationLng;
  int _locationRadius = 150;
  String _locationTriggerMode = 'arrival';
  int _locationDwellMinutes = 5;

  // Pacing - start time + duration (value + unit)
  TimeOfDay? _timeBoundStartTime;
  int _timeBoundDurationValue = 15;
  String _timeBoundDurationUnit = 'minutes';

  int get _timeBoundDurationMinutes {
    final v = _timeBoundDurationValue < 0 ? 0 : _timeBoundDurationValue;
    return _timeBoundDurationUnit == 'hours' ? v * 60 : v;
  }

  // Strategy (Stacking & CBT)
  bool _habitStackingEnabled = true;
  String? _afterHabitId;
  String _anchorHabitText = '';
  String _relationship = 'Before';

  final TextEditingController _triggerController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();

  // Deadline
  String? _deadline;
  bool _useGoalDeadline = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null &&
        widget.initialName!.trim().isNotEmpty &&
        widget.initialHabit == null) {
      _habitNameController.text = widget.initialName!.trim();
    }
    if (widget.suggestedGoalDeadline != null &&
        widget.suggestedGoalDeadline!.trim().isNotEmpty) {
      _useGoalDeadline = true;
      _deadline = widget.suggestedGoalDeadline!.trim();
    }
    _initializeFromHabit();
    // Default start time when creating new habit
    if (_timeBoundStartTime == null) {
      _timeBoundStartTime = TimeOfDay.now();
    }
  }

  void _initializeFromHabit() {
    final habit = widget.initialHabit;
    if (habit == null) return;

    // Identity
    _habitNameController.text = habit.name;
    _category = habit.category;
    if (_category != null) {
      final indices = _categoryToIconIndices[_category];
      if (indices != null &&
          indices.isNotEmpty &&
          !indices.contains(_selectedIconIndex)) {
        _selectedIconIndex = indices.first;
      }
    }

    // Deadline
    if (habit.deadline != null && habit.deadline!.trim().isNotEmpty) {
      _deadline = habit.deadline!.trim();
      _useGoalDeadline = false;
    }

    // Rhythm (Frequency)
    if (habit.frequency == 'Daily' || habit.weeklyDays.isEmpty) {
      _weekdays.clear();
      _weekdays.addAll([0, 1, 2, 3, 4, 5, 6]);
    } else {
      _weekdays.clear();
      for (final day in habit.weeklyDays) {
        _weekdays.add(day - 1);
      }
    }

    // Step 4: Triggers (Time)
    if (habit.timeOfDay != null && habit.timeOfDay!.isNotEmpty) {
      _selectedTime = _parseTimeOfDay(habit.timeOfDay!);
    }
    _reminderEnabled = habit.reminderEnabled;
    if (habit.reminderMinutes != null) {
      final hours = habit.reminderMinutes! ~/ 60;
      final minutes = habit.reminderMinutes! % 60;
      _reminderTime = TimeOfDay(hour: hours, minute: minutes);
    } else if (_reminderEnabled) {
      _reminderMinutesBefore = 15; // default when enabling
    }

    // Step 4: Triggers (Location)
    final loc = habit.locationBound;
    if (loc != null && loc.enabled) {
      _locationEnabled = true;
      _locationLat = loc.lat;
      _locationLng = loc.lng;
      _locationRadius = loc.radiusMeters;
      _locationTriggerMode = loc.triggerMode;
      _locationDwellMinutes = loc.dwellMinutes ?? 5;
    }

    // Pacing (Duration)
    final tb = habit.timeBound;
    if (tb != null && tb.enabled) {
      _timeBoundStartTime = const TimeOfDay(hour: 8, minute: 0);
      final d = tb.durationMinutes <= 0 ? 15 : tb.durationMinutes;
      if (d >= 60 && d % 60 == 0) {
        _timeBoundDurationValue = d ~/ 60;
        _timeBoundDurationUnit = 'hours';
      } else {
        _timeBoundDurationValue = d;
        _timeBoundDurationUnit = 'minutes';
      }
    }

    // Derive reminderMinutesBefore from start time and reminder time (after Pacing sets start time)
    if (_reminderEnabled && habit.reminderMinutes != null) {
      final startTime = _timeBoundStartTime ?? const TimeOfDay(hour: 8, minute: 0);
      final startMins = startTime.hour * 60 + startTime.minute;
      final reminderMins = habit.reminderMinutes!;
      final before = startMins - reminderMins;
      if (_kReminderMinutesBeforeOptions.contains(before)) {
        _reminderMinutesBefore = before;
      } else {
        _reminderMinutesBefore = 15;
      }
    }

    // Step 6: Strategy (Stacking)
    final chaining = habit.chaining;
    if (chaining != null && chaining.anchorHabit != null) {
      _habitStackingEnabled = true;
      _afterHabitId = chaining.anchorHabit;
      final rel = chaining.relationship ?? 'Before';
      _relationship = (rel == 'Immediately') ? 'Before' : rel;
      // Try to find the anchor habit name
      final anchor = widget.existingHabits
          .where((h) => h.id == chaining.anchorHabit)
          .firstOrNull;
      if (anchor != null) {
        _anchorHabitText = anchor.name;
      } else {
        // Anchor may be a freeform name (default / custom habit)
        _anchorHabitText = chaining.anchorHabit ?? '';
      }
    }

    // Step 6: Strategy (CBT) - map to trigger/action controllers
    final cbt = habit.cbtEnhancements;
    if (cbt != null) {
      // Use ifThenPlan for trigger controller (the "if" part describes the trigger)
      _triggerController.text = cbt.predictedObstacle ?? '';
      // Use microVersion for action controller (the small actionable step)
      _actionController.text = cbt.ifThenPlan ?? '';
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final cleaned = timeStr.trim().toUpperCase();
      final isPM = cleaned.contains('PM');
      final isAM = cleaned.contains('AM');
      final timePart = cleaned.replaceAll(RegExp(r'[APM\s]'), '');
      final parts = timePart.split(':');
      if (parts.length >= 2) {
        var hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        if (isPM && hours < 12) hours += 12;
        if (isAM && hours == 12) hours = 0;
        return TimeOfDay(hour: hours, minute: minutes);
      }
    } catch (_) {}
    return null;
  }

  static String _toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadline != null ? DateTime.tryParse(_deadline!) : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _deadline = _toIsoDate(picked);
      _useGoalDeadline = false;
    });
  }

  @override
  void dispose() {
    _habitNameController.dispose();
    _triggerController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  // --- Save Logic ---

  void _handleCommit() {
    HapticFeedback.mediumImpact();

    // Default Name if empty
    final habitName = _habitNameController.text.trim().isNotEmpty
        ? _habitNameController.text.trim()
        : _habitIcons[_selectedIconIndex].$2;

    // 1. Build CBT Logic
    CbtEnhancements? cbtEnhancements;
    if (_triggerController.text.isNotEmpty ||
        _actionController.text.isNotEmpty) {
      cbtEnhancements = CbtEnhancements(
        predictedObstacle: _triggerController.text.trim(),
        ifThenPlan: _actionController.text.trim(),
      );
    }

    // 2. Build TimeBound (start time + duration)
    HabitTimeBoundSpec? timeBound;
    if (_timeBoundStartTime != null && _timeBoundDurationMinutes > 0) {
      final maxVal = _timeBoundDurationUnit == 'hours' ? 24 : 24 * 60;
      timeBound = HabitTimeBoundSpec(
        enabled: true,
        duration: _timeBoundDurationValue.clamp(1, maxVal),
        unit: _timeBoundDurationUnit,
        mode: 'time',
      );
    }

    // 3. Build Chaining
    HabitChaining? chaining;
    if (_anchorHabitText.isNotEmpty || _afterHabitId != null) {
      chaining = HabitChaining(
        anchorHabit: _anchorHabitText.trim().isEmpty
            ? null
            : _anchorHabitText.trim(),
        relationship: _relationship,
      );
    }

    // 4. Build Location
    HabitLocationBoundSpec? locationBound;
    if (_locationEnabled && _locationLat != null && _locationLng != null) {
      locationBound = HabitLocationBoundSpec(
        enabled: true,
        lat: _locationLat!,
        lng: _locationLng!,
        radiusMeters: _locationRadius,
        triggerMode: _locationTriggerMode,
        dwellMinutes: _locationTriggerMode == 'dwell'
            ? _locationDwellMinutes
            : null,
      );
    }

    // 5. Calc Reminder (from start time - minutes before)
    int? reminderMins;
    if (_reminderEnabled &&
        _reminderMinutesBefore != null &&
        _timeBoundStartTime != null) {
      final startMins =
          _timeBoundStartTime!.hour * 60 + _timeBoundStartTime!.minute;
      reminderMins = (startMins - _reminderMinutesBefore!).clamp(0, 24 * 60 - 1);
    }

    // 6. Resolve deadline
    String? resolvedDeadline = _deadline?.trim().isEmpty == true
        ? null
        : _deadline;
    if (_useGoalDeadline &&
        widget.suggestedGoalDeadline != null &&
        widget.suggestedGoalDeadline!.trim().isNotEmpty) {
      resolvedDeadline = widget.suggestedGoalDeadline!.trim();
    }

    // 7. Create Request
    final request = HabitCreateRequest(
      name: habitName,
      category: _category,
      frequency: _mapFrequency(),
      weeklyDays: _mapWeeklyDays(),
      deadline: resolvedDeadline,
      afterHabitId: _afterHabitId,
      timeOfDay: _selectedTime != null
          ? _formatTimeOfDay(_selectedTime!)
          : null,
      reminderMinutes: reminderMins,
      reminderEnabled: _reminderEnabled,
      chaining: chaining,
      cbtEnhancements: cbtEnhancements,
      timeBound: timeBound,
      locationBound: locationBound,
    );

    Navigator.of(context).pop(request);
  }

  // --- Helpers ---

  String? _mapFrequency() {
    return _weekdays.length == 7 ? 'Daily' : 'Weekly';
  }

  List<int> _mapWeeklyDays() {
    return _weekdays.map((d) => d + 1).toList()..sort();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _onAfterHabitIdChanged(String? id) {
    setState(() {
      _afterHabitId = id;
      if (id != null) {
        final h = widget.existingHabits.where((x) => x.id == id).firstOrNull;
        if (h != null) _anchorHabitText = h.name;
      }
    });
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final suggestedDeadline = widget.suggestedGoalDeadline?.trim();
    final baseColor = colorScheme.onSurface;

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Container(
        color: colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: Listener(
                onPointerDown: (e) {
                  if (!_customizeExpanded && !_colorPickerExpanded) return;
                  final box =
                      _colorSectionKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (box != null && box.hasSize) {
                    final bounds = box.localToGlobal(Offset.zero) & box.size;
                    if (bounds.contains(e.position)) return;
                  }
                  setState(() {
                    _customizeExpanded = false;
                    _colorPickerExpanded = false;
                  });
                },
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    topPadding + 24,
                    24,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Step1IdentityWithColor(
                        colorSectionKey: _colorSectionKey,
                        nameController: _habitNameController,
                        selectedCategory: _category,
                        onCategoryChanged: (v) {
                          setState(() {
                            _category = v;
                            if (v != null) {
                              final indices = _categoryToIconIndices[v];
                              if (indices != null &&
                                  indices.isNotEmpty &&
                                  !indices.contains(_selectedIconIndex)) {
                                _selectedIconIndex = indices.first;
                              }
                            }
                          });
                        },
                        selectedIconIndex: _selectedIconIndex,
                        iconsForCategory: _iconsForCurrentCategory,
                        selectedColorIndex: _selectedColorIndex,
                        allColors: _allColors,
                        colorPickerExpanded: _colorPickerExpanded,
                        customizeExpanded: _customizeExpanded,
                        onColorPickerExpandedChanged: (v) =>
                            setState(() => _colorPickerExpanded = v),
                        onCustomizeExpandedChanged: (v) =>
                            setState(() => _customizeExpanded = v),
                        onIconSelected: (i) =>
                            setState(() => _selectedIconIndex = i),
                        onColorSelected: (i) =>
                            setState(() => _selectedColorIndex = i),
                        onCustomizePreset: (index, gradientColor, darkColor) {
                          setState(
                            () => _customizedPresets[index] = (
                              gradientColor,
                              darkColor,
                            ),
                          );
                        },
                      ),
                      SizedBox(height: _kSectionSpacing),
                      _Step5Pacing(
                        habitColor: baseColor,
                        weekdays: _weekdays,
                        onWeekdayToggled: (day) => setState(() {
                          if (_weekdays.contains(day))
                            _weekdays.remove(day);
                          else
                            _weekdays.add(day);
                        }),
                      ),
                      SizedBox(height: _kSectionSpacing),
                      _Step4Triggers(
                        habitColor: baseColor,
                        scheduleStartTime: _timeBoundStartTime,
                        selectedTime: _selectedTime,
                        reminderEnabled: _reminderEnabled,
                        reminderTime: _reminderTime,
                        reminderMinutesBefore: _reminderMinutesBefore,
                        onReminderMinutesBeforeChanged: (v) =>
                            setState(() => _reminderMinutesBefore = v),
                        durationValue: _timeBoundDurationValue,
                        durationUnit: _timeBoundDurationUnit,
                        onStartTimeChanged: (t) =>
                            setState(() => _timeBoundStartTime = t),
                        onDurationChanged: (value, unit) => setState(() {
                          _timeBoundDurationValue = value;
                          _timeBoundDurationUnit = unit;
                        }),
                        locationEnabled: _locationEnabled,
                        lat: _locationLat,
                        lng: _locationLng,
                        radius: _locationRadius,
                        triggerMode: _locationTriggerMode,
                        dwellMinutes: _locationDwellMinutes,
                        onTimeChanged: (t) =>
                            setState(() => _selectedTime = t),
                        onReminderToggle: (v) {
                          setState(() {
                            _reminderEnabled = v;
                            if (v && _reminderMinutesBefore == null) {
                              _reminderMinutesBefore = 15;
                            }
                          });
                        },
                        onReminderTimeChanged: (t) =>
                            setState(() => _reminderTime = t),
                        onLocationToggle: (v) =>
                            setState(() => _locationEnabled = v),
                        onLocationSelected: (lat, lng) => setState(() {
                          _locationLat = lat;
                          _locationLng = lng;
                        }),
                        onRadiusChanged: (v) =>
                            setState(() => _locationRadius = v),
                        onTriggerModeChanged: (v) =>
                            setState(() => _locationTriggerMode = v),
                        onDwellMinutesChanged: (v) =>
                            setState(() => _locationDwellMinutes = v),
                      ),
                      SizedBox(height: _kSectionSpacing),
                      _Step6Strategy(
                        habitColor: baseColor,
                        habitStackingEnabled: _habitStackingEnabled,
                        onHabitStackingToggle: (v) {
                          setState(() {
                            _habitStackingEnabled = v;
                            if (!v) {
                              _afterHabitId = null;
                              _anchorHabitText = '';
                            }
                          });
                        },
                        existingHabits: widget.existingHabits,
                        afterHabitId: _afterHabitId,
                        anchorHabitText: _anchorHabitText,
                        relationship: _relationship,
                        isEditing: widget.initialHabit != null,
                        onAfterHabitIdChanged: _onAfterHabitIdChanged,
                        onAnchorTextChanged: (v) =>
                            setState(() => _anchorHabitText = v),
                        onRelationshipChanged: (v) =>
                            setState(() => _relationship = v),
                      ),
                      SizedBox(height: _kSectionSpacing),
                      _buildCopingPlanSection(colorScheme),
                      SizedBox(height: _kSectionSpacing),
                      _buildDeadlineSection(colorScheme, suggestedDeadline),
                      SizedBox(height: _kSectionSpacing),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _handleCommit,
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: Text(
                              widget.initialHabit != null
                                  ? 'Save Habit'
                                  : 'Create Habit',
                              style: AppTypography.button(context).copyWith(fontWeight: FontWeight.w600),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: bottomPadding > 0 ? bottomPadding : 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopingPlanSection(ColorScheme colorScheme) {
    return CupertinoListSection.insetGrouped(
      header: Text(
        'Coping Plan',
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: _sectionDecoration(colorScheme),
      separatorColor: _sectionSeparatorColor(colorScheme),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: _triggerController,
            style: AppTypography.body(context),
            decoration: InputDecoration(
              prefixText: "If ",
              prefixStyle: AppTypography.body(context).copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.bold,
              ),
              hintText: "I feel tired...",
              hintStyle: AppTypography.body(context).copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: _actionController,
            style: AppTypography.body(context),
            decoration: InputDecoration(
              prefixText: "Then I will ",
              prefixStyle: AppTypography.body(context).copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              hintText: "do just 2 minutes.",
              hintStyle: AppTypography.body(context).copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlineSection(
    ColorScheme colorScheme,
    String? suggestedDeadline,
  ) {
    final deadlineChildren = <Widget>[
      CupertinoListTile.notched(
        leading: Icon(
          Icons.event_outlined,
          color: colorScheme.onSurfaceVariant,
          size: 28,
        ),
        title: Text(
          _deadline ??
              (suggestedDeadline != null && _useGoalDeadline
                  ? 'Use goal deadline ($suggestedDeadline)'
                  : 'Set an end date (optional)'),
          style: AppTypography.body(context).copyWith(
            color: _deadline != null || _useGoalDeadline
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_deadline != null)
              GestureDetector(
                onTap: () => setState(() {
                  _deadline = null;
                  _useGoalDeadline = false;
                }),
                child: Icon(
                  Icons.clear,
                  color: colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            if (_deadline != null) const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ],
        ),
        onTap: _pickDeadline,
      ),
    ];
    if (suggestedDeadline != null && suggestedDeadline.isNotEmpty) {
      deadlineChildren.add(
        CupertinoListTile.notched(
          leading: Icon(
            Icons.flag_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 28,
          ),
          title: Text(
            'Use goal deadline ($suggestedDeadline)',
            style: AppTypography.body(context),
          ),
          trailing: CupertinoSwitch(
            value: _useGoalDeadline,
            onChanged: (v) => setState(() {
              _useGoalDeadline = v;
              _deadline = v ? suggestedDeadline : _deadline;
            }),
            activeTrackColor: colorScheme.primary,
          ),
          onTap: null,
        ),
      );
    }
    return CupertinoListSection.insetGrouped(
      header: Text(
        'End date',
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: _sectionDecoration(colorScheme),
      separatorColor: _sectionSeparatorColor(colorScheme),
      children: deadlineChildren,
    );
  }
}

// ============================================================================
// STEP WIDGETS
// ============================================================================

// --- STEP 1: IDENTITY (name + color in same control) ---
class _Step1IdentityWithColor extends StatefulWidget {
  final GlobalKey colorSectionKey;
  final TextEditingController nameController;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final int selectedIconIndex;
  final List<(int, IconData, String)> iconsForCategory;
  final int selectedColorIndex;
  final List<(String, List<Color>)> allColors;
  final bool colorPickerExpanded;
  final bool customizeExpanded;
  final ValueChanged<bool> onColorPickerExpandedChanged;
  final ValueChanged<bool> onCustomizeExpandedChanged;
  final ValueChanged<int> onIconSelected;
  final ValueChanged<int> onColorSelected;
  final void Function(int index, Color gradientColor, Color darkColor)
  onCustomizePreset;

  const _Step1IdentityWithColor({
    required this.colorSectionKey,
    required this.nameController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.selectedIconIndex,
    required this.iconsForCategory,
    required this.selectedColorIndex,
    required this.allColors,
    required this.colorPickerExpanded,
    required this.customizeExpanded,
    required this.onColorPickerExpandedChanged,
    required this.onCustomizeExpandedChanged,
    required this.onIconSelected,
    required this.onColorSelected,
    required this.onCustomizePreset,
  });

  @override
  State<_Step1IdentityWithColor> createState() =>
      _Step1IdentityWithColorState();
}

class _Step1IdentityWithColorState extends State<_Step1IdentityWithColor> {
  double _customizeHue = 0.0;
  bool _iconViewAllExpanded = false;

  void _openCustomize() {
    _customizeHue = HSLColor.fromColor(
      widget.allColors[widget.selectedColorIndex].$2.first,
    ).hue;
    widget.onCustomizeExpandedChanged(true);
  }

  void _closeCustomize() {
    widget.onCustomizeExpandedChanged(false);
  }

  void _applyCustomColor() {
    final gradientColor = HSLColor.fromAHSL(
      1,
      _customizeHue,
      0.6,
      0.5,
    ).toColor();
    final darkColor = HSLColor.fromAHSL(1, _customizeHue, 0.6, 0.35).toColor();
    widget.onCustomizePreset(
      widget.selectedColorIndex,
      gradientColor,
      darkColor,
    );
    _closeCustomize();
  }

  Widget _buildInlineHuePicker(ColorScheme colorScheme) {
    final gradientColor = HSLColor.fromAHSL(
      1,
      _customizeHue,
      0.6,
      0.5,
    ).toColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: gradientColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: _hueSpectrumColors,
              stops: [0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1],
            ),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 0,
              overlayColor: Colors.transparent,
              thumbColor: colorScheme.surface,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _customizeHue,
              min: 0,
              max: 360,
              onChanged: (v) => setState(() => _customizeHue = v),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _applyCustomColor,
          child: const Text('Use this color'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = widget.allColors[widget.selectedColorIndex].$2;

    return CupertinoListSection.insetGrouped(
      header: Text(
        "Habit",
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: _sectionDecoration(colorScheme),
      separatorColor: _sectionSeparatorColor(colorScheme),
      children: [
        // Name + color row
        Container(
          key: widget.colorSectionKey,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: widget.nameController,
                style: AppTypography.body(context),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: "Add a habit (e.g., meditation)",
                  hintStyle: AppTypography.body(context).copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      final next = !widget.colorPickerExpanded;
                      widget.onColorPickerExpandedChanged(next);
                      if (!next) widget.onCustomizeExpandedChanged(false);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.first.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.colorPickerExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: widget.allColors.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (ctx, index) => SizedBox(
                                  width: 36,
                                  child: _AnimatedColorTile(
                                    colors: widget.allColors[index].$2,
                                    isSelected:
                                        widget.selectedColorIndex == index,
                                    onTap: () => widget.onColorSelected(index),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: _kControlSpacing),
                            InkWell(
                              onTap: () => widget.customizeExpanded
                                  ? _closeCustomize()
                                  : _openCustomize(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.palette_outlined,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Customize color",
                                      style: AppTypography.bodySmall(context)
                                          .copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      widget.customizeExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      if (widget.customizeExpanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildInlineHuePicker(colorScheme),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Category row (before icon so icon list is filtered by category)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.selectedCategory,
              isExpanded: true,
              hint: Text(
                "Select category",
                style: AppTypography.body(context).copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(12),
              items: _kHabitCategories
                  .map((c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c, style: AppTypography.body(context)),
                      ))
                  .toList(),
              onChanged: (v) => widget.onCategoryChanged(v),
            ),
          ),
        ),
        // Icon picker row (tile + expandable grid, filtered by category)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoListTile.notched(
              leading: Icon(
                _habitIcons[widget.selectedIconIndex].$1,
                color: colors.first,
                size: 28,
              ),
              title: Text(
                _habitIcons[widget.selectedIconIndex].$2,
                style: AppTypography.body(context),
              ),
              trailing: Icon(
                _iconViewAllExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () => setState(
                () => _iconViewAllExpanded = !_iconViewAllExpanded,
              ),
            ),
            if (_iconViewAllExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.iconsForCategory.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 12),
                    itemBuilder: (ctx, index) {
                      final entry = widget.iconsForCategory[index];
                      final globalIndex = entry.$1;
                      return SizedBox(
                        width: 56,
                        child: _AnimatedIconTile(
                          icon: entry.$2,
                          label: entry.$3,
                          isSelected:
                              widget.selectedIconIndex == globalIndex,
                          onTap: () =>
                              widget.onIconSelected(globalIndex),
                          accentColor: colors.first,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// Animated Icon Tile for carousel
class _AnimatedIconTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  const _AnimatedIconTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  @override
  State<_AnimatedIconTile> createState() => _AnimatedIconTileState();
}

class _AnimatedIconTileState extends State<_AnimatedIconTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void didUpdateWidget(_AnimatedIconTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = widget.isSelected
              ? _bounceAnimation.value
              : _scaleAnimation.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? (widget.accentColor ?? colorScheme.primary).withValues(
                        alpha: 0.2,
                      )
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: widget.isSelected
                    ? (widget.accentColor ?? colorScheme.primary)
                    : colorScheme.onSurfaceVariant,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Animated Color Tile
class _AnimatedColorTile extends StatefulWidget {
  final List<Color> colors;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedColorTile({
    required this.colors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedColorTile> createState() => _AnimatedColorTileState();
}

class _AnimatedColorTileState extends State<_AnimatedColorTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.colors),
            shape: BoxShape.circle,
            border: widget.isSelected
                ? Border.all(color: colorScheme.onSurface, width: 3)
                : null,
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withValues(alpha: 0.4),
                blurRadius: widget.isSelected ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.isSelected
              ? Icon(Icons.check, color: colorScheme.onPrimary, size: 22)
              : null,
        ),
      ),
    );
  }
}

// Animated Day Chip
class _AnimatedDayChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final Color? accentColor;
  final VoidCallback onTap;

  const _AnimatedDayChip({
    required this.label,
    required this.isSelected,
    this.accentColor,
    required this.onTap,
  });

  @override
  State<_AnimatedDayChip> createState() => _AnimatedDayChipState();
}

class _AnimatedDayChipState extends State<_AnimatedDayChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.85).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (widget.accentColor ?? colorScheme.primary)
                : colorScheme.surfaceContainerHigh,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected
                  ? (widget.accentColor ?? colorScheme.primary)
                  : colorScheme.outlineVariant,
              width: widget.isSelected ? 0 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppTypography.bodySmall(context).copyWith(
              color: widget.isSelected
                  ? _contrastColor(widget.accentColor ?? colorScheme.primary)
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// Animated Icon Button
class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedIconButton({required this.icon, required this.onTap});

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.9).animate(_controller),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, color: colorScheme.primary, size: 28),
        ),
      ),
    );
  }
}

// --- STEP 4: TRIGGERS ---
class _Step4Triggers extends StatefulWidget {
  final Color habitColor;
  final TimeOfDay? scheduleStartTime;
  final TimeOfDay? selectedTime;
  final bool reminderEnabled;
  final TimeOfDay? reminderTime;
  final int? reminderMinutesBefore;
  final ValueChanged<int?> onReminderMinutesBeforeChanged;
  final int durationValue;
  final String durationUnit;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final void Function(int value, String unit) onDurationChanged;
  final bool locationEnabled;
  final double? lat;
  final double? lng;
  final int radius;
  final String triggerMode;
  final int dwellMinutes;
  final ValueChanged<TimeOfDay?> onTimeChanged;
  final ValueChanged<bool> onReminderToggle;
  final ValueChanged<TimeOfDay?> onReminderTimeChanged;
  final ValueChanged<bool> onLocationToggle;
  final void Function(double, double) onLocationSelected;
  final ValueChanged<int> onRadiusChanged;
  final ValueChanged<String> onTriggerModeChanged;
  final ValueChanged<int> onDwellMinutesChanged;

  const _Step4Triggers({
    required this.habitColor,
    this.scheduleStartTime,
    required this.selectedTime,
    required this.reminderEnabled,
    required this.reminderTime,
    this.reminderMinutesBefore,
    required this.onReminderMinutesBeforeChanged,
    required this.durationValue,
    required this.durationUnit,
    required this.onStartTimeChanged,
    required this.onDurationChanged,
    required this.locationEnabled,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.triggerMode,
    required this.dwellMinutes,
    required this.onTimeChanged,
    required this.onReminderToggle,
    required this.onReminderTimeChanged,
    required this.onLocationToggle,
    required this.onLocationSelected,
    required this.onRadiusChanged,
    required this.onTriggerModeChanged,
    required this.onDwellMinutesChanged,
  });

  @override
  State<_Step4Triggers> createState() => _Step4TriggersState();
}

class _Step4TriggersState extends State<_Step4Triggers> {
  bool _startTimePickerExpanded = false;
  bool _durationExpanded = false;
  bool _alertExpanded = false;
  late DateTime _pendingStartDateTime;
  late TextEditingController _durationController;
  late FocusNode _durationFocusNode;

  void _syncPendingFromStartTime() {
    final st = widget.scheduleStartTime ?? TimeOfDay.now();
    final now = DateTime.now();
    _pendingStartDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      st.hour,
      st.minute,
    );
  }

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.durationValue.toString(),
    );
    _durationFocusNode = FocusNode();
    _durationFocusNode.addListener(() {
      if (!_durationFocusNode.hasFocus && mounted) {
        setState(() => _durationExpanded = false);
      }
    });
    _syncPendingFromStartTime();
  }

  @override
  void didUpdateWidget(_Step4Triggers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationValue != widget.durationValue &&
        _durationController.text != widget.durationValue.toString()) {
      _durationController.text = widget.durationValue.toString();
    }
    if (oldWidget.scheduleStartTime != widget.scheduleStartTime &&
        !_startTimePickerExpanded) {
      _syncPendingFromStartTime();
    }
    if (oldWidget.reminderEnabled && !widget.reminderEnabled) {
      _alertExpanded = false;
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _durationFocusNode.dispose();
    super.dispose();
  }

  void _onDurationTextChanged(String text) {
    final parsed = int.tryParse(text);
    final value = parsed ?? 0;
    final maxVal = widget.durationUnit == 'hours' ? 24 : 1440;
    widget.onDurationChanged(value.clamp(0, maxVal), widget.durationUnit);
  }

  void _confirmStartTime() {
    widget.onStartTimeChanged(TimeOfDay.fromDateTime(_pendingStartDateTime));
    setState(() => _startTimePickerExpanded = false);
  }

  static String _formatMinutesBefore(int mins) =>
      mins == 60 ? '1 hour before' : '$mins mins before';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final startDefault = TimeOfDay.now();
    final displayStart = widget.scheduleStartTime ?? startDefault;

    return CupertinoListSection.insetGrouped(
      header: Text(
        "Reminders",
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: _sectionDecoration(colorScheme),
      separatorColor: _sectionSeparatorColor(colorScheme),
      children: [
        // Start time row
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    if (_startTimePickerExpanded) {
                      _confirmStartTime();
                    } else {
                      _syncPendingFromStartTime();
                      _startTimePickerExpanded = true;
                      _durationExpanded = false;
                      _alertExpanded = false;
                    }
                  });
                },
                borderRadius: BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Start time",
                            style: AppTypography.bodySmall(context).copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            displayStart.format(context),
                            style: AppTypography.body(context).copyWith(
                              color: widget.habitColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_startTimePickerExpanded)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: theme.brightness == Brightness.dark
                          ? Brightness.dark
                          : Brightness.light,
                    ),
                    child: SizedBox(
                      height: 180,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: _pendingStartDateTime,
                        use24hFormat: MediaQuery.of(context)
                            .alwaysUse24HourFormat,
                        minuteInterval: 1,
                        onDateTimeChanged: (v) =>
                            setState(() => _pendingStartDateTime = v),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirmStartTime,
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        // Duration row
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _durationExpanded = true;
                    _startTimePickerExpanded = false;
                    _alertExpanded = false;
                  });
                },
                borderRadius: BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Duration",
                            style: AppTypography.bodySmall(context).copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          _durationExpanded
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      child: TextField(
                                        controller: _durationController,
                                        focusNode: _durationFocusNode,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        autofocus: true,
                                        style: AppTypography.body(context)
                                            .copyWith(
                                              fontSize: 18,
                                              color: widget.habitColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        decoration: InputDecoration(
                                          hintText: '5',
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 4,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: widget.habitColor,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        onChanged: _onDurationTextChanged,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: widget.durationUnit,
                                        isExpanded: false,
                                        underline: const SizedBox.shrink(),
                                        style: AppTypography.body(context)
                                            .copyWith(
                                              fontSize: 18,
                                              color: widget.habitColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'minutes',
                                            child: Text('min'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'hours',
                                            child: Text('hr'),
                                          ),
                                        ],
                                        onChanged: (unit) {
                                          if (unit != null) {
                                            widget.onDurationChanged(
                                              widget.durationValue,
                                              unit,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  "${widget.durationValue} ${widget.durationUnit == 'hours' ? 'hr' : 'min'}",
                                  style: AppTypography.body(context)
                                      .copyWith(
                                        color: widget.habitColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Alert row (collapsible when reminder enabled)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.reminderEnabled
                    ? () {
                        setState(() {
                          _alertExpanded = !_alertExpanded;
                          _startTimePickerExpanded = false;
                          _durationExpanded = false;
                        });
                      }
                    : null,
                borderRadius: BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Alert",
                              style: AppTypography.bodySmall(context).copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              widget.reminderEnabled
                                  ? _formatMinutesBefore(
                                      widget.reminderMinutesBefore ??
                                          _kReminderMinutesBeforeOptions.first,
                                    )
                                  : "Off",
                              style: AppTypography.body(context).copyWith(
                                color: widget.reminderEnabled
                                    ? widget.habitColor
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: widget.reminderEnabled,
                        onChanged: widget.onReminderToggle,
                        activeTrackColor: widget.habitColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_alertExpanded && widget.reminderEnabled)
              Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    ..._kReminderMinutesBeforeOptions.map((mins) {
                      final isSelected =
                          (widget.reminderMinutesBefore ?? 15) == mins;
                      return InkWell(
                        onTap: () {
                          widget.onReminderMinutesBeforeChanged(mins);
                          setState(() => _alertExpanded = false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _formatMinutesBefore(mins),
                                  style: AppTypography.body(context),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check,
                                  color: widget.habitColor,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
        // Location row
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoListTile.notched(
              leading: Icon(
                Icons.location_on_outlined,
                color: colorScheme.onSurfaceVariant,
                size: 28,
              ),
              title: Text(
                "Location",
                style: AppTypography.body(context),
              ),
              additionalInfo: widget.lat != null
                  ? Text(
                      "Location set",
                      style: AppTypography.body(context).copyWith(
                        color: widget.habitColor,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
              trailing: CupertinoSwitch(
                value: widget.locationEnabled,
                onChanged: widget.onLocationToggle,
                activeTrackColor: widget.habitColor,
              ),
              onTap: () async {
                if (widget.locationEnabled) return;
                try {
                  LocationPermission p =
                      await Geolocator.checkPermission();
                  if (p == LocationPermission.denied) {
                    p = await Geolocator.requestPermission();
                  }
                  if (p == LocationPermission.whileInUse ||
                      p == LocationPermission.always) {
                    final pos =
                        await Geolocator.getCurrentPosition();
                    widget.onLocationSelected(
                        pos.latitude, pos.longitude);
                    widget.onLocationToggle(true);
                  }
                } catch (e) {
                  debugPrint('Location error: $e');
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

// --- STEP 5: PACING (Weekdays only; start time and duration are in Reminders) ---
class _Step5Pacing extends StatelessWidget {
  final Color habitColor;
  final Set<int> weekdays;
  final ValueChanged<int> onWeekdayToggled;

  const _Step5Pacing({
    required this.habitColor,
    required this.weekdays,
    required this.onWeekdayToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CupertinoListSection.insetGrouped(
      header: Text(
        "Schedule",
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: _sectionDecoration(colorScheme),
      separatorColor: _sectionSeparatorColor(colorScheme),
      children: [
        // Weekdays row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final selected = weekdays.contains(index);
              return _AnimatedDayChip(
                label: days[index],
                isSelected: selected,
                accentColor: habitColor,
                onTap: () => onWeekdayToggled(index),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// --- STEP 6: HABIT STACKING ---
class _Step6Strategy extends StatefulWidget {
  final Color habitColor;
  final bool habitStackingEnabled;
  final ValueChanged<bool> onHabitStackingToggle;
  final List<HabitItem> existingHabits;
  final String? afterHabitId;
  final String anchorHabitText;
  final String relationship;
  final bool isEditing;
  final ValueChanged<String?> onAfterHabitIdChanged;
  final ValueChanged<String> onAnchorTextChanged;
  final ValueChanged<String> onRelationshipChanged;

  const _Step6Strategy({
    required this.habitColor,
    required this.habitStackingEnabled,
    required this.onHabitStackingToggle,
    required this.existingHabits,
    required this.afterHabitId,
    required this.anchorHabitText,
    required this.relationship,
    required this.onAfterHabitIdChanged,
    required this.onAnchorTextChanged,
    required this.onRelationshipChanged,
    this.isEditing = false,
  });

  @override
  State<_Step6Strategy> createState() => _Step6StrategyState();
}

class _Step6StrategyState extends State<_Step6Strategy> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    if (widget.anchorHabitText.isNotEmpty) {
      _searchController.text = widget.anchorHabitText;
    }
    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _Step6Strategy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.anchorHabitText != oldWidget.anchorHabitText &&
        widget.anchorHabitText != _searchController.text) {
      _searchController.text = widget.anchorHabitText;
    }
    // Auto-focus the search field when habit stacking is toggled on
    if (widget.habitStackingEnabled && !oldWidget.habitStackingEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Builds the merged + filtered suggestion list from user habits and defaults.
  List<_HabitSuggestion> _buildSuggestions() {
    final query = _searchController.text.trim().toLowerCase();
    final existingNames =
        widget.existingHabits.map((h) => h.name.toLowerCase()).toSet();

    final List<_HabitSuggestion> results = [];

    // User's own habits
    for (final h in widget.existingHabits) {
      if (query.isEmpty || h.name.toLowerCase().contains(query)) {
        results.add(_HabitSuggestion(
          label: h.name,
          habitId: h.id,
          isDefault: false,
        ));
      }
    }

    // Default habits (exclude duplicates already in user habits)
    for (final name in _kDefaultStackingHabits) {
      if (!existingNames.contains(name.toLowerCase())) {
        if (query.isEmpty || name.toLowerCase().contains(query)) {
          results.add(_HabitSuggestion(
            label: name,
            habitId: null,
            isDefault: true,
          ));
        }
      }
    }

    return results;
  }

  void _selectSuggestion(_HabitSuggestion suggestion) {
    _searchController.text = suggestion.label;
    widget.onAnchorTextChanged(suggestion.label);
    widget.onAfterHabitIdChanged(suggestion.habitId);
    _searchFocusNode.unfocus();
    setState(() => _showSuggestions = false);
  }

  void _clearSelection() {
    _searchController.clear();
    widget.onAnchorTextChanged('');
    widget.onAfterHabitIdChanged(null);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CupertinoListSection.insetGrouped(
      header: Text(
        "Habit Stacking",
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: _sectionDecoration(colorScheme),
      separatorColor: _sectionSeparatorColor(colorScheme),
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoListTile.notched(
              leading: Icon(
                Icons.link,
                color: colorScheme.onSurfaceVariant,
                size: 28,
              ),
              title: Text(
                "Link this habit to an existing routine",
                style: AppTypography.body(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: CupertinoSwitch(
                value: widget.habitStackingEnabled,
                onChanged: widget.onHabitStackingToggle,
                activeTrackColor: widget.habitColor,
              ),
              onTap: null,
            ),
            if (widget.habitStackingEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Relationship picker (Before / After)
                    Builder(builder: (context) {
                      const options = ['Before', 'After'];
                      final safeValue = options.contains(widget.relationship)
                          ? widget.relationship
                          : 'Before';
                      return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        dropdownColor:
                            colorScheme.surfaceContainerHighest,
                        value: safeValue,
                        isExpanded: true,
                        style: AppTypography.body(context),
                        underline: const SizedBox(),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        items: ['Before', 'After']
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            widget.onRelationshipChanged(v!),
                      ),
                    );
                    }),
                    SizedBox(height: _kControlSpacing),

                    // Searchable habit picker
                    TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: AppTypography.body(context),
                      onChanged: (v) {
                        widget.onAnchorTextChanged(v);
                        // Clear the linked habit ID when user starts typing
                        if (widget.afterHabitId != null) {
                          widget.onAfterHabitIdChanged(null);
                        }
                        setState(() => _showSuggestions = true);
                      },
                      decoration: InputDecoration(
                        hintText: "Search or type a habit...",
                        hintStyle: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  size: 18,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                onPressed: _clearSelection,
                              )
                            : null,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),

                    // Suggestion list
                    if (_showSuggestions) _buildSuggestionList(colorScheme),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestionList(ColorScheme colorScheme) {
    final suggestions = _buildSuggestions();
    final query = _searchController.text.trim();

    // Split into user habits and default habits
    final userHabits =
        suggestions.where((s) => !s.isDefault).toList();
    final defaultHabits =
        suggestions.where((s) => s.isDefault).toList();

    // Check if typed text matches any suggestion exactly
    final exactMatch = suggestions.any(
      (s) => s.label.toLowerCase() == query.toLowerCase(),
    );

    if (suggestions.isEmpty && query.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            // "Use custom" option when typed text doesn't match any suggestion
            if (query.isNotEmpty && !exactMatch)
              _SuggestionTile(
                label: 'Use "$query"',
                icon: Icons.add_circle_outline,
                iconColor: widget.habitColor,
                colorScheme: colorScheme,
                onTap: () {
                  widget.onAnchorTextChanged(query);
                  widget.onAfterHabitIdChanged(null);
                  _searchFocusNode.unfocus();
                  setState(() => _showSuggestions = false);
                },
              ),

            // User's own habits section
            if (userHabits.isNotEmpty) ...[
              _SectionLabel(
                label: 'Your Habits',
                colorScheme: colorScheme,
              ),
              ...userHabits.map((s) => _SuggestionTile(
                    label: s.label,
                    icon: Icons.person_outline,
                    iconColor: colorScheme.primary,
                    colorScheme: colorScheme,
                    isSelected: widget.afterHabitId == s.habitId,
                    onTap: () => _selectSuggestion(s),
                  )),
            ],

            // Default habits section
            if (defaultHabits.isNotEmpty) ...[
              _SectionLabel(
                label: 'Common Habits',
                colorScheme: colorScheme,
              ),
              ...defaultHabits.map((s) => _SuggestionTile(
                    label: s.label,
                    icon: Icons.auto_awesome_outlined,
                    iconColor: colorScheme.tertiary,
                    colorScheme: colorScheme,
                    isSelected:
                        s.label == widget.anchorHabitText &&
                            widget.afterHabitId == null,
                    onTap: () => _selectSuggestion(s),
                  )),
            ],

            // Empty state
            if (suggestions.isEmpty && query.isNotEmpty && exactMatch)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No matching habits found',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(context).copyWith(
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Internal model for a habit suggestion entry.
class _HabitSuggestion {
  final String label;
  final String? habitId;
  final bool isDefault;

  const _HabitSuggestion({
    required this.label,
    this.habitId,
    required this.isDefault,
  });
}

/// Section header label inside the suggestion list.
class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const _SectionLabel({required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Single tappable row in the suggestion list.
class _SuggestionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final ColorScheme colorScheme;
  final bool isSelected;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.colorScheme,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body(context).copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: 18, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

