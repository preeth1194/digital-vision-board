import 'package:flutter/material.dart';

import '../../../models/habit_action_step.dart';
import '../../../models/habit_item.dart';
import '../../../services/habit_storage_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../../../widgets/rituals/habit_form_constants.dart';
import '../onboarding_first_habit_draft.dart';
import '_step_header.dart';

class _StackSuggestion {
  final String label;
  final String? habitId;
  final bool isDefault;

  const _StackSuggestion({
    required this.label,
    this.habitId,
    required this.isDefault,
  });
}

/// Optional routine steps, daily reminder, and anchor habit before the photo step.
class StepFirstHabitRoutine extends StatefulWidget {
  final OnboardingFirstHabitDraft draft;
  final VoidCallback notifyParent;
  final VoidCallback onNext;

  const StepFirstHabitRoutine({
    super.key,
    required this.draft,
    required this.notifyParent,
    required this.onNext,
  });

  @override
  State<StepFirstHabitRoutine> createState() => _StepFirstHabitRoutineState();
}

class _StepFirstHabitRoutineState extends State<StepFirstHabitRoutine> {
  static const int _maxSteps = 6;
  static const TimeOfDay _defaultReminder = TimeOfDay(hour: 9, minute: 0);

  final List<TextEditingController> _stepControllers = [];
  bool _reminderOn = false;
  TimeOfDay? _reminderTime;

  final TextEditingController _anchorController = TextEditingController();
  final FocusNode _anchorFocus = FocusNode();
  bool _anchorEnabled = false;
  bool _showAnchorSuggestions = false;
  String? _anchorAfterHabitId;
  String _anchorRelationship = 'Before';
  List<HabitItem> _existingHabits = [];
  final GlobalKey _anchorSuggestionsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reminderOn = widget.draft.reminderEnabled;
    _reminderTime = widget.draft.reminderTime ?? _defaultReminder;
    if (widget.draft.actionSteps.isNotEmpty) {
      for (final s in widget.draft.actionSteps) {
        _stepControllers.add(TextEditingController(text: s.title));
      }
    }

    _anchorEnabled = widget.draft.stackAnchorEnabled;
    _anchorController.text = widget.draft.stackAnchorText;
    _anchorAfterHabitId = widget.draft.stackAfterHabitId;
    _anchorRelationship =
        widget.draft.stackRelationship == 'After' ? 'After' : 'Before';

