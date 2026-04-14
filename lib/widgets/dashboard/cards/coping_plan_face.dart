import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../models/habit_item.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';

/// Back face of the flippable habit card showing the IF/THEN coping plan.
class CopingPlanFace extends StatelessWidget {
  final HabitItem habit;
  final bool isCompleted;

  const CopingPlanFace({super.key, required this.habit, this.isCompleted = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cbt = habit.cbtEnhancements;
    final hasContent =
        cbt != null &&
        ((cbt.predictedObstacle?.isNotEmpty ?? false) ||
            (cbt.ifThenPlan?.isNotEmpty ?? false));

    final textColor = colorScheme.onSurface;
    final subtitleColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.6)
        : colorScheme.onSurfaceVariant;
    final accentColor = AppColors.completedOrange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cloudWhite.withValues(alpha: 0.08)
                  : AppColors.cloudWhite.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? AppColors.cloudWhite.withValues(alpha: 0.12)
                    : AppColors.cloudWhite.withValues(alpha: 0.7),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? AppColors.pureBlack.withValues(alpha: 0.25)
                      : AppColors.pureBlack.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: hasContent
                ? Row(
                    children: [
                      // Coping plan icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.25 : 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology_rounded,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // IF trigger
                            if (cbt.predictedObstacle?.isNotEmpty ?? false) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.error.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'IF',
                                      style: AppTypography.caption(context)
                                          .copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.error,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cbt.predictedObstacle!,
                                      style: AppTypography.bodySmall(context)
                                          .copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isCompleted
                                                ? textColor.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : textColor,
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationColor: isCompleted
                                                ? textColor.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : null,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            // THEN action
                            if (cbt.ifThenPlan?.isNotEmpty ?? false)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'THEN',
                                      style: AppTypography.caption(context)
                                          .copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.primary,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cbt.ifThenPlan!,
                                      style: AppTypography.bodySmall(context)
                                          .copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isCompleted
                                                ? textColor.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : textColor,
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationColor: isCompleted
                                                ? textColor.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : null,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // Micro version / reward chips
                      if (cbt.microVersion?.isNotEmpty ?? false) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Micro',
                            style: AppTypography.caption(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        color: subtitleColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'No coping plan set',
                        style: AppTypography.bodySmall(context).copyWith(
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                          fontStyle: FontStyle.italic,
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
