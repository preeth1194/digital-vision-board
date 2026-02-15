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

const List<(IconData, String)> _habitIcons = [
  (Icons.fitness_center, 'Workout'),
  (Icons.menu_book, 'Read'),
  (Icons.water_drop, 'Water'),
  (Icons.restaurant, 'Food'),
  (Icons.bedtime, 'Sleep'),
  (Icons.psychology, 'Mental'),
  (Icons.favorite, 'Health'),
  (Icons.directions_bike, 'Exercise'),
  (Icons.coffee, 'Morning'),
  (Icons.music_note, 'Creative'),
  (Icons.mood, 'Happy'),
  (Icons.wb_sunny, 'Energy'),
  (Icons.eco, 'Nature'),
  (Icons.bolt, 'Power'),
  (Icons.track_changes, 'Goal'),
  (Icons.emoji_events, 'Win'),
];

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

  List<(String, List<Color>)> get _allColors {
    return List.generate(7, (i) {
      final override = _customizedPresets[i];
      if (override != null) return ('Custom', [override.$1, override.$2]);
      return _habitColors[i];
    });
  }

  // Rhythm (Frequency) - all 7 days selected by default (daily logic)
  final Set<int> _weekdays = {0, 1, 2, 3, 4, 5, 6};

  // Triggers (Time & Location)
  TimeOfDay? _selectedTime;
  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;

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
  String? _afterHabitId;
  String _anchorHabitText = '';
  String _relationship = 'Immediately';

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

    // Step 6: Strategy (Stacking)
    final chaining = habit.chaining;
    if (chaining != null && chaining.anchorHabit != null) {
      _afterHabitId = chaining.anchorHabit;
      _relationship = chaining.relationship ?? 'Immediately';
      // Try to find the anchor habit name
      final anchor = widget.existingHabits
          .where((h) => h.id == chaining.anchorHabit)
          .firstOrNull;
      if (anchor != null) {
        _anchorHabitText = anchor.name;
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

    // 5. Calc Reminder
    int? reminderMins;
    if (_reminderEnabled && _reminderTime != null) {
      reminderMins = _reminderTime!.hour * 60 + _reminderTime!.minute;
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.initialHabit != null ? 'Edit Habit' : 'Add Habit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Step1IdentityWithColor(
                        colorSectionKey: _colorSectionKey,
                        nameController: _habitNameController,
                        selectedIconIndex: _selectedIconIndex,
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
                      SizedBox(height: _kControlSpacing),
                      _Step5Pacing(
                        startTime: _timeBoundStartTime,
                        durationValue: _timeBoundDurationValue,
                        durationUnit: _timeBoundDurationUnit,
                        habitColor: _allColors[_selectedColorIndex].$2.first,
                        onStartTimeChanged: (t) =>
                            setState(() => _timeBoundStartTime = t),
                        onDurationChanged: (value, unit) => setState(() {
                          _timeBoundDurationValue = value;
                          _timeBoundDurationUnit = unit;
                        }),
                      ),
                      SizedBox(height: _kControlSpacing),
                      _Step3Rhythm(
                        weekdays: _weekdays,
                        habitColor: _allColors[_selectedColorIndex].$2.first,
                        onWeekdayToggled: (day) => setState(() {
                          if (_weekdays.contains(day))
                            _weekdays.remove(day);
                          else
                            _weekdays.add(day);
                        }),
                      ),
                      SizedBox(height: _kControlSpacing),
                      _Step4Triggers(
                        habitColor: _allColors[_selectedColorIndex].$2.first,
                        selectedTime: _selectedTime,
                        reminderEnabled: _reminderEnabled,
                        reminderTime: _reminderTime,
                        locationEnabled: _locationEnabled,
                        lat: _locationLat,
                        lng: _locationLng,
                        radius: _locationRadius,
                        triggerMode: _locationTriggerMode,
                        dwellMinutes: _locationDwellMinutes,
                        onTimeChanged: (t) => setState(() {
                          _selectedTime = t;
                          if (t != null && _reminderTime == null)
                            _reminderTime = t;
                        }),
                        onReminderToggle: (v) =>
                            setState(() => _reminderEnabled = v),
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
                      SizedBox(height: _kControlSpacing),
                      _Step6Strategy(
                        existingHabits: widget.existingHabits,
                        triggerController: _triggerController,
                        actionController: _actionController,
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
                      SizedBox(height: _kControlSpacing),
                      _buildDeadlineSection(colorScheme, suggestedDeadline),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  bottomPadding > 0 ? bottomPadding : 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineSection(
    ColorScheme colorScheme,
    String? suggestedDeadline,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'End date',
          style: AppTypography.bodySmall(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: _kControlSpacing),
        InkWell(
          onTap: _pickDeadline,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
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
                ),
                if (_deadline != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _deadline = null;
                      _useGoalDeadline = false;
                    }),
                  ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        if (suggestedDeadline != null && suggestedDeadline.isNotEmpty) ...[
          SizedBox(height: _kControlSpacing),
          SwitchListTile(
            value: _useGoalDeadline,
            onChanged: (v) => setState(() {
              _useGoalDeadline = v;
              _deadline = v ? suggestedDeadline : _deadline;
            }),
            title: Text(
              'Use goal deadline ($suggestedDeadline)',
              style: AppTypography.bodySmall(context),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
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
  final int selectedIconIndex;
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
    required this.selectedIconIndex,
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
              thumbColor: Colors.white,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Habit",
          style: AppTypography.bodySmall(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: _kControlSpacing),
        Container(
          key: widget.colorSectionKey,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
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
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: widget.colorPickerExpanded
                    ? Padding(
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
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              child: widget.customizeExpanded
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: _buildInlineHuePicker(colorScheme),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        SizedBox(height: _kControlSpacing),
        Row(
          children: [
            Text(
              "Icon",
              style: AppTypography.bodySmall(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            InkWell(
              onTap: () => setState(
                () => _iconViewAllExpanded = !_iconViewAllExpanded,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "View all",
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _iconViewAllExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: _kControlSpacing),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 12),
                    itemBuilder: (ctx, index) => SizedBox(
                      width: 56,
                      child: _AnimatedIconTile(
                        icon: _habitIcons[index].$1,
                        label: _habitIcons[index].$2,
                        isSelected: widget.selectedIconIndex == index,
                        onTap: () => widget.onIconSelected(index),
                        accentColor: colors.first,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: _iconViewAllExpanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 5,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1,
                          children: List.generate(
                            _habitIcons.length - 5,
                            (i) {
                              final index = i + 5;
                              return _AnimatedIconTile(
                                icon: _habitIcons[index].$1,
                                label: _habitIcons[index].$2,
                                isSelected: widget.selectedIconIndex == index,
                                onTap: () => widget.onIconSelected(index),
                                accentColor: colors.first,
                              );
                            },
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Animated Icon Tile for carousel (compact: icon only)
class _AnimatedIconTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;
  final Color? accentColor;

  const _AnimatedIconTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.compact = true,
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
            if (!widget.compact) ...[
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: AppTypography.caption(context).copyWith(
                  color: widget.isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}

// --- STEP 3: RHYTHM (Repeat control) ---
class _Step3Rhythm extends StatelessWidget {
  final Set<int> weekdays;
  final Color habitColor;
  final ValueChanged<int> onWeekdayToggled;

  const _Step3Rhythm({
    required this.weekdays,
    required this.habitColor,
    required this.onWeekdayToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
        ),
      ],
    );
  }
}

// Animated Option Card
class _AnimatedOptionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedOptionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedOptionCard> createState() => _AnimatedOptionCardState();
}

class _AnimatedOptionCardState extends State<_AnimatedOptionCard>
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
        scale: Tween<double>(begin: 1.0, end: 0.98).animate(_controller),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? colorScheme.primary.withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: AppTypography.body(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
              if (widget.isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary),
            ],
          ),
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
class _Step4Triggers extends StatelessWidget {
  final Color habitColor;
  final TimeOfDay? selectedTime;
  final bool reminderEnabled;
  final TimeOfDay? reminderTime;
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
    required this.selectedTime,
    required this.reminderEnabled,
    required this.reminderTime,
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayTime = reminderTime ?? selectedTime ?? TimeOfDay.now();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Time card (alarm style)
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            leading: Icon(Icons.schedule, color: colorScheme.onSurfaceVariant),
            title: Row(
              children: [
                Text(
                  "Alert",
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.notifications_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            subtitle: Text(
              reminderEnabled && (reminderTime != null || selectedTime != null)
                  ? displayTime.format(context)
                  : "Pick time",
              style: AppTypography.body(context).copyWith(
                color:
                    (reminderEnabled &&
                        (reminderTime != null || selectedTime != null))
                    ? habitColor
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Switch(
              value: reminderEnabled,
              onChanged: onReminderToggle,
              activeColor: habitColor,
            ),
            onTap: () async {
              final t = await showCupertinoTimePicker(
                context,
                initialTime: reminderTime ?? selectedTime ?? TimeOfDay.now(),
              );
              if (t != null) {
                onReminderTimeChanged(t);
                onTimeChanged(t);
              }
            },
          ),
        ),
        SizedBox(height: _kControlSpacing),
        // Location card (Time Zone style)
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: ListTile(
            leading: Icon(Icons.public, color: colorScheme.onSurfaceVariant),
            title: Text(
              "Location",
              style: AppTypography.bodySmall(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              locationEnabled && lat != null
                  ? "Location set"
                  : "Select location",
              style: AppTypography.body(context).copyWith(
                color: (locationEnabled && lat != null)
                    ? habitColor
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () async {
              try {
                LocationPermission p = await Geolocator.checkPermission();
                if (p == LocationPermission.denied) {
                  p = await Geolocator.requestPermission();
                }
                if (p == LocationPermission.whileInUse ||
                    p == LocationPermission.always) {
                  final pos = await Geolocator.getCurrentPosition();
                  onLocationSelected(pos.latitude, pos.longitude);
                  onLocationToggle(true);
                }
              } catch (e) {
                debugPrint('Location error: $e');
              }
            },
          ),
        ),
      ],
    );
  }
}

// --- STEP 5: PACING ---
class _Step5Pacing extends StatefulWidget {
  final TimeOfDay? startTime;
  final int durationValue;
  final String durationUnit;
  final Color habitColor;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final void Function(int value, String unit) onDurationChanged;

  const _Step5Pacing({
    required this.startTime,
    required this.durationValue,
    required this.durationUnit,
    required this.habitColor,
    required this.onStartTimeChanged,
    required this.onDurationChanged,
  });

  @override
  State<_Step5Pacing> createState() => _Step5PacingState();
}

class _Step5PacingState extends State<_Step5Pacing> {
  late TextEditingController _durationController;
  bool _startTimePickerExpanded = false;
  DateTime _pendingStartDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.durationValue.toString(),
    );
    _syncPendingFromStartTime();
  }

  void _syncPendingFromStartTime() {
    final st = widget.startTime ?? TimeOfDay.now();
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
  void didUpdateWidget(_Step5Pacing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationValue != widget.durationValue &&
        _durationController.text != widget.durationValue.toString()) {
      _durationController.text = widget.durationValue.toString();
    }
    if (oldWidget.startTime != widget.startTime && !_startTimePickerExpanded) {
      _syncPendingFromStartTime();
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final startDefault = TimeOfDay.now();
    final displayStart = widget.startTime ?? startDefault;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (_startTimePickerExpanded) {
                              _confirmStartTime();
                            } else {
                              _syncPendingFromStartTime();
                              _startTimePickerExpanded = true;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "Start time",
                                style: AppTypography.bodySmall(
                                  context,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayStart.format(context),
                                style: AppTypography.body(context).copyWith(
                                  color: widget.habitColor,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Duration",
                              style: AppTypography.bodySmall(
                                context,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 56,
                                  child: TextField(
                                    controller: _durationController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.body(context).copyWith(
                                      fontSize: 18,
                                      color: widget.habitColor,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '5',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: _onDurationTextChanged,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: widget.durationUnit,
                                  underline: const SizedBox.shrink(),
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: _startTimePickerExpanded
                    ? Column(
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
                                use24hFormat: MediaQuery.of(
                                  context,
                                ).alwaysUse24HourFormat,
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
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- STEP 6: STRATEGY ---
class _Step6Strategy extends StatelessWidget {
  final List<HabitItem> existingHabits;
  final TextEditingController triggerController;
  final TextEditingController actionController;
  final String? afterHabitId;
  final String anchorHabitText;
  final String relationship;
  final bool isEditing;
  final ValueChanged<String?> onAfterHabitIdChanged;
  final ValueChanged<String> onAnchorTextChanged;
  final ValueChanged<String> onRelationshipChanged;

  const _Step6Strategy({
    required this.existingHabits,
    required this.triggerController,
    required this.actionController,
    required this.afterHabitId,
    required this.anchorHabitText,
    required this.relationship,
    required this.onAfterHabitIdChanged,
    required this.onAnchorTextChanged,
    required this.onRelationshipChanged,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Strategy",
          style: AppTypography.bodySmall(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: _kControlSpacing),
        Text(
          "Set yourself up for success.",
          style: AppTypography.caption(context),
        ),
        SizedBox(height: _kControlSpacing),
        // Habit Stacking Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Text(
                    "Habit Stacking",
                    style: AppTypography.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: _kControlSpacing),
              Text(
                "Link this habit to an existing routine",
                style: AppTypography.caption(context),
              ),
              SizedBox(height: _kControlSpacing),

              // Relationship selector
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  dropdownColor: colorScheme.surfaceContainerHighest,
                  value: relationship,
                  isExpanded: true,
                  style: AppTypography.body(context),
                  underline: const SizedBox(),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  items: ['Immediately', 'After', 'Before']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => onRelationshipChanged(v!),
                ),
              ),

              SizedBox(height: _kControlSpacing),

              if (existingHabits.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String?>(
                    value: afterHabitId,
                    hint: Text(
                      "Select an existing habit",
                      style: AppTypography.body(context).copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    dropdownColor: colorScheme.surfaceContainerHighest,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          "None",
                          style: AppTypography.body(
                            context,
                          ).copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      ...existingHabits.map(
                        (h) => DropdownMenuItem(
                          value: h.id,
                          child: Text(
                            h.name,
                            style: AppTypography.body(context),
                          ),
                        ),
                      ),
                    ],
                    onChanged: onAfterHabitIdChanged,
                  ),
                )
              else
                TextField(
                  onChanged: onAnchorTextChanged,
                  style: AppTypography.body(context),
                  decoration: InputDecoration(
                    hintText: "e.g., brushing teeth",
                    hintStyle: AppTypography.body(context).copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
            ],
          ),
        ),

        SizedBox(height: _kControlSpacing),

        // The If-Then Plan (CBT)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Coping Plan",
                    style: AppTypography.body(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: _kControlSpacing),
              Text(
                "Plan ahead for obstacles (If-Then)",
                style: AppTypography.caption(context),
              ),
              SizedBox(height: _kControlSpacing),

              // If field
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: triggerController,
                  style: AppTypography.body(context),
                  decoration: InputDecoration(
                    prefixText: "If ",
                    prefixStyle: AppTypography.body(context).copyWith(
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: "I feel tired...",
                    hintStyle: AppTypography.body(context).copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),

              SizedBox(height: _kControlSpacing),

              // Then field
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: actionController,
                  style: AppTypography.body(context),
                  decoration: InputDecoration(
                    prefixText: "Then I will ",
                    prefixStyle: AppTypography.body(context).copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: "do just 2 minutes.",
                    hintStyle: AppTypography.body(context).copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _kControlSpacing),

        // Encouraging message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text("🎯", style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing
                      ? "You're all set! Tap 'Save Habit' to update your changes."
                      : "You're all set! Tap 'Create Habit' to start your journey.",
                  style: AppTypography.bodySmall(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// UI HELPER WIDGETS
// ============================================================================

class _GlassTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _GlassTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  State<_GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<_GlassTile>
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
        scale: Tween<double>(begin: 1.0, end: 0.98).animate(_controller),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.body(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppTypography.caption(context),
                    ),
                  ],
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniOptionButton extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MiniOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_MiniOptionButton> createState() => _MiniOptionButtonState();
}

class _MiniOptionButtonState extends State<_MiniOptionButton>
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
        scale: Tween<double>(begin: 1.0, end: 0.95).animate(_controller),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: widget.selected ? 0 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: AppTypography.bodySmall(context).copyWith(
              color: widget.selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
