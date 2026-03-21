import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '_step_header.dart';

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
    final white40 = Colors.white.withValues(alpha: 0.4);
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
              StepHeader(
                overline: 'YOUR TOOLS',
                title: 'Built for\nreal growth.',
                subtitle: 'Everything you need in one place.',
                titleColor: Colors.white,
                subtitleColor: white40,
                overlineColor: white40,
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
            color: Colors.white.withValues(alpha: 0.07),
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
                color: AppColors.honeyText.withValues(alpha: 0.9),
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
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