    _anchorController.addListener(_onAnchorTextChanged);

    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final all = await HabitStorageService.loadAll();
    if (!mounted) return;
    final hid = widget.draft.habitId;
    setState(() {
      _existingHabits = hid == null
          ? all
          : all.where((h) => h.id != hid).toList();
    });
  }

  void _onAnchorTextChanged() {
    setState(() {
      _anchorAfterHabitId = null;
      _showAnchorSuggestions = true;
    });
    widget.notifyParent();
  }

  @override
  void dispose() {
    _anchorController.removeListener(_onAnchorTextChanged);
    for (final c in _stepControllers) {
      c.dispose();
    }
    _anchorController.dispose();
    _anchorFocus.dispose();
    super.dispose();
  }

  List<_StackSuggestion> _buildSuggestions() {
    final query = _anchorController.text.trim().toLowerCase();
    final existingNames =
        _existingHabits.map((h) => h.name.toLowerCase()).toSet();
    final results = <_StackSuggestion>[];

    for (final h in _existingHabits) {
      if (query.isEmpty || h.name.toLowerCase().contains(query)) {
        results.add(
          _StackSuggestion(label: h.name, habitId: h.id, isDefault: false),
        );
      }
    }

    for (final name in kDefaultStackingHabits) {
      if (!existingNames.contains(name.toLowerCase())) {
        if (query.isEmpty || name.toLowerCase().contains(query)) {
          results.add(
            _StackSuggestion(label: name, habitId: null, isDefault: true),
          );
        }
      }
    }
    return results;
  }

  void _selectSuggestion(_StackSuggestion s) {
    _anchorController.removeListener(_onAnchorTextChanged);
    _anchorController.text = s.label;
    _anchorController.addListener(_onAnchorTextChanged);
    setState(() {
      _anchorAfterHabitId = s.habitId;
      _showAnchorSuggestions = false;
    });
    _anchorFocus.unfocus();
    widget.notifyParent();
  }

  void _clearAnchorSelection() {
    _anchorController.clear();
    setState(() {
      _anchorAfterHabitId = null;
    });
    widget.notifyParent();
  }

  void _addStepRow() {
    if (_stepControllers.length >= _maxSteps) return;
    setState(() {
      _stepControllers.add(TextEditingController());
    });
  }

  void _removeStepRow(int index) {
    setState(() {
      _stepControllers[index].dispose();
      _stepControllers.removeAt(index);
    });
  }

  Future<void> _pickReminderTime() async {
    final initial = _reminderTime ?? _defaultReminder;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.seedGold,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _reminderTime = picked);
      widget.notifyParent();
    }
  }

  void _onContinue() {
    final id = widget.draft.habitId;
    if (id == null) return;

    final steps = <HabitActionStep>[];
    var order = 0;
    for (var i = 0; i < _stepControllers.length; i++) {
      final t = _stepControllers[i].text.trim();
      if (t.isEmpty) continue;
      steps.add(
        HabitActionStep(
          id: '${id}_step_$order',
          title: t,
          iconCodePoint: Icons.check_circle_outline.codePoint,
          order: order,
        ),
      );
      order++;
    }

    widget.draft.actionSteps = steps;
    widget.draft.reminderEnabled = _reminderOn;
    widget.draft.reminderTime =
        _reminderOn ? (_reminderTime ?? _defaultReminder) : null;

    widget.draft.stackAnchorEnabled = _anchorEnabled;
    widget.draft.stackAnchorText = _anchorController.text.trim();
    widget.draft.stackAfterHabitId = _anchorAfterHabitId;
    widget.draft.stackRelationship = _anchorRelationship;

    widget.notifyParent();
    widget.onNext();
  }

  Widget _buildAnchorSuggestions(BuildContext context) {
    final suggestions = _buildSuggestions();
    final query = _anchorController.text.trim();
    final userHabits = suggestions.where((s) => !s.isDefault).toList();
    final defaultHabits = suggestions.where((s) => s.isDefault).toList();
    final exactMatch = suggestions.any(
      (s) => s.label.toLowerCase() == query.toLowerCase(),
    );

    if (suggestions.isEmpty && query.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget tile(String title, IconData icon, VoidCallback onTap) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.seedGold),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      key: _anchorSuggestionsKey,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          children: [
            if (query.isNotEmpty && !exactMatch)
              tile('Use "$query"', Icons.add_circle_outline, () {
                _selectSuggestion(
                  _StackSuggestion(label: query, habitId: null, isDefault: true),
                );
              }),
            if (userHabits.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  'Your habits',
                  style: AppTypography.caption(context).copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final s in userHabits)
                tile(s.label, Icons.check_circle_outline, () {
                  _selectSuggestion(s);
                }),
            ],
            if (defaultHabits.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  'Common anchors',
                  style: AppTypography.caption(context).copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final s in defaultHabits)
                tile(s.label, Icons.star_outline_rounded, () {
                  _selectSuggestion(s);
                }),
            ],
          ],
        ),
      ),
    );
  }

  void _scrollAnchorSuggestionsIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _anchorSuggestionsKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final labelMuted = Colors.white.withValues(alpha: 0.5);
    final bodyMuted = Colors.white.withValues(alpha: 0.62);
    final timeLabel = _reminderOn
        ? MaterialLocalizations.of(context).formatTimeOfDay(
              _reminderTime ?? _defaultReminder,
              alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
            )
        : null;
    final mq = MediaQuery.of(context);
    final scrollBottomPad = AppSpacing.md +
        ((_anchorEnabled && _showAnchorSuggestions) ? 240.0 : 0.0) +
        mq.padding.bottom;

    return Container(
      color: AppColors.cloudDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  scrollBottomPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    StepHeader(
                      overline: 'FIRST SEED',
                      title: 'Shape your\nroutine.',
                      subtitle:
                          'Optional: break the habit into small steps, a daily reminder, or anchor it to something you already do.',
                      titleColor: Colors.white,
                      subtitleColor: labelMuted,
                      overlineColor: labelMuted,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'STEPS (OPTIONAL)',
                      style: AppTypography.caption(context).copyWith(
                        color: labelMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tiny steps make it easier to start — add a few, or leave blank.',
                      style: AppTypography.secondary(context).copyWith(
                        color: bodyMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 0; i < _stepControllers.length; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _stepControllers[i],
                              style: AppTypography.body(context).copyWith(
                                color: Colors.white,
                              ),
                              cursorColor: AppColors.seedGold,
                              decoration: InputDecoration(
                                hintText: 'Step ${i + 1}',
                                hintStyle: AppTypography.secondary(context)
                                    .copyWith(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusInput,
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusInput,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.seedGold,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              tooltip: 'Remove step',
                              onPressed: () => _removeStepRow(i),
                              icon: Icon(
                                Icons.close,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (_stepControllers.length < _maxSteps)
                      TextButton.icon(
                        onPressed: _addStepRow,
                        icon: Icon(
                          Icons.add,
                          color: AppColors.seedGold.withValues(alpha: 0.95),
                          size: 22,
                        ),
                        label: Text(
                          'Add step',
                          style: AppTypography.button(context).copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'REMINDER (OPTIONAL)',
                      style: AppTypography.caption(context).copyWith(
                        color: labelMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Daily notification',
                        style: AppTypography.body(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'We will nudge you once a day at the time you choose.',
                        style: AppTypography.caption(context).copyWith(
                          color: bodyMuted,
                        ),
                      ),
                      value: _reminderOn,
                      activeThumbColor: AppColors.seedGold,
                      activeTrackColor: AppColors.seedGold.withValues(alpha: 0.45),
                      onChanged: (v) {
                        setState(() {
                          _reminderOn = v;
                          if (v && _reminderTime == null) {
                            _reminderTime = _defaultReminder;
                          }
                        });
                        widget.notifyParent();
                      },
                    ),
                    if (_reminderOn) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusInput),
                          onTap: _pickReminderTime,
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusInput),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    timeLabel ?? '',
                                    style: AppTypography.body(context).copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.schedule,
                                  color: AppColors.seedGold.withValues(alpha: 0.9),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'ANCHOR HABIT (OPTIONAL)',
                      style: AppTypography.caption(context).copyWith(
                        color: labelMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Link this habit to something you already do — search or pick a suggestion.',
                      style: AppTypography.secondary(context).copyWith(
                        color: bodyMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Anchor to an existing habit',
                        style: AppTypography.body(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: _anchorEnabled,
                      activeThumbColor: AppColors.seedGold,
                      activeTrackColor: AppColors.seedGold.withValues(alpha: 0.45),
                      onChanged: (v) {
                        setState(() {
                          _anchorEnabled = v;
                          if (!v) {
                            _showAnchorSuggestions = false;
                          } else {
                            _showAnchorSuggestions = true;
                          }
                        });
                        widget.notifyParent();
                        if (v) {
                          _scrollAnchorSuggestionsIntoView();
                        }
                      },
                    ),
                    if (_anchorEnabled) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusInput),
                        ),
                        child: DropdownButton<String>(
                          value: _anchorRelationship == 'After'
                              ? 'After'
                              : 'Before',
                          isExpanded: true,
                          dropdownColor: AppColors.cloudDark,
                          underline: const SizedBox(),
                          style: AppTypography.body(context).copyWith(
                            color: Colors.white,
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Before',
                              child: Text(
                                'Before',
                                style: AppTypography.body(context).copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'After',
                              child: Text(
                                'After',
                                style: AppTypography.body(context).copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _anchorRelationship = v;
                              _showAnchorSuggestions = true;
                            });
                            widget.notifyParent();
                            _scrollAnchorSuggestionsIntoView();
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _anchorController,
                        focusNode: _anchorFocus,
                        onTap: () {
                          setState(() => _showAnchorSuggestions = true);
                          _scrollAnchorSuggestionsIntoView();
                        },
                        style: AppTypography.body(context).copyWith(
                          color: Colors.white,
                        ),
                        cursorColor: AppColors.seedGold,
                        decoration: InputDecoration(
                          hintText: 'Search or type a habit…',
                          hintStyle: AppTypography.body(context).copyWith(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          suffixIcon: _anchorController.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear',
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  onPressed: _clearAnchorSelection,
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusInput),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusInput),
                            borderSide: const BorderSide(
                              color: AppColors.seedGold,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                      if (_showAnchorSuggestions && _anchorEnabled)
                        _buildAnchorSuggestions(context),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.seedGold,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusInput),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: AppTypography.button(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
