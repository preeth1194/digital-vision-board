import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/cbt_enhancements.dart';
import '../../models/habit_item.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../dialogs/add_habit_dialog.dart';

// ============================================================================
// Spacing Constants
// ============================================================================

const double _kSpacingXS = 4;
const double _kSpacingS = 8;
const double _kSpacingM = 12;
const double _kSpacingL = 16;
const double _kSpacingXL = 20;
const double _kSpacingXXL = 24;

const double _kRadiusS = 8;
const double _kRadiusM = 16;
const double _kRadiusL = 20;
const double _kRadiusXL = 24;

// ============================================================================
// Data Models
// ============================================================================

/// Icon options for habits
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

/// Color gradient options for habits
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

/// Occurrence/frequency options (matching routine_editor_screen.dart)
const List<({String value, String label, IconData icon, String description})>
    _occurrenceOptions = [
  (
    value: 'daily',
    label: 'Daily',
    icon: Icons.sunny,
    description: 'Repeat every day'
  ),
  (
    value: 'weekdays',
    label: 'Specific Days',
    icon: Icons.calendar_view_week_rounded,
    description: 'Choose which days'
  ),
  (
    value: 'interval',
    label: 'Custom Interval',
    icon: Icons.repeat_rounded,
    description: 'Every X days'
  ),
];

/// Relationship options for habit chaining
const List<String> _relationshipOptions = ['Immediately', 'After', 'Before'];

// ============================================================================
// Main Entry Function
// ============================================================================

