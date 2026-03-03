import 'dart:ui';
import 'package:flutter/material.dart';

import '../../utils/app_typography.dart';
import '../../utils/progress_growth_image.dart';

/// Header widget showing today's progress ring and streak info.
class DailyProgressHeader extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final int bestStreak;

  const DailyProgressHeader({
    super.key,
    this.completedCount = 0,
    this.totalCount = 0,
    this.bestStreak = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = totalCount > 0
        ? (completedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;

    final glassFill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.55);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: glassFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
        children: [
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bestStreak > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "You\u2019re on a",
                        style: AppTypography.bodySmall(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '$bestStreak-day streak!',
                            style: AppTypography.heading3(context).copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '\uD83D\uDD25',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Text(
                    '$completedCount of $totalCount completed',
                    style: AppTypography.heading3(context).copyWith(
                      color: colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Percent growth image
          _buildProgressImage(context, progress),
        ],
      ),
          ),
        ),
      ),
    );
  }

  static Widget _buildProgressImage(BuildContext context, double progress) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = (progress * 100).round();
    final assetPath = ProgressGrowthImage.assetForProgress(progress);

    return SizedBox(
      width: 84,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.linear,
              switchOutCurve: Curves.linear,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: Image.asset(
                assetPath,
                key: ValueKey<String>(assetPath),
                width: 72,
                height: 72,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$percentage%',
                style: AppTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
