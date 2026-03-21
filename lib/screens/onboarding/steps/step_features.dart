import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';


class StepFeatures extends StatelessWidget {
  final VoidCallback onNext;

  const StepFeatures({super.key, required this.onNext});

  static const _features = [
    ('01', 'Habit Tracking', 'Streaks, badges & reminders'),
    ('02', 'Vision Board', 'Tap-to-explore goal boards'),
    ('03', 'Affirmations', 'Daily mindset rituals'),
    ('04', 'Progress Insights', 'Charts & growth analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cloudDark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(
                'YOUR TOOLS',
                style: AppTypography.caption(context).copyWith(
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Built for\nreal growth.',
                style: AppTypography.heading1(context).copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Everything you need in one place.',
                style: AppTypography.body(context).copyWith(
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _features
                      .map((f) => _FeatureRow(
                            number: f.$1,
                            title: f.$2,
                            subtitle: f.$3,
                          ))
                      .toList(),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.seedGold,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusInput),
                    ),
                  ),
                  child: Text(
                    "Let's go",
                    style: AppTypography.button(context).copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.07),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: AppSpacing.xl,
            child: Text(
              number,
              style: AppTypography.bodySmall(context).copyWith(
                fontWeight: FontWeight.w800,
                // seedGold used as non-text icon-like accent on dark bg — acceptable
                color: AppColors.honeyText.withOpacity(0.9),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodySmall(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption(context).copyWith(
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
