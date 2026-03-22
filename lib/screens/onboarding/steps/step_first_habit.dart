import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../../../widgets/rituals/habit_form_constants.dart';
import '../onboarding_first_habit_draft.dart';
import '../widgets/onboarding_bottom_actions.dart';
import '_step_header.dart';

class StepFirstHabit extends StatefulWidget {
  final OnboardingFirstHabitDraft draft;
  final VoidCallback notifyParent;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const StepFirstHabit({
    super.key,
    required this.draft,
    required this.notifyParent,
    required this.onNext,
    this.onBack,
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
                      color: AppColors.cloudWhite,
                    ),
                  ),
                ),
                for (final cat in kHabitCategories)
                  ListTile(
                    title: Text(
                      cat,
                      style: AppTypography.body(ctx).copyWith(
                        color: AppColors.cloudWhite,
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

  Widget _copingPlanField({
    required BuildContext context,
    required String semanticLabel,
    required String labelText,
    required Color labelAccent,
    required TextEditingController controller,
    required String hint,
  }) {
    final borderRadius = BorderRadius.circular(AppSpacing.radiusInput);
    return Semantics(
      label: semanticLabel,
      textField: true,
      child: TextField(
        controller: controller,
        maxLength: 200,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        style: AppTypography.body(context).copyWith(
          color: AppColors.cloudWhite,
        ),
        cursorColor: AppColors.seedGold,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: AppTypography.caption(context).copyWith(
            color: labelAccent.withValues(alpha: 0.88),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
          floatingLabelStyle: AppTypography.caption(context).copyWith(
            color: labelAccent,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
          hintText: hint,
          hintStyle: AppTypography.body(context).copyWith(
            color: AppColors.cloudWhite.withValues(alpha: 0.42),
            fontSize: 14,
          ),
          counterStyle: AppTypography.caption(context).copyWith(
            color: AppColors.cloudWhite.withValues(alpha: 0.35),
          ),
          filled: true,
          fillColor: AppColors.cloudWhite.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: AppColors.cloudWhite.withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: AppColors.cloudWhite.withValues(alpha: 0.22),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: const BorderSide(
              color: AppColors.seedGold,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelMuted = AppColors.cloudWhite.withValues(alpha: 0.5);
    final bodyMuted = AppColors.cloudWhite.withValues(alpha: 0.62);
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
                      titleColor: AppColors.cloudWhite,
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
                        color: AppColors.cloudWhite,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: AppColors.seedGold,
                      decoration: InputDecoration(
                        hintText: 'e.g. Morning stretch',
                        hintStyle: AppTypography.body(context).copyWith(
                          color: AppColors.cloudWhite.withValues(alpha: 0.58),
                        ),
                        filled: true,
                        fillColor: AppColors.cloudWhite.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusInput),
                          borderSide: BorderSide(
                            color: AppColors.cloudWhite.withValues(alpha: 0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusInput),
                          borderSide: BorderSide(
                            color: AppColors.cloudWhite.withValues(alpha: 0.22),
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
                    _copingPlanField(
                      context: context,
                      semanticLabel:
                          'If, when things feel hard — what is the situation?',
                      labelText: 'IF',
                      labelAccent: AppColors.seedGold,
                      controller: _copingIfController,
                      hint: "I'm feeling too tired...",
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _copingPlanField(
                      context: context,
                      semanticLabel:
                          'Then, your gentle plan — what will you do?',
                      labelText: 'THEN',
                      labelAccent: AppColors.sproutGreen,
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
                              color: AppColors.cloudWhite.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusInput),
                              border: Border.all(
                                color: AppColors.cloudWhite.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _category ?? 'Choose category',
                                    style: AppTypography.body(context).copyWith(
                                      color: _category != null
                                          ? AppColors.cloudWhite
                                          : AppColors.cloudWhite.withValues(alpha: 0.45),
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
                  return OnboardingBottomActions(
                    onBack: widget.onBack,
                    backIconColor: AppColors.cloudWhite,
                    primary: FilledButton(
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
                          color: AppColors.cloudWhite,
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
