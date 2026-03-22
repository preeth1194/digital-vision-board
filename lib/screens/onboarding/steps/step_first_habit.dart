import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../../../widgets/rituals/habit_form_constants.dart';
import '../onboarding_first_habit_draft.dart';
import '_step_header.dart';

class StepFirstHabit extends StatefulWidget {
  final OnboardingFirstHabitDraft draft;
  final VoidCallback notifyParent;
  final VoidCallback onNext;

  const StepFirstHabit({
    super.key,
    required this.draft,
    required this.notifyParent,
    required this.onNext,
  });

  @override
  State<StepFirstHabit> createState() => _StepFirstHabitState();
}

class _StepFirstHabitState extends State<StepFirstHabit> {
  final _nameController = TextEditingController();
  final _copingIfController = TextEditingController();
  final _copingThenController = TextEditingController();
  String? _category = 'Health';

  @override
  void initState() {
    super.initState();
    if (widget.draft.name.isNotEmpty) {
      _nameController.text = widget.draft.name;
    }
    if (widget.draft.copingIf.isNotEmpty) {
      _copingIfController.text = widget.draft.copingIf;
    }
    if (widget.draft.copingThen.isNotEmpty) {
      _copingThenController.text = widget.draft.copingThen;
    }
    if (widget.draft.category != null) {
      _category = widget.draft.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _copingIfController.dispose();
    _copingThenController.dispose();
    super.dispose();
  }

  Future<void> _openCategoryPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cloudDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusCard),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    'Category',
                    style: AppTypography.heading3(ctx).copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                for (final cat in kHabitCategories)
                  ListTile(
                    title: Text(
                      cat,
                      style: AppTypography.body(ctx).copyWith(
                        color: Colors.white,
                      ),
                    ),
                    trailing: _category == cat
                        ? Icon(
                            Icons.check_circle,
                            color: AppColors.seedGold,
                          )
                        : null,
                    onTap: () => Navigator.pop(ctx, cat),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _category = picked);
      widget.notifyParent();
    }
  }

  void _onContinue() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    widget.draft.habitId ??=
        DateTime.now().millisecondsSinceEpoch.toString();
    widget.draft.name = name;
    widget.draft.category = _category;
    widget.draft.copingIf = _copingIfController.text.trim();
    widget.draft.copingThen = _copingThenController.text.trim();
    widget.notifyParent();
    widget.onNext();
  }

  Widget _ifThenRow({
    required BuildContext context,
    required String badge,
    required Color badgeColor,
    required Color badgeBg,
    required TextEditingController controller,
    required String hint,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
          ),
          alignment: Alignment.center,
          child: Text(
            badge,
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: controller,
            maxLength: 200,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            style: AppTypography.body(context).copyWith(
              color: Colors.white,
            ),
            cursorColor: AppColors.seedGold,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.body(context).copyWith(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 14,
              ),
              counterStyle: AppTypography.caption(context).copyWith(
                color: Colors.white.withValues(alpha: 0.35),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelMuted = Colors.white.withValues(alpha: 0.5);
    final bodyMuted = Colors.white.withValues(alpha: 0.62);
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
                      title: 'Plant one\nsmall habit.',
                      subtitle:
                          'Start with a name. Next, you can add optional steps, a reminder, and inspiration photos.',
                      titleColor: Colors.white,
                      subtitleColor: labelMuted,
                      overlineColor: labelMuted,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'HABIT NAME',
                      style: AppTypography.caption(context).copyWith(
                        color: labelMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _nameController,
                      style: AppTypography.body(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: AppColors.seedGold,
                      decoration: InputDecoration(
                        hintText: 'e.g. Morning stretch',
                        hintStyle: AppTypography.body(context).copyWith(
                          color: Colors.white.withValues(alpha: 0.58),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusInput),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusInput),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.22),
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
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'COPING PLAN (OPTIONAL)',
                      style: AppTypography.caption(context).copyWith(
                        color: labelMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'If things feel hard, plan a gentle “if / then” — same idea as the full habit form.',
                      style: AppTypography.secondary(context).copyWith(
                        color: bodyMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ifThenRow(
                      context: context,
                      badge: 'IF',
                      badgeColor: AppColors.seedGold,
                      badgeBg: AppColors.seedGold.withValues(alpha: 0.18),
                      controller: _copingIfController,
                      hint: "I'm feeling too tired...",
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Container(
                        height: 16,
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sproutGreen.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    _ifThenRow(
                      context: context,
                      badge: 'THEN',
                      badgeColor: AppColors.sproutGreen,
                      badgeBg: AppColors.sproutGreen.withValues(alpha: 0.18),
                      controller: _copingThenController,
                      hint: 'I will just do 2 minutes.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'CATEGORY',
                      style: AppTypography.caption(context).copyWith(
                        color: labelMuted,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      label: 'Category, ${_category ?? "none"}',
                      button: true,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusInput),
                          onTap: _openCategoryPicker,
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
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
                                    _category ?? 'Choose category',
                                    style: AppTypography.body(context).copyWith(
                                      color: _category != null
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.45),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.seedGold.withValues(alpha: 0.9),
                                ),
                              ],
                            ),
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
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (context, value, _) {
                  final ok = value.text.trim().isNotEmpty;
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: ok ? _onContinue : null,
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
                      child: Text(
                        'Continue',
                        style: AppTypography.button(context).copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
