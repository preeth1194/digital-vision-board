import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/cbt_enhancements.dart';
import '../../models/habit_item.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../dialogs/add_habit_dialog.dart';

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

final List<(String, List<Color>)> _habitColors = [
  ('Blue', [AppColors.medium, AppColors.dark]),
  ('Sky', [AppColors.lightest, AppColors.light]),
  ('Purple', [const Color(0xFFA78BFA), const Color(0xFF7C3AED)]),
  ('Indigo', [const Color(0xFF818CF8), const Color(0xFF4F46E5)]),
  ('Cyan', [const Color(0xFF22D3EE), const Color(0xFF0891B2)]),
  ('Green', [const Color(0xFF4ADE80), const Color(0xFF16A34A)]),
  ('Emerald', [const Color(0xFF34D399), const Color(0xFF059669)]),
  ('Amber', [const Color(0xFFFBBF24), const Color(0xFFD97706)]),
  ('Orange', [const Color(0xFFFB923C), const Color(0xFFEA580C)]),
  ('Pink', [const Color(0xFFF472B6), const Color(0xFFDB2777)]),
];

const List<({String value, String label, IconData icon, String description})>
    _occurrenceOptions = [
  (value: 'daily', label: 'Daily', icon: Icons.sunny, description: 'Every day'),
  (value: 'weekdays', label: 'Specific Days', icon: Icons.calendar_view_week_rounded, description: 'Select days'),
  (value: 'interval', label: 'Interval', icon: Icons.repeat_rounded, description: 'Every X days'),
];

// ============================================================================
// Main Entry Function
// ============================================================================

