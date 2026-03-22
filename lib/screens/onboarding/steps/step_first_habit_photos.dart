import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/cbt_enhancements.dart';
import '../../../models/habit_action_step.dart';
import '../../../models/habit_item.dart';
import '../../../services/habit_storage_service.dart';
import '../../../services/notifications_service.dart';
import '../../../services/onboarding_habit_board_seed.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../onboarding_first_habit_draft.dart';
import '_step_header.dart';

/// Optional motivation photos, then persist habit + board seed + reminders.
class StepFirstHabitPhotos extends StatefulWidget {
  final OnboardingFirstHabitDraft draft;
  final VoidCallback notifyParent;
  final VoidCallback onNext;

  const StepFirstHabitPhotos({
    super.key,
    required this.draft,
    required this.notifyParent,
    required this.onNext,
  });

  @override
  State<StepFirstHabitPhotos> createState() => _StepFirstHabitPhotosState();
}

class _StepFirstHabitPhotosState extends State<StepFirstHabitPhotos> {
  bool _picking = false;
  bool _saving = false;

  List<String> get _paths => widget.draft.motivationPaths;

  Future<void> _addPhotos() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted) return;
      if (files.isNotEmpty) {
        setState(() {
          for (final x in files) {
            if (_paths.length >= 8) break;
            _paths.add(x.path);
          }
        });
        widget.notifyParent();
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removePhoto(int index) {
    setState(() => _paths.removeAt(index));
    widget.notifyParent();
  }

  String _formatTimeOfDay(BuildContext context, TimeOfDay t) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      t,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  Future<void> _onContinue() async {
    final id = widget.draft.habitId;
    final name = widget.draft.name.trim();
    if (id == null || name.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final ifPart = widget.draft.copingIf.trim();
      final thenPart = widget.draft.copingThen.trim();
      CbtEnhancements? cbtEnhancements;
      if (ifPart.isNotEmpty || thenPart.isNotEmpty) {
        cbtEnhancements = CbtEnhancements(
          predictedObstacle: ifPart.isEmpty ? null : ifPart,
          ifThenPlan: thenPart.isEmpty ? null : thenPart,
        );
      }

      final reminderOn = widget.draft.reminderEnabled;
      final t = widget.draft.reminderTime;
      final reminderMinutes = reminderOn && t != null
          ? t.hour * 60 + t.minute
          : null;
      final timeOfDayStr = reminderOn && t != null
          ? _formatTimeOfDay(context, t)
          : null;

      final stackOn = widget.draft.stackAnchorEnabled;
      final anchorText = widget.draft.stackAnchorText.trim();
      HabitChaining? chaining;
      if (stackOn &&
          (anchorText.isNotEmpty || widget.draft.stackAfterHabitId != null)) {
        chaining = HabitChaining(
          anchorHabit: anchorText.isEmpty ? null : anchorText,
          relationship: widget.draft.stackRelationship,
        );
      }

      final habit = HabitItem(
        id: id,
        name: name,
        category: widget.draft.category,
        frequency: 'Daily',
        weeklyDays: const [],
        afterHabitId: stackOn ? widget.draft.stackAfterHabitId : null,
        timeOfDay: timeOfDayStr,
        reminderMinutes: reminderMinutes,
        reminderEnabled: reminderOn && reminderMinutes != null,
        completedDates: const [],
        actionSteps: List<HabitActionStep>.from(widget.draft.actionSteps),
        chaining: chaining,
        cbtEnhancements: cbtEnhancements,
      );

      await HabitStorageService.addHabit(habit);
      await OnboardingHabitBoardSeed.apply(
        habitId: id,
        pickedImagePaths: List<String>.from(_paths),
      );

      if (!kIsWeb && NotificationsService.shouldSchedule(habit)) {
        await NotificationsService.scheduleHabitReminders(habit);
      }

      if (!mounted) return;
      widget.onNext();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelMuted = Colors.white.withValues(alpha: 0.5);
    final bodyMuted = Colors.white.withValues(alpha: 0.62);
    final canSave = widget.draft.habitId != null &&
        widget.draft.name.trim().isNotEmpty &&
        !_saving;

    return Container(
      color: AppColors.cloudDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    StepHeader(
                      overline: 'FIRST SEED',
                      title: 'Your why\n(optional).',
                      subtitle:
                          'Photos can sit on your Vision Board as a quiet reminder of what you are growing toward.',
                      titleColor: Colors.white,
                      subtitleColor: labelMuted,
                      overlineColor: labelMuted,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'WHY (OPTIONAL)',
                      style: AppTypography.caption(context).copyWith(
                        color: labelMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Add photos of your goal or motivation — they appear on your Vision Board.',
                      style: AppTypography.secondary(context).copyWith(
                        color: bodyMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_paths.isNotEmpty)
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _paths.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: AppSpacing.sm),
                          itemBuilder: (context, i) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusChip,
                                  ),
                                  child: Image.file(
                                    File(_paths[i]),
                                    width: 88,
                                    height: 88,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Material(
                                    color: AppColors.forestDeep,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      color: Colors.white,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      onPressed: () => _removePhoto(i),
                                      tooltip: 'Remove',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    if (_paths.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_picking || _paths.length >= 8)
                            ? null
                            : _addPhotos,
                        icon: _picking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                        label: Text(
                          _picking ? 'Opening…' : 'Add inspiration photos',
                          style: AppTypography.button(context).copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusInput),
                          ),
                        ),
                      ),
                    ),
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
                  onPressed: canSave ? _onContinue : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.seedGold,
                    disabledBackgroundColor:
                        AppColors.seedGold.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusInput),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
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
