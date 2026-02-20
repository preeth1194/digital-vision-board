import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/challenge.dart';
import '../models/challenge_template.dart';
import '../models/habit_item.dart';
import '../services/challenge_storage_service.dart';
import '../services/habit_storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_typography.dart';
import '../widgets/rituals/habit_form_constants.dart';

/// Screen that lets users preview a challenge template, customise habit timing
/// and tracker targets, pick a start date, and launch the challenge.
class ChallengeSetupScreen extends StatefulWidget {
  final ChallengeTemplate template;

  const ChallengeSetupScreen({super.key, required this.template});

  @override
  State<ChallengeSetupScreen> createState() => _ChallengeSetupScreenState();
}

class _ChallengeSetupScreenState extends State<ChallengeSetupScreen> {
  late DateTime _startDate;
  late List<_EditableHabit> _habits;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _habits = widget.template.habits.map((bp) {
      return _EditableHabit(
        nameController: TextEditingController(text: bp.defaultName),
        category: bp.category,
        iconIndex: bp.iconIndex,
        timeBound: bp.timeBound,
        trackingSpec: bp.trackingSpec,
        startTimeMinutes: bp.suggestedStartTimeMinutes,
        description: bp.description,
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final h in _habits) {
      h.nameController.dispose();
    }
    super.dispose();
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hh = ((h % 12) == 0) ? 12 : (h % 12);
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '$hh:${m.toString().padLeft(2, '0')} $ampm';
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickTime(int habitIndex) async {
    final current = _habits[habitIndex].startTimeMinutes ?? 8 * 60;
    final h = current ~/ 60;
    final m = current % 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
    );
    if (picked != null && mounted) {
      setState(() {
        _habits[habitIndex].startTimeMinutes = picked.hour * 60 + picked.minute;
      });
    }
  }

  Future<void> _pickDuration(int habitIndex) async {
    final habit = _habits[habitIndex];
    final tb = habit.timeBound;
    if (tb == null) return;

    int minutes = tb.duration;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int val = minutes;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Workout Duration'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$val minutes', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Slider(
                    value: val.toDouble(),
                    min: 15,
                    max: 120,
                    divisions: 21,
                    label: '$val min',
                    onChanged: (v) => setDialogState(() => val = v.round()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, val), child: const Text('Set')),
              ],
            );
          },
        );
      },
    );
    if (result != null && mounted) {
      setState(() {
        _habits[habitIndex].timeBound = tb.copyWith(duration: result);
      });
    }
  }

  Future<void> _startChallenge() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final template = widget.template;
      final startIso = _startDate.toIso8601String().split('T')[0];
      final deadlineDate = _startDate.add(Duration(days: template.durationDays - 1));
      final deadlineIso = deadlineDate.toIso8601String().split('T')[0];
      final now = DateTime.now().millisecondsSinceEpoch;

      final habitIds = <String>[];
      for (int i = 0; i < _habits.length; i++) {
        final editable = _habits[i];
        final id = '${now}_challenge_$i';
        final timeMinutes = editable.startTimeMinutes;
        String? timeOfDay;
        if (timeMinutes != null) {
          timeOfDay = _formatTime(timeMinutes);
        }

        final habit = HabitItem(
          id: id,
          name: editable.nameController.text.trim(),
          category: editable.category,
          frequency: 'Daily',
          deadline: deadlineIso,
          timeOfDay: timeOfDay,
          reminderMinutes: timeMinutes,
          reminderEnabled: timeMinutes != null,
          timeBound: editable.timeBound,
          trackingSpec: editable.trackingSpec,
          iconIndex: editable.iconIndex,
          completedDates: const [],
          startTimeMinutes: timeMinutes,
        );
        await HabitStorageService.addHabit(habit, prefs: prefs);
        habitIds.add(id);
      }

      final challenge = Challenge(
        id: 'challenge_$now',
        name: template.name,
        templateType: template.id,
        startDate: startIso,
        totalDays: template.durationDays,
        habitIds: habitIds,
        completedDays: const [],
        isActive: true,
        restartCount: 0,
        createdAtMs: now,
      );
      await ChallengeStorageService.addChallenge(challenge, prefs: prefs);
      await ChallengeStorageService.setActiveChallengeId(challenge.id, prefs: prefs);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final template = widget.template;
    final endDate = _startDate.add(Duration(days: template.durationDays - 1));

    return Container(
      decoration: AppColors.skyDecoration(isDark: isDark),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(template.name),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(colorScheme, isDark, template),
              const SizedBox(height: 20),

              Text('Challenge Rules', style: AppTypography.heading3(context)),
              const SizedBox(height: 8),
              _glassContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: template.rules.asMap().entries.map((e) => Padding(
                    padding: EdgeInsets.only(bottom: e.key < template.rules.length - 1 ? 8 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.key + 1}. ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value,
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 24),

              Text('Start Date', style: AppTypography.heading3(context)),
              const SizedBox(height: 8),
              _glassContainer(
                isDark: isDark,
                child: ListTile(
                  leading: Icon(Icons.calendar_today_rounded, color: colorScheme.primary),
                  title: Text(_formatDate(_startDate)),
                  subtitle: Text('Ends ${_formatDate(endDate)}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(height: 24),

              Text('Customize Your Habits', style: AppTypography.heading3(context)),
              const SizedBox(height: 4),
              Text(
                'Adjust names, times, and durations to fit your schedule.',
                style: AppTypography.caption(context),
              ),
              const SizedBox(height: 12),
              ..._habits.asMap().entries.map((entry) =>
                  _buildHabitCard(entry.key, entry.value, colorScheme, isDark)),
            ],
          ),
        ),
        bottomSheet: _buildBottomBar(colorScheme, isDark),
      ),
    );
  }

  Widget _glassContainer({
    required bool isDark,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double radius = 16,
    required Widget child,
  }) {
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.55);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.7);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme, bool isDark, ChallengeTemplate template) {
    return _glassContainer(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.military_tech_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      template.subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            template.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(Icons.timer_outlined, '${template.durationDays} days', colorScheme),
              const SizedBox(width: 8),
              _infoChip(Icons.checklist_rounded, '${template.habits.length} daily tasks', colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCard(int index, _EditableHabit habit, ColorScheme colorScheme, bool isDark) {
    final iconData = (habit.iconIndex < habitIcons.length)
        ? habitIcons[habit.iconIndex].$1
        : Icons.check_circle;
    final bgColor = AppColors.categoryBgColor(habit.category, isDark);
    final iconColor = AppColors.categoryIconColor(habit.category, isDark);

    return _glassContainer(
      isDark: isDark,
      margin: const EdgeInsets.only(bottom: 12),
      radius: 12,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: habit.nameController,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (habit.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 50, bottom: 6),
              child: Text(
                habit.description,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (habit.startTimeMinutes != null)
                  ActionChip(
                    avatar: Icon(Icons.schedule, size: 16, color: colorScheme.primary),
                    label: Text(_formatTime(habit.startTimeMinutes!)),
                    onPressed: () => _pickTime(index),
                    visualDensity: VisualDensity.compact,
                  ),
                if (habit.startTimeMinutes == null)
                  ActionChip(
                    avatar: Icon(Icons.add_alarm, size: 16, color: colorScheme.primary),
                    label: const Text('Set time'),
                    onPressed: () => _pickTime(index),
                    visualDensity: VisualDensity.compact,
                  ),

                if (habit.timeBound != null)
                  ActionChip(
                    avatar: Icon(Icons.timer, size: 16, color: colorScheme.primary),
                    label: Text('${habit.timeBound!.duration} min'),
                    onPressed: () => _pickDuration(index),
                    visualDensity: VisualDensity.compact,
                  ),

                if (habit.trackingSpec != null)
                  Chip(
                    avatar: Icon(Icons.track_changes, size: 16, color: colorScheme.primary),
                    label: Text('Track in ${habit.trackingSpec!.unitLabel}'),
                    visualDensity: VisualDensity.compact,
                  ),

                Chip(
                  label: Text(
                    habit.category,
                    style: TextStyle(fontSize: 12, color: iconColor),
                  ),
                  backgroundColor: bgColor.withValues(alpha: 0.5),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme, bool isDark) {
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.55);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.7);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: fillColor,
            border: Border(
              top: BorderSide(color: borderColor, width: 1.0),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _saving ? null : _startChallenge,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.rocket_launch_rounded),
              label: Text(_saving ? 'Starting...' : 'Start Challenge'),
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableHabit {
  final TextEditingController nameController;
  final String category;
  final int iconIndex;
  HabitTimeBoundSpec? timeBound;
  HabitTrackingSpec? trackingSpec;
  int? startTimeMinutes;
  final String description;

  _EditableHabit({
    required this.nameController,
    required this.category,
    required this.iconIndex,
    this.timeBound,
    this.trackingSpec,
    this.startTimeMinutes,
    this.description = '',
  });
}
