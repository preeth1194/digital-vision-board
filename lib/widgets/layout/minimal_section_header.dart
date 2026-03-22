import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

/// Hero-style section header (onboarding rhythm): optional overline, bold title,
/// subtitle. Use for top-of-screen intros; keep [AppTypography.heading3] on
/// dense lists and cards per dashboard rules.
///
/// Defaults suit light mist backgrounds; pass custom colours on tinted surfaces.
class MinimalSectionHeader extends StatelessWidget {
  const MinimalSectionHeader({
    super.key,
    this.overline,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.overlineColor,
  });

  final String? overline;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Color? subtitleColor;
  final Color? overlineColor;

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