/// Shows the Add Habit modal with a slide-in animation from the right.
/// Returns a [HabitCreateRequest] if the user creates a habit, null otherwise.
Future<HabitCreateRequest?> showAddHabitModal(
  BuildContext context, {
  required List<HabitItem> existingHabits,
  HabitItem? initialHabit,
}) {
  return Navigator.of(context).push<HabitCreateRequest?>(
    PageRouteBuilder<HabitCreateRequest?>(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _CreateHabitWizard(
          existingHabits: existingHabits,
          initialHabit: initialHabit,
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
// Main Wizard Widget
// ============================================================================

class _CreateHabitWizard extends StatefulWidget {
  final List<HabitItem> existingHabits;
  final HabitItem? initialHabit;

  const _CreateHabitWizard({
    required this.existingHabits,
    this.initialHabit,
  });

  @override
  State<_CreateHabitWizard> createState() => _CreateHabitWizardState();
}

class _CreateHabitWizardState extends State<_CreateHabitWizard> 
    with TickerProviderStateMixin {
  // Navigation State
  int _currentStep = 0;
  final int _totalSteps = 6;
  
  // Slide animation controller
  AnimationController? _slideController;
  Animation<Offset>? _slideAnimation;
  bool _isAnimating = false;
  int _displayedStep = 0;

  // --- FORM DATA STATE ---

  // Step 1: Identity
  final TextEditingController _habitNameController = TextEditingController();
  int _selectedIconIndex = 0;

  // Step 2: Aesthetics
  int _selectedColorIndex = 0;

  // Step 3: Rhythm (Frequency)
  String _occurrenceType = 'daily';
  final Set<int> _weekdays = {};
  int _intervalDays = 1;

  // Step 4: Triggers (Time & Location)
  TimeOfDay? _selectedTime;
  bool _reminderEnabled = false;
  TimeOfDay? _reminderTime;
  
  // Location Data
  bool _locationEnabled = false;
  double? _locationLat;
  double? _locationLng;
  int _locationRadius = 150;
  String _locationTriggerMode = 'arrival';
  int _locationDwellMinutes = 5;

  // Step 5: Pacing (Duration)
  bool _timeBoundEnabled = false;
  int _timeBoundDuration = 15;
  String _timeBoundUnit = 'minutes';

  // Step 6: Strategy (Stacking & CBT)
  String? _afterHabitId;
  String _anchorHabitText = '';
  String _relationship = 'Immediately';
  
  // Strategy Card (CBT)
  final TextEditingController _triggerController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = _createSlideAnimation(Offset.zero, Offset.zero);
    
    // Pre-populate fields if editing an existing habit
    _initializeFromHabit();
  }
  
  void _initializeFromHabit() {
    final habit = widget.initialHabit;
    if (habit == null) return;
    
    // Step 1: Identity
    _habitNameController.text = habit.name;
    // Try to find matching icon index (default to 0 if not found)
    // Icon is not stored in HabitItem, so keep default
    
    // Step 3: Rhythm (Frequency)
    if (habit.frequency == 'Weekly' || habit.isWeekly) {
      _occurrenceType = 'weekdays';
      // Convert weeklyDays (1=Mon..7=Sun) to our format (0=Mon..6=Sun)
      _weekdays.clear();
      for (final day in habit.weeklyDays) {
        _weekdays.add(day - 1);
      }
    } else {
      _occurrenceType = 'daily';
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
    
    // Step 5: Pacing (Duration)
    final tb = habit.timeBound;
    if (tb != null && tb.enabled) {
      _timeBoundEnabled = true;
      _timeBoundDuration = tb.duration;
      _timeBoundUnit = tb.unit;
    }
    
    // Step 6: Strategy (Stacking)
    final chaining = habit.chaining;
    if (chaining != null && chaining.anchorHabit != null) {
      _afterHabitId = chaining.anchorHabit;
      _relationship = chaining.relationship ?? 'Immediately';
      // Try to find the anchor habit name
      final anchor = widget.existingHabits.where((h) => h.id == chaining.anchorHabit).firstOrNull;
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
    // Parse formats like "07:00 AM" or "14:30"
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
  
  Animation<Offset> _createSlideAnimation(Offset begin, Offset end) {
    return Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _slideController?.dispose();
    _habitNameController.dispose();
    _triggerController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  // --- Navigation Logic with Slide Animation ---

  Future<void> _animateToStep(int newStep) async {
    if (_isAnimating || newStep == _currentStep) return;
    if (newStep < 0 || newStep >= _totalSteps) return;
    if (_slideController == null) return;
    
    _isAnimating = true;
    final goingForward = newStep > _currentStep;
    
    // Set up slide out animation
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(goingForward ? -1.0 : 1.0, 0),
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeInOutCubic,
    ));
    
    // Slide out current step
    await _slideController!.forward();
    
    // Update step
    setState(() {
      _currentStep = newStep;
      _displayedStep = newStep;
    });
    
    // Reset and set up slide in animation
    _slideController!.reset();
    _slideAnimation = Tween<Offset>(
      begin: Offset(goingForward ? 1.0 : -1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    ));
    
    // Slide in new step
    await _slideController!.forward();
    
    _isAnimating = false;
  }

  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      HapticFeedback.selectionClick();
      _animateToStep(_currentStep + 1);
    } else {
      _handleCommit();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      HapticFeedback.selectionClick();
      _animateToStep(_currentStep - 1);
    } else {
      Navigator.pop(context);
    }
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
    if (_triggerController.text.isNotEmpty || _actionController.text.isNotEmpty) {
      cbtEnhancements = CbtEnhancements(
        predictedObstacle: _triggerController.text.trim(),
        ifThenPlan: _actionController.text.trim(),
      );
    }

    // 2. Build TimeBound
    HabitTimeBoundSpec? timeBound;
    if (_timeBoundEnabled) {
      timeBound = HabitTimeBoundSpec(
        enabled: true,
        duration: _timeBoundDuration,
        unit: _timeBoundUnit,
      );
    }

    // 3. Build Chaining
    HabitChaining? chaining;
    if (_anchorHabitText.isNotEmpty || _afterHabitId != null) {
      chaining = HabitChaining(
        anchorHabit: _anchorHabitText.trim().isEmpty ? null : _anchorHabitText.trim(),
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
        dwellMinutes: _locationTriggerMode == 'dwell' ? _locationDwellMinutes : null,
      );
    }

    // 5. Calc Reminder
    int? reminderMins;
    if (_reminderEnabled && _reminderTime != null) {
      reminderMins = _reminderTime!.hour * 60 + _reminderTime!.minute;
    }

    // 6. Create Request
    final request = HabitCreateRequest(
      name: habitName,
      frequency: _mapFrequency(),
      weeklyDays: _mapWeeklyDays(),
      deadline: null,
      afterHabitId: _afterHabitId,
      timeOfDay: _selectedTime != null ? _formatTimeOfDay(_selectedTime!) : null,
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
    switch (_occurrenceType) {
      case 'daily': return 'Daily';
      case 'weekdays': 
      case 'interval': return 'Weekly';
      default: return null;
    }
  }

  List<int> _mapWeeklyDays() {
    if (_occurrenceType == 'weekdays') {
      return _weekdays.map((d) => d + 1).toList()..sort();
    }
    return [];
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildCurrentStep() {
    switch (_displayedStep) {
      case 0:
        return _Step1Identity(
          nameController: _habitNameController,
          selectedIconIndex: _selectedIconIndex,
          onIconSelected: (i) => setState(() => _selectedIconIndex = i),
        );
      case 1:
        return _Step2Aesthetics(
          selectedColorIndex: _selectedColorIndex,
          selectedIconIndex: _selectedIconIndex,
          habitName: _habitNameController.text.isNotEmpty 
              ? _habitNameController.text 
              : _habitIcons[_selectedIconIndex].$2,
          onColorSelected: (i) => setState(() => _selectedColorIndex = i),
        );
      case 2:
        return _Step3Rhythm(
          occurrenceType: _occurrenceType,
          weekdays: _weekdays,
          intervalDays: _intervalDays,
          onTypeChanged: (v) => setState(() => _occurrenceType = v),
          onWeekdayToggled: (day) => setState(() {
            if (_weekdays.contains(day)) _weekdays.remove(day);
            else _weekdays.add(day);
          }),
          onIntervalChanged: (v) => setState(() => _intervalDays = v),
        );
      case 3:
        return _Step4Triggers(
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
             if(t != null && _reminderTime == null) _reminderTime = t;
          }),
          onReminderToggle: (v) => setState(() => _reminderEnabled = v),
          onReminderTimeChanged: (t) => setState(() => _reminderTime = t),
          onLocationToggle: (v) => setState(() => _locationEnabled = v),
          onLocationSelected: (lat, lng) => setState(() {
            _locationLat = lat;
            _locationLng = lng;
          }),
          onRadiusChanged: (v) => setState(() => _locationRadius = v),
          onTriggerModeChanged: (v) => setState(() => _locationTriggerMode = v),
          onDwellMinutesChanged: (v) => setState(() => _locationDwellMinutes = v),
        );
      case 4:
        return _Step5Pacing(
          timeBoundEnabled: _timeBoundEnabled,
          duration: _timeBoundDuration,
          unit: _timeBoundUnit,
          onToggle: (v) => setState(() => _timeBoundEnabled = v),
          onDurationChanged: (v) => setState(() => _timeBoundDuration = v),
          onUnitChanged: (v) => setState(() => _timeBoundUnit = v),
        );
      case 5:
        return _Step6Strategy(
          existingHabits: widget.existingHabits,
          triggerController: _triggerController,
          actionController: _actionController,
          afterHabitId: _afterHabitId,
          anchorHabitText: _anchorHabitText,
          relationship: _relationship,
          isEditing: widget.initialHabit != null,
          onAfterHabitIdChanged: (v) => setState(() => _afterHabitId = v),
          onAnchorTextChanged: (v) => setState(() => _anchorHabitText = v),
          onRelationshipChanged: (v) => setState(() => _relationship = v),
        );
      default:
        return const SizedBox();
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      backgroundColor: colorScheme.surface, 
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [colorScheme.surface, colorScheme.surfaceContainerHighest, AppColors.medium.withValues(alpha: 0.3)]
                : [colorScheme.surface, colorScheme.surfaceContainerLow, AppColors.light.withValues(alpha: 0.3)],
          ),
        ),
        child: Column(
          children: [
            // 1. Header with Progress Bar (SafeArea for top only)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  children: [
                    // Step indicator text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Step ${_currentStep + 1} of $_totalSteps",
                          style: AppTypography.caption(context),
                        ),
                        Text(
                          _getStepTitle(_currentStep),
                          style: AppTypography.caption(context).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(
                        begin: 0, 
                        end: (_currentStep + 1) / _totalSteps
                      ),
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Main Content with Slide Animation
            Expanded(
              child: _slideAnimation != null
                  ? SlideTransition(
                      position: _slideAnimation!,
                      child: _buildCurrentStep(),
                    )
                  : _buildCurrentStep(),
            ),

            // 3. Navigation Bar (pinned at bottom)
            Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding > 0 ? bottomPadding : 16),
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
                  // Back button (always enabled)
                  TextButton.icon(
                    onPressed: _prevPage,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                    ),
                    label: const Text("Back"),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  
                  const Spacer(),

                  // Next/Create button
                  ElevatedButton.icon(
                    onPressed: _isAnimating ? null : _nextPage,
                    icon: _currentStep == _totalSteps - 1 
                        ? const Icon(Icons.check_rounded, size: 20)
                        : const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(
                      _currentStep == _totalSteps - 1 
                          ? (widget.initialHabit != null ? "Save Habit" : "Create Habit")
                          : "Next",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getStepTitle(int step) {
    switch (step) {
      case 0: return "Identity";
      case 1: return "Aesthetics";
      case 2: return "Rhythm";
      case 3: return "Triggers";
      case 4: return "Pacing";
      case 5: return "Strategy";
      default: return "";
    }
  }
}

// ============================================================================
// STEP WIDGETS
// ============================================================================

// --- STEP 1: IDENTITY ---
class _Step1Identity extends StatelessWidget {
  final TextEditingController nameController;
  final int selectedIconIndex;
  final ValueChanged<int> onIconSelected;

  const _Step1Identity({
    required this.nameController,
    required this.selectedIconIndex,
    required this.onIconSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            "What is your new ritual?", 
            style: AppTypography.heading2(context),
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 8),
          Text(
            "Name it to claim it.", 
            style: AppTypography.secondary(context),
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 32),
          
          TextField(
            controller: nameController,
            style: AppTypography.body(context),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: "e.g., Morning Meditation",
              hintStyle: AppTypography.body(context).copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), 
                borderSide: BorderSide.none
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
          const SizedBox(height: 32),
          
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Choose an Icon", 
              style: AppTypography.bodySmall(context).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, 
              mainAxisSpacing: 12, 
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: _habitIcons.length,
            itemBuilder: (ctx, index) => _AnimatedIconTile(
              icon: _habitIcons[index].$1,
              label: _habitIcons[index].$2,
              isSelected: selectedIconIndex == index,
              onTap: () => onIconSelected(index),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Animated Icon Tile with micro-interactions
class _AnimatedIconTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedIconTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
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
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.isSelected 
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected 
                  ? colorScheme.primary 
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected ? [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.isSelected 
                      ? colorScheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isSelected 
                      ? colorScheme.primary 
                      : colorScheme.onSurfaceVariant,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: AppTypography.caption(context).copyWith(
                  color: widget.isSelected 
                      ? colorScheme.primary 
                      : colorScheme.onSurfaceVariant,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- STEP 2: AESTHETICS ---
class _Step2Aesthetics extends StatelessWidget {
  final int selectedColorIndex;
  final int selectedIconIndex;
  final String habitName;
  final ValueChanged<int> onColorSelected;

  const _Step2Aesthetics({
    required this.selectedColorIndex,
    required this.selectedIconIndex,
    required this.habitName,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = _habitColors[selectedColorIndex].$2;
    final icon = _habitIcons[selectedIconIndex].$1;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            "Set the Vibe", 
            style: AppTypography.heading2(context),
          ),
          const SizedBox(height: 8),
          Text(
            "Choose a color that inspires you.", 
            style: AppTypography.secondary(context),
          ),
          const SizedBox(height: 32),
          
          // Preview Card with animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 400),
            tween: Tween(begin: 0.95, end: 1.0),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Container(
              height: 130,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors, 
                  begin: Alignment.topLeft, 
                  end: Alignment.bottomRight
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.4), 
                    blurRadius: 20, 
                    offset: const Offset(0, 8)
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24), 
                      borderRadius: BorderRadius.circular(14)
                    ),
                    child: Icon(icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          habitName, 
                          style: AppTypography.heading3(context).copyWith(color: Colors.white), 
                          overflow: TextOverflow.ellipsis
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Daily Ritual", 
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8))
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Pick a Color Theme", 
              style: AppTypography.bodySmall(context).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, 
              mainAxisSpacing: 12, 
              crossAxisSpacing: 12
            ),
            itemCount: _habitColors.length,
            itemBuilder: (ctx, index) => _AnimatedColorTile(
              colors: _habitColors[index].$2,
              isSelected: selectedColorIndex == index,
              onTap: () => onColorSelected(index),
            ),
          ),
          const SizedBox(height: 24),
        ],
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
              )
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

// --- STEP 3: RHYTHM ---
class _Step3Rhythm extends StatelessWidget {
  final String occurrenceType;
  final Set<int> weekdays;
  final int intervalDays;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int> onWeekdayToggled;
  final ValueChanged<int> onIntervalChanged;

  const _Step3Rhythm({
    required this.occurrenceType,
    required this.weekdays,
    required this.intervalDays,
    required this.onTypeChanged,
    required this.onWeekdayToggled,
    required this.onIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            "Define the Rhythm", 
            style: AppTypography.heading2(context),
          ),
          const SizedBox(height: 8),
          Text(
            "Consistency builds momentum.", 
            style: AppTypography.secondary(context),
          ),
          const SizedBox(height: 32),

          // Option Cards
          ..._occurrenceOptions.map((opt) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AnimatedOptionCard(
              icon: opt.icon,
              label: opt.label,
              description: opt.description,
              isSelected: occurrenceType == opt.value,
              onTap: () => onTypeChanged(opt.value),
            ),
          )),

          // Logic for Weekdays
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: occurrenceType == 'weekdays' ? Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    "Select Days", 
                    style: AppTypography.bodySmall(context).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final days = ['M','T','W','T','F','S','S'];
                      final selected = weekdays.contains(index);
                      return _AnimatedDayChip(
                        label: days[index],
                        isSelected: selected,
                        onTap: () => onWeekdayToggled(index),
                      );
                    }),
                  ),
                ],
              ),
            ) : const SizedBox.shrink(),
          ),
          
          // Logic for Interval
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: occurrenceType == 'interval' ? Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AnimatedIconButton(
                    icon: Icons.remove_rounded,
                    onTap: () => onIntervalChanged(intervalDays > 1 ? intervalDays - 1 : 1),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    children: [
                      Text(
                        "$intervalDays", 
                        style: AppTypography.heading1(context).copyWith(
                          fontSize: 48,
                        ),
                      ),
                      Text(
                        intervalDays == 1 ? "day" : "days",
                        style: AppTypography.secondary(context),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  _AnimatedIconButton(
                    icon: Icons.add_rounded,
                    onTap: () => onIntervalChanged(intervalDays + 1),
                  ),
                ],
              ),
            ) : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
        ],
      ),
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
                  color: widget.isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant
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
                        color: widget.isSelected ? colorScheme.primary : colorScheme.onSurface,
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
              if(widget.isSelected) 
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
  final VoidCallback onTap;

  const _AnimatedDayChip({
    required this.label,
    required this.isSelected,
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
            color: widget.isSelected ? colorScheme.primary : colorScheme.surfaceContainerHigh,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected ? colorScheme.primary : colorScheme.outlineVariant,
              width: widget.isSelected ? 0 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label, 
            style: AppTypography.bodySmall(context).copyWith(
              color: widget.isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
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

  const _AnimatedIconButton({
    required this.icon,
    required this.onTap,
  });

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            "Set Triggers", 
            style: AppTypography.heading2(context),
          ),
          const SizedBox(height: 8),
          Text(
            "When and where do you want to be reminded?", 
            style: AppTypography.secondary(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Time Picker
          _GlassTile(
            icon: Icons.access_time_rounded,
            title: selectedTime == null ? "Set Start Time" : selectedTime!.format(context),
            subtitle: "When do you want to start?",
            trailing: selectedTime != null 
                ? Icon(Icons.check_circle, color: colorScheme.primary, size: 20)
                : null,
            onTap: () async {
              final t = await showTimePicker(
                context: context, 
                initialTime: selectedTime ?? TimeOfDay.now(),
              );
              if(t != null) onTimeChanged(t);
            },
          ),
          const SizedBox(height: 16),

          // Reminder Switch
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              title: Text(
                "Send Notification", 
                style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                "Get reminded when it's time",
                style: AppTypography.caption(context),
              ),
              secondary: Icon(Icons.notifications_outlined, color: colorScheme.onSurfaceVariant),
              value: reminderEnabled,
              onChanged: onReminderToggle,
              activeColor: colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: reminderEnabled ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _GlassTile(
                icon: Icons.alarm,
                title: reminderTime == null ? "Pick reminder time" : "Alert at ${reminderTime!.format(context)}",
                subtitle: "When should we notify you?",
                onTap: () async {
                  final t = await showTimePicker(
                    context: context, 
                    initialTime: reminderTime ?? selectedTime ?? TimeOfDay.now(),
                  );
                  if(t != null) onReminderTimeChanged(t);
                },
              ),
            ) : const SizedBox.shrink(),
          ),
          
          const SizedBox(height: 24),
          Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),

          // Location
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              title: Text(
                "Location Trigger", 
                style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                locationEnabled && lat != null 
                    ? "Location set" 
                    : "Remind me when I arrive somewhere",
                style: AppTypography.caption(context),
              ),
              secondary: Icon(Icons.location_on_outlined, color: colorScheme.onSurfaceVariant),
              value: locationEnabled,
              onChanged: (val) async {
                if (val) {
                  try {
                    LocationPermission p = await Geolocator.checkPermission();
                    if(p == LocationPermission.denied) {
                      p = await Geolocator.requestPermission();
                    }
                    if(p == LocationPermission.whileInUse || p == LocationPermission.always) {
                      final pos = await Geolocator.getCurrentPosition();
                      onLocationSelected(pos.latitude, pos.longitude);
                      onLocationToggle(true);
                    }
                  } catch(e) { 
                    debugPrint('Location error: $e'); 
                  }
                } else {
                  onLocationToggle(false);
                }
              },
              activeColor: colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: locationEnabled && lat != null ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Trigger Mode",
                      style: AppTypography.bodySmall(context).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniOptionButton(
                            label: "On Arrival",
                            selected: triggerMode == 'arrival',
                            onTap: () => onTriggerModeChanged('arrival'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniOptionButton(
                            label: "After Dwell",
                            selected: triggerMode == 'dwell',
                            onTap: () => onTriggerModeChanged('dwell'),
                          ),
                        ),
                      ],
                    ),
                    if (triggerMode == 'dwell') ...[
                      const SizedBox(height: 16),
                      Text(
                        "Dwell time: $dwellMinutes minutes",
                        style: AppTypography.caption(context),
                      ),
                      Slider(
                        value: dwellMinutes.toDouble(),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        activeColor: colorScheme.primary,
                        inactiveColor: colorScheme.outlineVariant,
                        onChanged: (v) => onDwellMinutesChanged(v.round()),
                      ),
                    ],
                  ],
                ),
              ),
            ) : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// --- STEP 5: PACING ---