/// Shows the Add Habit modal with a slide-in animation from the right.
/// Returns a [HabitCreateRequest] if the user creates a habit, null otherwise.
Future<HabitCreateRequest?> showAddHabitModal(
  BuildContext context, {
  required List<HabitItem> existingHabits,
}) {
  return Navigator.of(context).push<HabitCreateRequest?>(
    PageRouteBuilder<HabitCreateRequest?>(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AddHabitModal(existingHabits: existingHabits);
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
// Main Modal Widget
// ============================================================================

class _AddHabitModal extends StatefulWidget {
  final List<HabitItem> existingHabits;

  const _AddHabitModal({required this.existingHabits});

  @override
  State<_AddHabitModal> createState() => _AddHabitModalState();
}

class _AddHabitModalState extends State<_AddHabitModal>
    with TickerProviderStateMixin {
  // Current step (1-4)
  int _step = 1;
  static const int _totalSteps = 4;

  // Step 1: Name & Icon
  final _habitNameController = TextEditingController();
  int _selectedIconIndex = 0;

  // Step 2: Color
  int _selectedColorIndex = 0;

  // Step 3: Schedule
  String _occurrenceType = 'daily';
  final Set<int> _weekdays = {}; // 0=Mon..6=Sun for weekday picker
  int _intervalDays = 1;
  TimeOfDay? _selectedTime;
  int? _reminderMinutes;
  bool _reminderEnabled = false;

  // Duration/Timer settings
  bool _timeBoundEnabled = false;
  int _timeBoundDuration = 15;
  String _timeBoundUnit = 'minutes';

  // Habit anchoring
  String? _afterHabitId;
  String _anchorHabitText = '';
  String _relationship = 'Immediately';
  bool _showAnchorSection = false;

  // Step 4: Goals & Coping Plan
  int _targetCount = 1;
  int _coinReward = 50;
  bool _showCopingPlan = false;

  // CBT Fields
  final _microVersionController = TextEditingController();
  final _predictedObstacleController = TextEditingController();
  final _ifThenPlanController = TextEditingController();
  final _rewardController = TextEditingController();
  double _confidence = 8;

  // Animation controllers
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progressAnimation = Tween<double>(begin: 0.25, end: 0.25).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _habitNameController.dispose();
    _microVersionController.dispose();
    _predictedObstacleController.dispose();
    _ifThenPlanController.dispose();
    _rewardController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  double get _progress => _step / _totalSteps;

  void _updateProgress() {
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: _progress,
    ).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
    _progressController.forward(from: 0);
  }

  void _nextStep() {
    if (_step < _totalSteps) {
      setState(() => _step++);
      _updateProgress();
      HapticFeedback.selectionClick();
    }
  }

  void _previousStep() {
    if (_step > 1) {
      setState(() => _step--);
      _updateProgress();
      HapticFeedback.selectionClick();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleSave() {
    HapticFeedback.mediumImpact();

    final habitName = _habitNameController.text.trim().isNotEmpty
        ? _habitNameController.text.trim()
        : _habitIcons[_selectedIconIndex].$2;

    // Build CBT enhancements if any field is filled
    CbtEnhancements? cbtEnhancements;
    final hasCbt = _microVersionController.text.trim().isNotEmpty ||
        _predictedObstacleController.text.trim().isNotEmpty ||
        _ifThenPlanController.text.trim().isNotEmpty ||
        _rewardController.text.trim().isNotEmpty;

    if (hasCbt) {
      cbtEnhancements = CbtEnhancements(
        microVersion: _microVersionController.text.trim().isEmpty
            ? null
            : _microVersionController.text.trim(),
        predictedObstacle: _predictedObstacleController.text.trim().isEmpty
            ? null
            : _predictedObstacleController.text.trim(),
        ifThenPlan: _ifThenPlanController.text.trim().isEmpty
            ? null
            : _ifThenPlanController.text.trim(),
        confidenceScore: _confidence.round(),
        reward: _rewardController.text.trim().isEmpty
            ? null
            : _rewardController.text.trim(),
      );
    }

    // Build timeBound if enabled
    HabitTimeBoundSpec? timeBound;
    if (_timeBoundEnabled) {
      timeBound = HabitTimeBoundSpec(
        enabled: true,
        duration: _timeBoundDuration,
        unit: _timeBoundUnit,
      );
    }

    // Build chaining if anchor is set
    HabitChaining? chaining;
    if (_anchorHabitText.trim().isNotEmpty || _afterHabitId != null) {
      chaining = HabitChaining(
        anchorHabit: _anchorHabitText.trim().isEmpty ? null : _anchorHabitText.trim(),
        relationship: _relationship,
      );
    }

    final request = HabitCreateRequest(
      name: habitName,
      frequency: _mapFrequency(),
      weeklyDays: _mapWeeklyDays(),
      deadline: null,
      afterHabitId: _afterHabitId,
      timeOfDay: _selectedTime != null ? _formatTimeOfDay(_selectedTime!) : null,
      reminderMinutes: _reminderMinutes,
      reminderEnabled: _reminderEnabled,
      chaining: chaining,
      cbtEnhancements: cbtEnhancements,
      timeBound: timeBound,
      locationBound: null,
    );

    Navigator.of(context).pop(request);
  }

  String? _mapFrequency() {
    switch (_occurrenceType) {
      case 'daily':
        return 'Daily';
      case 'weekdays':
      case 'interval':
        return 'Weekly';
      default:
        return null;
    }
  }

  List<int> _mapWeeklyDays() {
    if (_occurrenceType == 'weekdays') {
      // Convert 0=Mon..6=Sun to 1=Mon..7=Sun
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkest, AppColors.dark, AppColors.medium]
                : [AppColors.lightest, AppColors.light, AppColors.medium],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with progress bar
              _buildHeader(context, isDark, colorScheme),
              // Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: _buildStepContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, bool isDark, ColorScheme colorScheme) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: AppColors.darkest.withValues(alpha: isDark ? 0.9 : 0.8),
          padding: const EdgeInsets.fromLTRB(
              _kSpacingL, _kSpacingL, _kSpacingL, _kSpacingM),
          child: Column(
            children: [
              // Back button and title
              Row(
                children: [
                  _AnimatedIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _previousStep,
                  ),
                  Expanded(
                    child: Text(
                      'Create New Habit',
                      style: AppTypography.heading2(context)
                          .copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),
              const SizedBox(height: _kSpacingL),
              // Progress bar
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(_kRadiusS),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progressAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.lightest, Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(_kRadiusS),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: _kSpacingS),
              // Step indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step $_step of $_totalSteps',
                    style: AppTypography.caption(context)
                        .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: AppTypography.caption(context)
                        .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return _Step1NameIcon(
          key: const ValueKey('step1'),
          habitNameController: _habitNameController,
          selectedIconIndex: _selectedIconIndex,
          onIconSelected: (index) =>
              setState(() => _selectedIconIndex = index),
          onNext: _nextStep,
        );
      case 2:
        return _Step2Color(
          key: const ValueKey('step2'),
          selectedColorIndex: _selectedColorIndex,
          selectedIconIndex: _selectedIconIndex,
          habitName: _habitNameController.text.trim().isNotEmpty
              ? _habitNameController.text.trim()
              : _habitIcons[_selectedIconIndex].$2,
          onColorSelected: (index) =>
              setState(() => _selectedColorIndex = index),
          onNext: _nextStep,
          onBack: _previousStep,
        );
      case 3:
        return _Step3Schedule(
          key: const ValueKey('step3'),
          occurrenceType: _occurrenceType,
          weekdays: _weekdays,
          intervalDays: _intervalDays,
          selectedTime: _selectedTime,
          reminderEnabled: _reminderEnabled,
          timeBoundEnabled: _timeBoundEnabled,
          timeBoundDuration: _timeBoundDuration,
          timeBoundUnit: _timeBoundUnit,
          showAnchorSection: _showAnchorSection,
          existingHabits: widget.existingHabits,
          afterHabitId: _afterHabitId,
          anchorHabitText: _anchorHabitText,
          relationship: _relationship,
          onOccurrenceChanged: (type) => setState(() => _occurrenceType = type),
          onWeekdayToggled: (day) {
            setState(() {
              if (_weekdays.contains(day)) {
                _weekdays.remove(day);
              } else {
                _weekdays.add(day);
              }
            });
          },
          onIntervalChanged: (days) => setState(() => _intervalDays = days),
          onTimeSelected: (time) {
            setState(() {
              _selectedTime = time;
              if (time != null) {
                _reminderMinutes = time.hour * 60 + time.minute;
              } else {
                _reminderMinutes = null;
              }
            });
          },
          onReminderToggled: (enabled) =>
              setState(() => _reminderEnabled = enabled),
          onTimeBoundToggled: (enabled) =>
              setState(() => _timeBoundEnabled = enabled),
          onTimeBoundDurationChanged: (duration) =>
              setState(() => _timeBoundDuration = duration),
          onTimeBoundUnitChanged: (unit) =>
              setState(() => _timeBoundUnit = unit),
          onShowAnchorToggled: (show) =>
              setState(() => _showAnchorSection = show),
          onAfterHabitIdChanged: (id) => setState(() => _afterHabitId = id),
          onAnchorHabitTextChanged: (text) =>
              setState(() => _anchorHabitText = text),
          onRelationshipChanged: (rel) => setState(() => _relationship = rel),
          onNext: _nextStep,
          onBack: _previousStep,
        );
      case 4:
        return _Step4Goals(
          key: const ValueKey('step4'),
          targetCount: _targetCount,
          coinReward: _coinReward,
          reminderEnabled: _reminderEnabled,
          habitName: _habitNameController.text.trim().isNotEmpty
              ? _habitNameController.text.trim()
              : _habitIcons[_selectedIconIndex].$2,
          selectedIconIndex: _selectedIconIndex,
          selectedColorIndex: _selectedColorIndex,
          showCopingPlan: _showCopingPlan,
          microVersionController: _microVersionController,
          predictedObstacleController: _predictedObstacleController,
          ifThenPlanController: _ifThenPlanController,
          rewardController: _rewardController,
          confidence: _confidence,
          onTargetChanged: (count) => setState(() => _targetCount = count),
          onCoinRewardChanged: (coins) => setState(() => _coinReward = coins),
          onReminderToggled: (enabled) =>
              setState(() => _reminderEnabled = enabled),
          onShowCopingPlanToggled: (show) =>
              setState(() => _showCopingPlan = show),
          onConfidenceChanged: (conf) => setState(() => _confidence = conf),
          onSave: _handleSave,
          onBack: _previousStep,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ============================================================================
// Step 1: Name & Icon (Enhanced with bounce animations)
// ============================================================================

class _Step1NameIcon extends StatefulWidget {
  final TextEditingController habitNameController;
  final int selectedIconIndex;
  final ValueChanged<int> onIconSelected;
  final VoidCallback onNext;

  const _Step1NameIcon({
    super.key,
    required this.habitNameController,
    required this.selectedIconIndex,
    required this.onIconSelected,
    required this.onNext,
  });

  @override
  State<_Step1NameIcon> createState() => _Step1NameIconState();
}

class _Step1NameIconState extends State<_Step1NameIcon>
    with TickerProviderStateMixin {
  late List<AnimationController> _iconAnimations;
  bool _hasAnimatedEntrance = false;

  @override
  void initState() {
    super.initState();
    _iconAnimations = List.generate(
      _habitIcons.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    // Staggered entrance animation
    _animateEntrance();
  }

  Future<void> _animateEntrance() async {
    if (_hasAnimatedEntrance) return;
    _hasAnimatedEntrance = true;

    for (int i = 0; i < _iconAnimations.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) {
        _iconAnimations[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _iconAnimations) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(_kSpacingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated emoji
          const _WigglingEmoji(emoji: '✨'),
          const SizedBox(height: _kSpacingL),
          // Title
          Text(
            "What's your new habit?",
            style:
                AppTypography.heading2(context).copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingS),
          Text(
            'Give it a name and choose an icon',
            style: AppTypography.bodySmall(context)
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingXXL),
          // Name input
          Text(
            'Habit Name',
            style: AppTypography.body(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: _kSpacingM),
          TextField(
            controller: widget.habitNameController,
            style: AppTypography.body(context).copyWith(
              color: AppColors.dark,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., Morning Meditation',
              hintStyle: AppTypography.body(context).copyWith(
                color: AppColors.medium.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: colorScheme.surface.withValues(alpha: 0.9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kRadiusM),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: _kSpacingXXL,
                vertical: _kSpacingL,
              ),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: _kSpacingXXL),
          // Icon selection
          Text(
            'Choose an Icon',
            style: AppTypography.body(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: _kSpacingM),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: _kSpacingM,
              crossAxisSpacing: _kSpacingM,
            ),
            itemCount: _habitIcons.length,
            itemBuilder: (context, index) {
              final isSelected = widget.selectedIconIndex == index;
              final icon = _habitIcons[index].$1;
              return AnimatedBuilder(
                animation: _iconAnimations[index],
                builder: (context, child) {
                  final scale = Curves.elasticOut
                      .transform(_iconAnimations[index].value);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: _BounceSelectableIconButton(
                  icon: icon,
                  isSelected: isSelected,
                  onTap: () => widget.onIconSelected(index),
                ),
              );
            },
          ),
          const SizedBox(height: _kSpacingXXL + _kSpacingL),
          // Next button
          _PrimaryButton(
            label: 'Next Step →',
            onTap: widget.onNext,
            enabled: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Step 2: Color Selection (Enhanced with shimmer preview)
// ============================================================================

class _Step2Color extends StatefulWidget {
  final int selectedColorIndex;
  final int selectedIconIndex;
  final String habitName;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2Color({
    super.key,
    required this.selectedColorIndex,
    required this.selectedIconIndex,
    required this.habitName,
    required this.onColorSelected,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step2Color> createState() => _Step2ColorState();
}

class _Step2ColorState extends State<_Step2Color>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedColors = _habitColors[widget.selectedColorIndex].$2;
    final selectedIcon = _habitIcons[widget.selectedIconIndex].$1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(_kSpacingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated emoji
          const _WigglingEmoji(emoji: '🎨', rotates: true),
          const SizedBox(height: _kSpacingL),
          // Title
          Text(
            'Pick a color theme',
            style:
                AppTypography.heading2(context).copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingS),
          Text(
            'Choose a color that inspires you',
            style: AppTypography.bodySmall(context)
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingXXL),
          // Preview card with shimmer
          _ShimmerPreviewCard(
            habitName: widget.habitName,
            icon: selectedIcon,
            gradientColors: selectedColors,
            shimmerController: _shimmerController,
          ),
          const SizedBox(height: _kSpacingXXL),
          // Color grid
          Text(
            'Select Color',
            style: AppTypography.body(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: _kSpacingM),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: _kSpacingM,
              crossAxisSpacing: _kSpacingM,
            ),
            itemCount: _habitColors.length,
            itemBuilder: (context, index) {
              final isSelected = widget.selectedColorIndex == index;
              final colors = _habitColors[index].$2;
              return _BounceSelectableColorButton(
                colors: colors,
                isSelected: isSelected,
                onTap: () => widget.onColorSelected(index),
              );
            },
          ),
          const SizedBox(height: _kSpacingXXL + _kSpacingL),
          // Navigation buttons
          _NavigationButtons(
            onBack: widget.onBack,
            onNext: widget.onNext,
            nextLabel: 'Next Step →',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Step 3: Schedule (Enhanced with routine-style pickers)
// ============================================================================

class _Step3Schedule extends StatelessWidget {
  final String occurrenceType;
  final Set<int> weekdays;
  final int intervalDays;
  final TimeOfDay? selectedTime;
  final bool reminderEnabled;
  final bool timeBoundEnabled;
  final int timeBoundDuration;
  final String timeBoundUnit;
  final bool showAnchorSection;
  final List<HabitItem> existingHabits;
  final String? afterHabitId;
  final String anchorHabitText;
  final String relationship;
  final ValueChanged<String> onOccurrenceChanged;
  final ValueChanged<int> onWeekdayToggled;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<TimeOfDay?> onTimeSelected;
  final ValueChanged<bool> onReminderToggled;
  final ValueChanged<bool> onTimeBoundToggled;
  final ValueChanged<int> onTimeBoundDurationChanged;
  final ValueChanged<String> onTimeBoundUnitChanged;
  final ValueChanged<bool> onShowAnchorToggled;
  final ValueChanged<String?> onAfterHabitIdChanged;
  final ValueChanged<String> onAnchorHabitTextChanged;
  final ValueChanged<String> onRelationshipChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step3Schedule({
    super.key,
    required this.occurrenceType,
    required this.weekdays,
    required this.intervalDays,
    required this.selectedTime,
    required this.reminderEnabled,
    required this.timeBoundEnabled,
    required this.timeBoundDuration,
    required this.timeBoundUnit,
    required this.showAnchorSection,
    required this.existingHabits,
    required this.afterHabitId,
    required this.anchorHabitText,
    required this.relationship,
    required this.onOccurrenceChanged,
    required this.onWeekdayToggled,
    required this.onIntervalChanged,
    required this.onTimeSelected,
    required this.onReminderToggled,
    required this.onTimeBoundToggled,
    required this.onTimeBoundDurationChanged,
    required this.onTimeBoundUnitChanged,
    required this.onShowAnchorToggled,
    required this.onAfterHabitIdChanged,
    required this.onAnchorHabitTextChanged,
    required this.onRelationshipChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(_kSpacingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated emoji
          const _WigglingEmoji(emoji: '📆', scales: true),
          const SizedBox(height: _kSpacingL),
          // Title
          Text(
            'Set your schedule',
            style:
                AppTypography.heading2(context).copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingS),
          Text(
            'When do you want to do this?',
            style: AppTypography.bodySmall(context)
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingXXL),

          // Frequency picker (routine-style)
          Text(
            'Frequency',
            style: AppTypography.body(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: _kSpacingM),
          _OccurrencePickerCard(
            selectedType: occurrenceType,
            onTypeSelected: onOccurrenceChanged,
          ),

          // Weekday picker (animated)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: occurrenceType == 'weekdays'
                ? Column(
                    children: [
                      const SizedBox(height: _kSpacingL),
                      _WeekdayCirclePicker(
                        selectedDays: weekdays,
                        onDayToggled: onWeekdayToggled,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Interval picker
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: occurrenceType == 'interval'
                ? Column(
                    children: [
                      const SizedBox(height: _kSpacingL),
                      _IntervalStepper(
                        intervalDays: intervalDays,
                        onIntervalChanged: onIntervalChanged,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: _kSpacingXXL),

          // Time picker
          Text(
            'Scheduled Time',
            style: AppTypography.body(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: _kSpacingM),
          _TimePickerCard(
            selectedTime: selectedTime,
            onTimeSelected: onTimeSelected,
          ),

          // Reminder toggle (shown when time is selected)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: selectedTime != null
                ? Column(
                    children: [
                      const SizedBox(height: _kSpacingM),
                      _ReminderToggle(
                        enabled: reminderEnabled,
                        onToggle: onReminderToggled,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: _kSpacingXXL),

          // Duration settings
          Text(
            'Duration (Timer)',
            style: AppTypography.body(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: _kSpacingM),
          _DurationToggleCard(
            enabled: timeBoundEnabled,
            duration: timeBoundDuration,
            unit: timeBoundUnit,
            onToggle: onTimeBoundToggled,
            onDurationChanged: onTimeBoundDurationChanged,
            onUnitChanged: onTimeBoundUnitChanged,
          ),

          const SizedBox(height: _kSpacingXXL),

          // Anchor habit section
          _ExpandableSection(
            title: 'Habit Anchoring',
            subtitle: 'Chain this habit to another',
            icon: Icons.link_rounded,
            isExpanded: showAnchorSection,
            onToggle: () => onShowAnchorToggled(!showAnchorSection),
            child: _AnchorHabitSection(
              existingHabits: existingHabits,
              afterHabitId: afterHabitId,
              anchorHabitText: anchorHabitText,
              relationship: relationship,
              onAfterHabitIdChanged: onAfterHabitIdChanged,
              onAnchorHabitTextChanged: onAnchorHabitTextChanged,
              onRelationshipChanged: onRelationshipChanged,
            ),
          ),

          const SizedBox(height: _kSpacingXXL),

          // Navigation buttons
          _NavigationButtons(
            onBack: onBack,
            onNext: onNext,
            nextLabel: 'Next Step →',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Step 4: Goals & Coping Plan
// ============================================================================

class _Step4Goals extends StatelessWidget {
  final int targetCount;
  final int coinReward;
  final bool reminderEnabled;
  final String habitName;
  final int selectedIconIndex;
  final int selectedColorIndex;
  final bool showCopingPlan;
  final TextEditingController microVersionController;
  final TextEditingController predictedObstacleController;
  final TextEditingController ifThenPlanController;
  final TextEditingController rewardController;
  final double confidence;
  final ValueChanged<int> onTargetChanged;
  final ValueChanged<int> onCoinRewardChanged;
  final ValueChanged<bool> onReminderToggled;
  final ValueChanged<bool> onShowCopingPlanToggled;
  final ValueChanged<double> onConfidenceChanged;
  final VoidCallback onSave;
  final VoidCallback onBack;

  const _Step4Goals({
    super.key,
    required this.targetCount,
    required this.coinReward,
    required this.reminderEnabled,
    required this.habitName,
    required this.selectedIconIndex,
    required this.selectedColorIndex,
    required this.showCopingPlan,
    required this.microVersionController,
    required this.predictedObstacleController,
    required this.ifThenPlanController,
    required this.rewardController,
    required this.confidence,
    required this.onTargetChanged,
    required this.onCoinRewardChanged,
    required this.onReminderToggled,
    required this.onShowCopingPlanToggled,
    required this.onConfidenceChanged,
    required this.onSave,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColors = _habitColors[selectedColorIndex].$2;
    final selectedIcon = _habitIcons[selectedIconIndex].$1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(_kSpacingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated emoji
          const _WigglingEmoji(emoji: '🎯'),
          const SizedBox(height: _kSpacingL),
          // Title
          Text(
            'Set your goals',
            style:
                AppTypography.heading2(context).copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingS),
          Text(
            'Define targets and rewards',
            style: AppTypography.bodySmall(context)
                .copyWith(color: Colors.white.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _kSpacingXXL),

          // Final preview card
          _HabitPreviewCard(
            habitName: habitName,
            icon: selectedIcon,
            gradientColors: selectedColors,
            showDetails: true,
            coinReward: coinReward,
          ),
          const SizedBox(height: _kSpacingXXL),

          // Daily target
          Text(
            'Daily Target',
            style: AppTypography.body(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: _kSpacingM),
          _GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Times per day',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: Colors.white),
                ),
                Row(
                  children: [
                    _CircleButton(
                      icon: Icons.remove,
                      onTap: targetCount > 1
                          ? () => onTargetChanged(targetCount - 1)
                          : null,
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: SizedBox(
                        key: ValueKey(targetCount),
                        width: 48,
                        child: Text(
                          '$targetCount',
                          style: AppTypography.heading2(context)
                              .copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    _CircleButton(
                      icon: Icons.add,
                      onTap: targetCount < 10
                          ? () => onTargetChanged(targetCount + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: _kSpacingL),

          // Coin reward
          Text(
            'Coin Reward',
            style: AppTypography.body(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: _kSpacingM),
          _GlassCard(
            child: Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFFFFD700),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    thumbColor: const Color(0xFFFFD700),
                    overlayColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: coinReward.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    onChanged: (value) => onCoinRewardChanged(value.round()),
                  ),
                ),
                const SizedBox(height: _kSpacingS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: _kSpacingS),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Text(
                        '$coinReward',
                        key: ValueKey(coinReward),
                        style: AppTypography.heading2(context)
                            .copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: _kSpacingS),
                    Text(
                      'coins per completion',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: _kSpacingXXL),

          // Coping Plan section
          _ExpandableSection(
            title: 'Coping Plan',
            subtitle: 'Prepare for obstacles',
            icon: Icons.psychology_outlined,
            isExpanded: showCopingPlan,
            onToggle: () => onShowCopingPlanToggled(!showCopingPlan),
            child: _CopingPlanSection(
              microVersionController: microVersionController,
              predictedObstacleController: predictedObstacleController,
              ifThenPlanController: ifThenPlanController,
              rewardController: rewardController,
              confidence: confidence,
              onConfidenceChanged: onConfidenceChanged,
            ),
          ),

          const SizedBox(height: _kSpacingXXL),

          // Navigation buttons
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: '← Back',
                  onTap: onBack,
                ),
              ),
              const SizedBox(width: _kSpacingM),
              Expanded(
                child: _CreateHabitButton(onTap: onSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Enhanced Reusable Components
// ============================================================================

/// Animated back button
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

class _AnimatedIconButtonState extends State<_AnimatedIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Wiggling emoji animation
class _WigglingEmoji extends StatefulWidget {
  final String emoji;
  final bool rotates;
  final bool scales;

  const _WigglingEmoji({
    required this.emoji,
    this.rotates = false,
    this.scales = false,
  });

  @override
  State<_WigglingEmoji> createState() => _WigglingEmojiState();
}

class _WigglingEmojiState extends State<_WigglingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double rotation = 0;
        double scale = 1;

        if (widget.rotates) {
          rotation = _controller.value * 2 * math.pi;
        } else if (widget.scales) {
          scale = 1 + 0.2 * (0.5 - (_controller.value - 0.5).abs());
        } else {
          // Wiggle effect
          final wiggle = math.sin(_controller.value * 4 * math.pi) * 0.1;
          rotation = wiggle;
        }

        return Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Text(
        widget.emoji,
        style: const TextStyle(fontSize: 56),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Bounce-animated selectable icon button
class _BounceSelectableIconButton extends StatefulWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _BounceSelectableIconButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BounceSelectableIconButton> createState() =>
      _BounceSelectableIconButtonState();
}

class _BounceSelectableIconButtonState
    extends State<_BounceSelectableIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(_BounceSelectableIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _bounceController,
        builder: (context, child) {
          final bounce = widget.isSelected
              ? 1.0 + Curves.elasticOut.transform(_bounceController.value) * 0.1
              : 1.0;
          return AnimatedScale(
            scale: _isPressed ? 0.9 : bounce,
            duration: const Duration(milliseconds: 100),
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(_kRadiusM),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 24,
              color: widget.isSelected ? AppColors.medium : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bounce-animated selectable color button
class _BounceSelectableColorButton extends StatefulWidget {
  final List<Color> colors;
  final bool isSelected;
  final VoidCallback onTap;

  const _BounceSelectableColorButton({
    required this.colors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BounceSelectableColorButton> createState() =>
      _BounceSelectableColorButtonState();
}

class _BounceSelectableColorButtonState
    extends State<_BounceSelectableColorButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(_BounceSelectableColorButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _bounceController,
        builder: (context, child) {
          final bounce = widget.isSelected
              ? 1.0 + Curves.elasticOut.transform(_bounceController.value) * 0.15
              : 1.0;
          return AnimatedScale(
            scale: _isPressed ? 0.9 : bounce,
            duration: const Duration(milliseconds: 100),
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_kRadiusM),
            border: widget.isSelected
                ? Border.all(color: Colors.white, width: 4)
                : null,
            boxShadow: [
              BoxShadow(
                color: widget.colors[0].withValues(alpha: 0.4),
                blurRadius: widget.isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.isSelected
              ? Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: AppColors.dark,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Shimmer preview card for color selection
class _ShimmerPreviewCard extends StatelessWidget {
  final String habitName;
  final IconData icon;
  final List<Color> gradientColors;
  final AnimationController shimmerController;

  const _ShimmerPreviewCard({
    required this.habitName,
    required this.icon,
    required this.gradientColors,
    required this.shimmerController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmerController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(_kSpacingXXL),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_kRadiusXL),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Shimmer overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_kRadiusXL),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment(-1.0 + shimmerController.value * 3, 0),
                        end: Alignment(shimmerController.value * 3, 0),
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcATop,
                    child: Container(color: Colors.white),
                  ),
                ),
              ),
              // Content
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(_kRadiusM),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: _kSpacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habitName,
                          style: AppTypography.heading3(context)
                              .copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: _kSpacingXS),
                        Text(
                          'Preview',
                          style: AppTypography.bodySmall(context)
                              .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Occurrence picker card (routine-style)
class _OccurrencePickerCard extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeSelected;

  const _OccurrencePickerCard({
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedOption = _occurrenceOptions.firstWhere(
      (o) => o.value == selectedType,
      orElse: () => _occurrenceOptions.first,
    );

    return GestureDetector(
      onTap: () => _showOccurrenceBottomSheet(context, colorScheme),
      child: _GlassCard(
        child: Row(
          children: [
            // Icon container
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(_kRadiusM),
              ),
              child: Icon(
                selectedOption.icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: _kSpacingM),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedOption.label,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedOption.description,
                    style: AppTypography.caption(context).copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Dropdown arrow
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(_kRadiusS),
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOccurrenceBottomSheet(BuildContext context, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(_kRadiusXL)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: _kSpacingM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(_kSpacingXL),
                child: Text(
                  'Repeat',
                  style: AppTypography.heading3(context),
                ),
              ),
              // Options
              ..._occurrenceOptions.map((option) {
                final isSelected = selectedType == option.value;
                return _OccurrenceOptionTile(
                  option: option,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTypeSelected(option.value);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: _kSpacingXL),
            ],
          ),
        ),
      ),
    );
  }
}

/// Occurrence option tile in bottom sheet
class _OccurrenceOptionTile extends StatelessWidget {
  final ({String value, String label, IconData icon, String description}) option;
  final bool isSelected;
  final VoidCallback onTap;

  const _OccurrenceOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: _kSpacingL, vertical: _kSpacingXS),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(_kRadiusM),
        border: isSelected
            ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_kRadiusM),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(_kSpacingL),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(_kRadiusM),
                  ),
                  child: Icon(
                    option.icon,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                const SizedBox(width: _kSpacingL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: AppTypography.bodySmall(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.description,
                        style: AppTypography.caption(context),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: colorScheme.onPrimary,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Weekday circle picker
class _WeekdayCirclePicker extends StatelessWidget {
  final Set<int> selectedDays;
  final ValueChanged<int> onDayToggled;

  const _WeekdayCirclePicker({
    required this.selectedDays,
    required this.onDayToggled,
  });

  static const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select days',
            style: AppTypography.caption(context)
                .copyWith(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: _kSpacingM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isSelected = selectedDays.contains(index);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onDayToggled(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _weekdayLetters[index],
                      style: AppTypography.bodySmall(context).copyWith(
                        color: isSelected ? AppColors.dark : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (selectedDays.isNotEmpty) ...[
            const SizedBox(height: _kSpacingS),
            Text(
              (selectedDays.toList()..sort())
                  .map((i) => _weekdayNames[i])
                  .join(', '),
              style: AppTypography.caption(context)
                  .copyWith(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interval stepper
class _IntervalStepper extends StatelessWidget {
  final int intervalDays;
  final ValueChanged<int> onIntervalChanged;

  const _IntervalStepper({
    required this.intervalDays,
    required this.onIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          Icon(
            Icons.repeat_rounded,
            color: Colors.white.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: _kSpacingM),
          Text(
            'Every',
            style: AppTypography.bodySmall(context).copyWith(color: Colors.white),
          ),
          const SizedBox(width: _kSpacingM),
          // Stepper
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(_kRadiusS),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onTap: intervalDays > 1
                      ? () {
                          HapticFeedback.selectionClick();
                          onIntervalChanged(intervalDays - 1);
                        }
                      : null,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Container(
                    key: ValueKey(intervalDays),
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      '$intervalDays',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onIntervalChanged(intervalDays + 1);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: _kSpacingM),
          Text(
            intervalDays == 1 ? 'day' : 'days',
            style: AppTypography.bodySmall(context).copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Stepper button
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_kRadiusS),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_kSpacingS),
          child: Icon(
            icon,
            size: 18,
            color: onTap != null
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// Time picker card
class _TimePickerCard extends StatelessWidget {
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay?> onTimeSelected;

  const _TimePickerCard({
    required this.selectedTime,
    required this.onTimeSelected,
  });

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: selectedTime ?? TimeOfDay.now(),
        );
        if (time != null) {
          onTimeSelected(time);
        }
      },
      child: _GlassCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(_kRadiusM),
              ),
              child: const Icon(
                Icons.access_time_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: _kSpacingM),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: selectedTime != null
                    ? Text(
                        _formatTime(selectedTime!),
                        key: ValueKey(selectedTime),
                        style: AppTypography.bodySmall(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Text(
                        'Tap to set time',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
              ),
            ),
            if (selectedTime != null)
              GestureDetector(
                onTap: () => onTimeSelected(null),
                child: Container(
                  padding: const EdgeInsets.all(_kSpacingS),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(_kRadiusS),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Duration toggle card
class _DurationToggleCard extends StatelessWidget {
  final bool enabled;
  final int duration;
  final String unit;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<String> onUnitChanged;

  const _DurationToggleCard({
    required this.enabled,
    required this.duration,
    required this.unit,
    required this.onToggle,
    required this.onDurationChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(!enabled);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(_kSpacingL),
            decoration: BoxDecoration(
              color: enabled
                  ? colorScheme.surface.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(_kRadiusL),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: enabled ? AppColors.medium : Colors.white,
                  size: 24,
                ),
                const SizedBox(width: _kSpacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Track Duration',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: enabled ? AppColors.dark : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Set a target time for this habit',
                        style: AppTypography.caption(context).copyWith(
                          color: enabled
                              ? AppColors.medium
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                _AnimatedSwitch(enabled: enabled),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: enabled
              ? Padding(
                  padding: const EdgeInsets.only(top: _kSpacingM),
                  child: _GlassCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _CircleButton(
                                icon: Icons.remove,
                                onTap: duration > 1
                                    ? () => onDurationChanged(duration - 5)
                                    : null,
                              ),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                        scale: animation, child: child);
                                  },
                                  child: Text(
                                    '$duration',
                                    key: ValueKey(duration),
                                    style: AppTypography.heading2(context)
                                        .copyWith(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              _CircleButton(
                                icon: Icons.add,
                                onTap: () => onDurationChanged(duration + 5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: _kSpacingM),
                        _UnitSelector(
                          selectedUnit: unit,
                          onUnitChanged: onUnitChanged,
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Unit selector for duration
class _UnitSelector extends StatelessWidget {
  final String selectedUnit;
  final ValueChanged<String> onUnitChanged;

  const _UnitSelector({
    required this.selectedUnit,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(_kRadiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['minutes', 'hours'].map((unit) {
          final isSelected = selectedUnit == unit;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onUnitChanged(unit);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: _kSpacingM,
                vertical: _kSpacingS,
              ),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(_kRadiusS),
              ),
              child: Text(
                unit == 'minutes' ? 'min' : 'hrs',
                style: AppTypography.caption(context).copyWith(
                  color: isSelected ? AppColors.dark : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Animated switch
class _AnimatedSwitch extends StatelessWidget {
  final bool enabled;

  const _AnimatedSwitch({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 28,
      decoration: BoxDecoration(
        color: enabled ? AppColors.medium : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Expandable section
class _ExpandableSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  const _ExpandableSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(_kSpacingL),
            decoration: BoxDecoration(
              color: isExpanded
                  ? colorScheme.surface.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(_kRadiusL),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isExpanded ? AppColors.medium : Colors.white,
                  size: 24,
                ),
                const SizedBox(width: _kSpacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodySmall(context).copyWith(
                          color: isExpanded ? AppColors.dark : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption(context).copyWith(
                          color: isExpanded
                              ? AppColors.medium
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isExpanded ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isExpanded ? AppColors.medium : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: _kSpacingM),
                  child: child,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Anchor habit section
class _AnchorHabitSection extends StatelessWidget {
  final List<HabitItem> existingHabits;
  final String? afterHabitId;
  final String anchorHabitText;
  final String relationship;
  final ValueChanged<String?> onAfterHabitIdChanged;
  final ValueChanged<String> onAnchorHabitTextChanged;
  final ValueChanged<String> onRelationshipChanged;

  const _AnchorHabitSection({
    required this.existingHabits,
    required this.afterHabitId,
    required this.anchorHabitText,
    required this.relationship,
    required this.onAfterHabitIdChanged,
    required this.onAnchorHabitTextChanged,
    required this.onRelationshipChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Existing habit dropdown
          if (existingHabits.isNotEmpty) ...[
            Text(
              'Link to existing habit',
              style: AppTypography.caption(context)
                  .copyWith(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: _kSpacingS),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: _kSpacingM),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(_kRadiusS),
              ),
              child: DropdownButton<String?>(
                value: afterHabitId,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                dropdownColor: colorScheme.surface,
                hint: Text(
                  'Select a habit',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: Colors.white.withValues(alpha: 0.7)),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'None',
                      style: AppTypography.bodySmall(context),
                    ),
                  ),
                  ...existingHabits.map((h) => DropdownMenuItem(
                        value: h.id,
                        child: Text(
                          h.name,
                          style: AppTypography.bodySmall(context),
                        ),
                      )),
                ],
                onChanged: onAfterHabitIdChanged,
              ),
            ),
            const SizedBox(height: _kSpacingM),
          ],
          // Or type custom
          Text(
            'Or type anchor habit name',
            style: AppTypography.caption(context)
                .copyWith(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: _kSpacingS),
          TextField(
            onChanged: onAnchorHabitTextChanged,
            style: AppTypography.bodySmall(context).copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g., After breakfast',
              hintStyle: AppTypography.bodySmall(context)
                  .copyWith(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kRadiusS),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: _kSpacingM,
                vertical: _kSpacingS,
              ),
            ),
          ),
          const SizedBox(height: _kSpacingM),
          // Relationship selector
          Text(
            'Relationship',
            style: AppTypography.caption(context)
                .copyWith(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: _kSpacingS),
          Wrap(
            spacing: _kSpacingS,
            children: _relationshipOptions.map((rel) {
              final isSelected = relationship == rel;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onRelationshipChanged(rel);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kSpacingM,
                    vertical: _kSpacingS,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(_kRadiusS),
                  ),
                  child: Text(
                    rel,
                    style: AppTypography.caption(context).copyWith(
                      color: isSelected ? AppColors.dark : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Coping plan section
class _CopingPlanSection extends StatelessWidget {
  final TextEditingController microVersionController;
  final TextEditingController predictedObstacleController;
  final TextEditingController ifThenPlanController;
  final TextEditingController rewardController;
  final double confidence;
  final ValueChanged<double> onConfidenceChanged;

  const _CopingPlanSection({
    required this.microVersionController,
    required this.predictedObstacleController,
    required this.ifThenPlanController,
    required this.rewardController,
    required this.confidence,
    required this.onConfidenceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CopingPlanField(
            controller: microVersionController,
            label: 'Micro version',
            hint: 'What\'s the smallest version? (e.g., 5 minutes)',
            icon: Icons.compress_rounded,
          ),
          const SizedBox(height: _kSpacingM),
          _CopingPlanField(
            controller: predictedObstacleController,
            label: 'Predicted obstacle',
            hint: 'What might stop you?',
            icon: Icons.block_rounded,
          ),
          const SizedBox(height: _kSpacingM),
          _CopingPlanField(
            controller: ifThenPlanController,
            label: 'If-Then plan',
            hint: 'If X happens, then I will...',
            icon: Icons.alt_route_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: _kSpacingM),
          // Confidence slider
          Text(
            'Confidence: ${confidence.round()}/10',
            style: AppTypography.caption(context)
                .copyWith(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: _kSpacingS),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.lightest,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: confidence,
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: onConfidenceChanged,
            ),
          ),
          const SizedBox(height: _kSpacingM),
          _CopingPlanField(
            controller: rewardController,
            label: 'Reward',
            hint: 'How will you celebrate?',
            icon: Icons.celebration_rounded,
          ),
        ],
      ),
    );
  }
}

/// Coping plan field
class _CopingPlanField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _CopingPlanField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(width: _kSpacingS),
            Text(
              label,
              style: AppTypography.caption(context)
                  .copyWith(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
        const SizedBox(height: _kSpacingS),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.bodySmall(context).copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodySmall(context)
                .copyWith(color: Colors.white.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_kRadiusS),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: _kSpacingM,
              vertical: _kSpacingS,
            ),
          ),
        ),
      ],
    );
  }
}

/// Habit preview card
class _HabitPreviewCard extends StatelessWidget {
  final String habitName;
  final IconData icon;
  final List<Color> gradientColors;
  final bool showDetails;
  final int? coinReward;

  const _HabitPreviewCard({
    required this.habitName,
    required this.icon,
    required this.gradientColors,
    this.showDetails = false,
    this.coinReward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_kSpacingXXL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_kRadiusXL),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(_kRadiusM),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: _kSpacingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habitName,
                      style: AppTypography.heading3(context)
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: _kSpacingXS),
                    Text(
                      showDetails ? 'Daily Goal' : 'Preview',
                      style: AppTypography.bodySmall(context)
                          .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              if (!showDetails)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
            ],
          ),
          if (showDetails) ...[
            const SizedBox(height: _kSpacingL),
            Row(
              children: [
                Text(
                  '🔥 0 day streak',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(width: _kSpacingL),
                Text(
                  '🪙 ${coinReward ?? 50} coins',
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Glass card container
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_kSpacingL),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(_kRadiusL),
      ),
      child: child,
    );
  }
}

/// Circle button for increment/decrement
class _CircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleButton({
    required this.icon,
    this.onTap,
  });

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: isEnabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isEnabled ? 1.0 : 0.5,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              color: AppColors.dark,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reminder toggle card
class _ReminderToggle extends StatefulWidget {
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _ReminderToggle({
    required this.enabled,
    required this.onToggle,
  });

  @override
  State<_ReminderToggle> createState() => _ReminderToggleState();
}

class _ReminderToggleState extends State<_ReminderToggle> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onToggle(!widget.enabled);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(_kSpacingL),
          decoration: BoxDecoration(
            color: widget.enabled
                ? colorScheme.surface
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(_kRadiusL),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                color: widget.enabled ? AppColors.medium : Colors.white,
                size: 24,
              ),
              const SizedBox(width: _kSpacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable Reminder',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: widget.enabled ? AppColors.dark : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: _kSpacingXS),
                    Text(
                      'Get notified at the scheduled time',
                      style: AppTypography.caption(context).copyWith(
                        color: widget.enabled
                            ? AppColors.medium
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              _AnimatedSwitch(enabled: widget.enabled),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary button
class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp:
          widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.enabled
          ? () {
              HapticFeedback.mediumImpact();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.enabled ? 1.0 : 0.5,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_kRadiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.label,
                style: AppTypography.button(context).copyWith(
                  color: AppColors.dark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button
class _SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(_kRadiusM),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: AppTypography.button(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation buttons (Back + Next)
class _NavigationButtons extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String nextLabel;

  const _NavigationButtons({
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SecondaryButton(label: '← Back', onTap: onBack),
        ),
        const SizedBox(width: _kSpacingM),
        Expanded(
          child: _PrimaryButton(label: nextLabel, onTap: onNext, enabled: true),
        ),
      ],
    );
  }
}

/// Create Habit button with gradient
class _CreateHabitButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CreateHabitButton({required this.onTap});

  @override
  State<_CreateHabitButton> createState() => _CreateHabitButtonState();
}

class _CreateHabitButtonState extends State<_CreateHabitButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF34D399), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_kRadiusM),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF34D399).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: _kSpacingS),
              Text(
                'Create Habit',
                style: AppTypography.button(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
