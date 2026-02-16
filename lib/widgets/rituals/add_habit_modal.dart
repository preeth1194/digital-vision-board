import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/cbt_enhancements.dart';
import '../../models/habit_item.dart';
import '../../utils/app_typography.dart';
import 'addon_tools_section.dart';
import 'habit_form_constants.dart';
import 'habit_form_identity_section.dart';
import 'habit_form_pacing_section.dart';
import 'habit_form_strategy_section.dart';
import 'habit_form_triggers_section.dart';

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

  const _CreateHabitPage({
    required this.existingHabits,
    this.initialHabit,
    this.initialName,
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
      return habitColors[i];
    });
  }

  /// Icons filtered by current category. Returns (globalIndex, IconData, label).
  /// When category is null, returns all icons. When set, returns only icons for that category.
  List<(int, IconData, String)> get _iconsForCurrentCategory {
    if (_category == null) {
      return List.generate(
        habitIcons.length,
        (i) => (i, habitIcons[i].$1, habitIcons[i].$2),
      );
    }
    final indices = categoryToIconIndices[_category];
    if (indices == null || indices.isEmpty) {
      return List.generate(
        habitIcons.length,
        (i) => (i, habitIcons[i].$1, habitIcons[i].$2),
      );
    }
    return indices
        .map((i) => (i, habitIcons[i].$1, habitIcons[i].$2))
        .toList();
  }

  // Rhythm (Frequency) - all 7 days selected by default (daily logic)
  final Set<int> _weekdays = {0, 1, 2, 3, 4, 5, 6};

  // Addon tools
  bool _remindersAddonAdded = false;
  bool _timerAddonAdded = false;

  // Validation errors
  String? _nameError;
  String? _triggerError;
  String? _actionError;
  String? _anchorHabitError;

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
  bool _habitStackingEnabled = false;
  String? _afterHabitId;
  String _anchorHabitText = '';
  String _relationship = 'Before';

  final TextEditingController _triggerController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();

  // Commitment / Deadline
  // One of: '21', '66', '90', 'none', 'custom', 'goal'
  String _selectedMilestone = 'none';
  DateTime? _customDeadlineDate;
  bool _milestoneExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null &&
        widget.initialName!.trim().isNotEmpty &&
        widget.initialHabit == null) {
      _habitNameController.text = widget.initialName!.trim();
    }
    _initializeFromHabit();
    // Default start time when creating new habit
    if (_timeBoundStartTime == null) {
      _timeBoundStartTime = TimeOfDay.now();
    }

    _habitNameController.addListener(_clearNameError);
    _triggerController.addListener(_clearTriggerError);
    _actionController.addListener(_clearActionError);
  }

  void _clearNameError() {
    if (_nameError != null) setState(() => _nameError = null);
  }

  void _clearTriggerError() {
    if (_triggerError != null) setState(() => _triggerError = null);
  }

  void _clearActionError() {
    if (_actionError != null) setState(() => _actionError = null);
  }

  void _initializeFromHabit() {
    final habit = widget.initialHabit;
    if (habit == null) return;

    // Identity
    _habitNameController.text = habit.name;
    _category = habit.category;
    if (_category != null) {
      final indices = categoryToIconIndices[_category];
      if (indices != null &&
          indices.isNotEmpty &&
          !indices.contains(_selectedIconIndex)) {
        _selectedIconIndex = indices.first;
      }
    }

    // Deadline -> reverse-map to milestone
    if (habit.deadline != null && habit.deadline!.trim().isNotEmpty) {
      final deadlineStr = habit.deadline!.trim();
      final deadlineDate = DateTime.tryParse(deadlineStr);
      if (deadlineDate != null) {
        final daysFromNow = deadlineDate.difference(DateTime.now()).inDays;
        // Check if it matches a milestone preset (within +/- 2 day tolerance)
        if ((daysFromNow - 21).abs() <= 2) {
          _selectedMilestone = '21';
        } else if ((daysFromNow - 66).abs() <= 2) {
          _selectedMilestone = '66';
        } else if ((daysFromNow - 90).abs() <= 2) {
          _selectedMilestone = '90';
        } else {
          _selectedMilestone = 'custom';
          _customDeadlineDate = deadlineDate;
        }
      } else {
        _selectedMilestone = 'custom';
      }
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
      if (kReminderMinutesBeforeOptions.contains(before)) {
        _reminderMinutesBefore = before;
      } else {
        _reminderMinutesBefore = 15;
      }
    }

    // Auto-enable reminders addon if the habit has any trigger data
    if (_reminderEnabled || _locationEnabled) {
      _remindersAddonAdded = true;
    }
    // Auto-enable timer addon if the habit has start time / duration
    if (_timeBoundStartTime != null) {
      _timerAddonAdded = true;
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

  Future<void> _pickCustomDeadline() async {
    final now = DateTime.now();
    final initial = _customDeadlineDate ?? now.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customDeadlineDate = picked;
      _selectedMilestone = 'custom';
    });
  }

  @override
  void dispose() {
    _habitNameController.removeListener(_clearNameError);
    _triggerController.removeListener(_clearTriggerError);
    _actionController.removeListener(_clearActionError);
    _habitNameController.dispose();
    _triggerController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  // --- Save Logic ---

  void _handleCommit() {
    HapticFeedback.mediumImpact();

    // Validate mandatory fields
    bool hasError = false;

    if (_habitNameController.text.trim().isEmpty) {
      _nameError = 'Please enter a habit name';
      hasError = true;
    }
    if (_triggerController.text.trim().isEmpty) {
      _triggerError = 'Please enter a trigger';
      hasError = true;
    }
    if (_actionController.text.trim().isEmpty) {
      _actionError = 'Please enter a coping action';
      hasError = true;
    }
    if (_habitStackingEnabled && _anchorHabitText.trim().isEmpty) {
      _anchorHabitError = 'Please select or enter a habit';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    final habitName = _habitNameController.text.trim();

    // 1. Build CBT Logic
    CbtEnhancements? cbtEnhancements;
    if (_triggerController.text.isNotEmpty ||
        _actionController.text.isNotEmpty) {
      cbtEnhancements = CbtEnhancements(
        predictedObstacle: _triggerController.text.trim(),
        ifThenPlan: _actionController.text.trim(),
      );
    }

    // 2. Build TimeBound (start time + duration) — only when timer addon is active
    HabitTimeBoundSpec? timeBound;
    if (_timerAddonAdded && _timeBoundStartTime != null && _timeBoundDurationMinutes > 0) {
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

    // 6. Resolve deadline from selected milestone
    String? resolvedDeadline;
    switch (_selectedMilestone) {
      case '21':
      case '66':
      case '90':
        final days = int.parse(_selectedMilestone);
        resolvedDeadline = _toIsoDate(
          DateTime.now().add(Duration(days: days)),
        );
        break;
      case 'custom':
        if (_customDeadlineDate != null) {
          resolvedDeadline = _toIsoDate(_customDeadlineDate!);
        }
        break;
      case 'none':
      default:
        resolvedDeadline = null;
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
      if (_anchorHabitError != null) _anchorHabitError = null;
    });
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
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
                    20,
                    topPadding,
                    20,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Step1IdentityWithColor(
                        colorSectionKey: _colorSectionKey,
                        nameController: _habitNameController,
                        nameError: _nameError,
                        selectedCategory: _category,
                        onCategoryChanged: (v) {
                          setState(() {
                            _category = v;
                            if (v != null) {
                              final indices = categoryToIconIndices[v];
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
                        onColorPickerExpandedChanged: (v) => setState(() {
                          _colorPickerExpanded = v;
                          if (v) _milestoneExpanded = false;
                        }),
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
                        onSectionExpanded: () =>
                            setState(() => _milestoneExpanded = false),
                      ),
                      SizedBox(height: kSectionSpacing),
                      Step5Pacing(
                        habitColor: baseColor,
                        weekdays: _weekdays,
                        onWeekdayToggled: (day) => setState(() {
                          if (_weekdays.contains(day)) {
                            _weekdays.remove(day);
                          } else {
                            _weekdays.add(day);
                          }
                        }),
                      ),
                      SizedBox(height: kSectionSpacing),
                      _buildCopingPlanSection(colorScheme),
                      SizedBox(height: kSectionSpacing),
                      _buildCommitmentSection(colorScheme),
                      SizedBox(height: kSectionSpacing),
                      Step6Strategy(
                        habitColor: baseColor,
                        habitStackingEnabled: _habitStackingEnabled,
                        onHabitStackingToggle: (v) {
                          setState(() {
                            _habitStackingEnabled = v;
                            if (v) _milestoneExpanded = false;
                            if (!v) {
                              _afterHabitId = null;
                              _anchorHabitText = '';
                              _anchorHabitError = null;
                            }
                          });
                        },
                        existingHabits: widget.existingHabits,
                        afterHabitId: _afterHabitId,
                        anchorHabitText: _anchorHabitText,
                        relationship: _relationship,
                        isEditing: widget.initialHabit != null,
                        onAfterHabitIdChanged: _onAfterHabitIdChanged,
                        onAnchorTextChanged: (v) => setState(() {
                          _anchorHabitText = v;
                          if (_anchorHabitError != null) _anchorHabitError = null;
                        }),
                        onRelationshipChanged: (v) =>
                            setState(() => _relationship = v),
                        anchorHabitError: _anchorHabitError,
                      ),
                      SizedBox(height: kSectionSpacing),
                      AddonToolsSection(
                        habitColor: baseColor,
                        remindersAdded: _remindersAddonAdded,
                        onRemindersToggle: (added) {
                          setState(() {
                            _remindersAddonAdded = added;
                            if (!added) {
                              _reminderEnabled = false;
                              _reminderMinutesBefore = null;
                              _reminderTime = null;
                              _selectedTime = null;
                              _locationEnabled = false;
                              _locationLat = null;
                              _locationLng = null;
                            }
                          });
                        },
                        timerAdded: _timerAddonAdded,
                        onTimerToggle: (added) {
                          setState(() {
                            _timerAddonAdded = added;
                            if (!added) {
                              _timeBoundStartTime = null;
                              _timeBoundDurationValue = 15;
                              _timeBoundDurationUnit = 'minutes';
                            }
                          });
                        },
                      ),
                      if (_remindersAddonAdded || _timerAddonAdded) ...[
                        SizedBox(height: kSectionSpacing),
                        Step4Triggers(
                          habitColor: baseColor,
                          showReminderFields: _remindersAddonAdded,
                          showDurationField: _timerAddonAdded,
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
                      ],
                      SizedBox(height: kSectionSpacing),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
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
        'Safety Net',
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: habitSectionDecoration(colorScheme),
      separatorColor: habitSectionSeparatorColor(colorScheme),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'IF',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: colorScheme.tertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _triggerController,
                      style: AppTypography.body(context),
                      decoration: InputDecoration(
                        hintText: "I'm feeling too tired...",
                        hintStyle: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                        errorText: _triggerError,
                        errorStyle: AppTypography.caption(context).copyWith(
                          color: colorScheme.error,
                          fontSize: 11,
                        ),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: _triggerError != null
                                ? colorScheme.error
                                : colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: _triggerError != null
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.only(bottom: 4),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 23),
                child: Container(
                  height: 16,
                  width: 2,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'THEN',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _actionController,
                      style: AppTypography.body(context),
                      decoration: InputDecoration(
                        hintText: "I will just do 2 minutes.",
                        hintStyle: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                        errorText: _actionError,
                        errorStyle: AppTypography.caption(context).copyWith(
                          color: colorScheme.error,
                          fontSize: 11,
                        ),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: _actionError != null
                                ? colorScheme.error
                                : colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: _actionError != null
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.only(bottom: 4),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _milestoneDisplayText() {
    if (_selectedMilestone == 'custom' && _customDeadlineDate != null) {
      return 'Custom: ${_toIsoDate(_customDeadlineDate!)}';
    }
    for (final preset in kMilestonePresets) {
      if (preset.id == _selectedMilestone) {
        final star = preset.isRecommended ? ' \u2B50' : '';
        return '${preset.label} · ${preset.subtitle}$star';
      }
    }
    return 'No End Date';
  }

  Widget _buildMilestoneRow({
    required ColorScheme colorScheme,
    required String id,
    required String label,
    required String subtitle,
    bool isRecommended = false,
    IconData? leadingIcon,
  }) {
    final selected = _selectedMilestone == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedMilestone = id);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 16,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: label,
                  style: AppTypography.body(context).copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                  children: [
                    TextSpan(
                      text: '  $subtitle',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    if (isRecommended)
                      const TextSpan(
                        text: ' \u2B50',
                        style: TextStyle(fontSize: 12),
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

  Widget _buildCommitmentSection(
    ColorScheme colorScheme,
  ) {
    final customDateLabel = _customDeadlineDate != null
        ? _toIsoDate(_customDeadlineDate!)
        : null;

    return CupertinoListSection.insetGrouped(
      header: Text(
        'Mastery Milestone',
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: habitSectionDecoration(colorScheme),
      separatorColor: habitSectionSeparatorColor(colorScheme),
      children: [
        // Collapsed tile - always visible
        CupertinoListTile.notched(
          leading: Icon(
            Icons.timer_outlined,
            color: colorScheme.primary,
            size: 24,
          ),
          title: Text(
            _milestoneDisplayText(),
            style: AppTypography.body(context),
          ),
          trailing: Icon(
            _milestoneExpanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          onTap: () => setState(() {
            _milestoneExpanded = !_milestoneExpanded;
            if (_milestoneExpanded) {
              _colorPickerExpanded = false;
              _customizeExpanded = false;
            }
          }),
        ),
        // Expanded content - list items
        if (_milestoneExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final preset in kMilestonePresets)
                  _buildMilestoneRow(
                    colorScheme: colorScheme,
                    id: preset.id,
                    label: preset.label,
                    subtitle: preset.subtitle,
                    isRecommended: preset.isRecommended,
                  ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: _pickCustomDeadline,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _selectedMilestone == 'custom'
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: _selectedMilestone == 'custom'
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: _selectedMilestone == 'custom'
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            customDateLabel != null
                                ? 'Custom: $customDateLabel'
                                : 'Pick a custom end date',
                            style: AppTypography.body(context).copyWith(
                              color: _selectedMilestone == 'custom'
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                              fontWeight: _selectedMilestone == 'custom'
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_selectedMilestone == 'custom' &&
                            customDateLabel != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _customDeadlineDate = null;
                              _selectedMilestone = 'none';
                            }),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

