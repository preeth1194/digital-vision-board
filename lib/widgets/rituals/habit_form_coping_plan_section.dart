import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';

// ============================================================================
// HabitFormCopingPlanSection
// ============================================================================

/// Stateless widget extracted from [_buildCopingPlanSection] in add_habit_modal.dart.
/// Displays the "Safety Net" IF/THEN coping-plan fields.
class HabitFormCopingPlanSection extends StatelessWidget {
  final TextEditingController triggerController;
  final TextEditingController actionController;
  final String? triggerError;
  final String? actionError;
  final VoidCallback onClearTriggerError;
  final VoidCallback onClearActionError;

  const HabitFormCopingPlanSection({
    super.key,
    required this.triggerController,
    required this.actionController,
    this.triggerError,
    this.actionError,
    required this.onClearTriggerError,
    required this.onClearActionError,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
      backgroundColor: Colors.transparent,
      decoration: habitSectionDecoration(colorScheme),
      separatorColor: habitSectionSeparatorColor(colorScheme),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'IF',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: colorScheme.onTertiaryContainer,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: triggerController,
                      maxLength: 200,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      style: AppTypography.body(context),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: "I'm feeling too tired...",
                        hintStyle: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                          fontSize: 14,
                        ),
                        errorText: triggerError,
                        errorStyle: AppTypography.caption(
                          context,
                        ).copyWith(color: colorScheme.error, fontSize: 12),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: triggerError != null
                                ? colorScheme.error
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: triggerError != null
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.only(bottom: 4),
                        isDense: true,
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'THEN',
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: actionController,
                      maxLength: 200,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      style: AppTypography.body(context),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: "I will just do 2 minutes.",
                        hintStyle: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                          fontSize: 14,
                        ),
                        errorText: actionError,
                        errorStyle: AppTypography.caption(
                          context,
                        ).copyWith(color: colorScheme.error, fontSize: 12),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: actionError != null
                                ? colorScheme.error
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: actionError != null
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.only(bottom: 4),
                        isDense: true,
                        counterText: '',
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
}