class _Step5Pacing extends StatelessWidget {
  final bool timeBoundEnabled;
  final int duration;
  final String unit;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<String> onUnitChanged;

  const _Step5Pacing({
    required this.timeBoundEnabled,
    required this.duration,
    required this.unit,
    required this.onToggle,
    required this.onDurationChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            "Pacing & Flow", 
            style: AppTypography.heading2(context),
          ),
          const SizedBox(height: 8),
          Text(
            "How long should this habit take?", 
            style: AppTypography.secondary(context),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined, 
                          color: timeBoundEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Timer Mode", 
                          style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Switch(
                      value: timeBoundEnabled, 
                      onChanged: onToggle, 
                      activeColor: colorScheme.primary
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: timeBoundEnabled ? Column(
                    children: [
                      const SizedBox(height: 24),
                      Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _AnimatedIconButton(
                            icon: Icons.remove_rounded,
                            onTap: () => onDurationChanged(duration > 5 ? duration - 5 : 5),
                          ),
                          const SizedBox(width: 24),
                          Column(
                            children: [
                              Text(
                                "$duration", 
                                style: AppTypography.heading1(context).copyWith(
                                  fontSize: 56,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          _AnimatedIconButton(
                            icon: Icons.add_rounded,
                            onTap: () => onDurationChanged(duration + 5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Unit selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MiniOptionButton(
                            label: "Minutes",
                            selected: unit == 'minutes',
                            onTap: () => onUnitChanged('minutes'),
                          ),
                          const SizedBox(width: 12),
                          _MiniOptionButton(
                            label: "Songs",
                            selected: unit == 'songs',
                            onTap: () => onUnitChanged('songs'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        unit == 'songs' 
                            ? "Complete after $duration songs" 
                            : "Focus for $duration minutes",
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ) : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: !timeBoundEnabled ? Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Without a timer, you'll mark this habit complete manually.",
                        style: AppTypography.caption(context),
                      ),
                    ),
                  ],
                ),
              ),
            ) : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
        ],
      ),
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
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            "Success Strategy", 
            style: AppTypography.heading2(context),
          ),
          const SizedBox(height: 8),
          Text(
            "Set yourself up for success.", 
            style: AppTypography.secondary(context),
          ),
          const SizedBox(height: 32),

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
                      style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Link this habit to an existing routine",
                  style: AppTypography.caption(context),
                ),
                const SizedBox(height: 16),
                
                // Relationship selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurfaceVariant),
                    items: ['Immediately', 'After', 'Before']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => onRelationshipChanged(v!),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                if (existingHabits.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String?>(
                      value: afterHabitId,
                      hint: Text(
                        "Select an existing habit", 
                        style: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      dropdownColor: colorScheme.surfaceContainerHighest,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.onSurfaceVariant),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null, 
                          child: Text("None", style: AppTypography.body(context).copyWith(
                            color: colorScheme.onSurfaceVariant,
                          )),
                        ),
                        ...existingHabits.map((h) => DropdownMenuItem(
                          value: h.id, 
                          child: Text(h.name, style: AppTypography.body(context)),
                        )),
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
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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

          const SizedBox(height: 20),

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
                    Icon(Icons.psychology_outlined, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text(
                      "Coping Plan", 
                      style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Plan ahead for obstacles (If-Then)",
                  style: AppTypography.caption(context),
                ),
                const SizedBox(height: 16),
                
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
                        fontWeight: FontWeight.bold
                      ),
                      hintText: "I feel tired...",
                      hintStyle: AppTypography.body(context).copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
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
                        fontWeight: FontWeight.bold
                      ),
                      hintText: "do just 2 minutes.",
                      hintStyle: AppTypography.body(context).copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
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
          const SizedBox(height: 24),
        ],
      ),
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
    required this.onTap
  });

  @override
  State<_GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<_GlassTile> with SingleTickerProviderStateMixin {
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
            borderRadius: BorderRadius.circular(16)
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
                      style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600),
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
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
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
            color: widget.selected ? colorScheme.primary : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.selected ? colorScheme.primary : colorScheme.outlineVariant,
              width: widget.selected ? 0 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: AppTypography.bodySmall(context).copyWith(
              color: widget.selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
