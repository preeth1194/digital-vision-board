import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';

/// Shared header for every onboarding step.
///
/// Renders an optional uppercase overline, a bold title, and a subtitle.
/// Defaults to dark-on-light colours; pass [titleColor] / [subtitleColor] /
/// [overlineColor] for steps with coloured backgrounds (e.g. sproutGreen).
class StepHeader extends StatelessWidget {
  final String? overline;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Color? subtitleColor;
  final Color? overlineColor;

  const StepHeader({
    super.key,
    this.overline,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.overlineColor,
  });

  @override
  Widget build(BuildContext context) {
    final tColor = titleColor ?? AppColors.forestDeep;
    final sColor = subtitleColor ?? AppColors.forestDeep.withValues(alpha: 0.5);
    final oColor = overlineColor ?? sColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overline != null) ...[
          Text(
            overline!,
            style: AppTypography.caption(context).copyWith(
              color: oColor,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          title,
          style: AppTypography.heading1(context).copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: tColor,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: AppTypography.body(context).copyWith(color: sColor),
        ),
      ],
    );
  }
}
