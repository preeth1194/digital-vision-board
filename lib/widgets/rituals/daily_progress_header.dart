import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

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

    // #region agent log
    try {
      final _subtitleColor = isDark ? colorScheme.onSurfaceVariant.withValues(alpha: 0.7) : colorScheme.secondary.withValues(alpha: 0.65);
      File('/Users/preeth/digital-vision-board/.cursor/debug-308c67.log').writeAsStringSync(
        '${jsonEncode({"sessionId":"308c67","runId":"post-fix","hypothesisId":"A,C","location":"daily_progress_header.dart:build","message":"DailyProgressHeader colors FIXED","data":{"isDark":isDark,"subtitleColor":"0x${_subtitleColor.value.toRadixString(16)}","streakTextColor":"0x${colorScheme.onSurface.value.toRadixString(16)}","pctTextColor":"0x${colorScheme.onSurface.value.toRadixString(16)}","onSurface":"0x${colorScheme.onSurface.value.toRadixString(16)}"},"timestamp":DateTime.now().millisecondsSinceEpoch})}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
    // #endregion

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.secondary.withValues(alpha: 0.4)
            : colorScheme.outlineVariant.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? colorScheme.outlineVariant.withValues(alpha: 0.10)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today\u2019s Progress",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                        : colorScheme.secondary.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 6),
                if (bestStreak > 0)
                  Text(
                    "You\u2019re on a $bestStreak-day streak! \uD83D\uDD25",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      height: 1.2,
                    ),
                  )
                else
                  Text(
                    '$completedCount of $totalCount completed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Progress ring
          _buildProgressRing(context, progress, isDark),
        ],
      ),
    );
  }

  static Widget _buildProgressRing(BuildContext context, double progress, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final progressColor = colorScheme.primary;
    final trackColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.15)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.20);
    final percentage = (progress * 100).round();

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          CustomPaint(
            size: const Size(56, 56),
            painter: _ProgressRingPainter(
              progress: 1.0,
              color: trackColor,
              strokeWidth: 6,
            ),
          ),
          // Progress arc
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return CustomPaint(
                size: const Size(56, 56),
                painter: _ProgressRingPainter(
                  progress: value,
                  color: progressColor,
                  strokeWidth: 6,
                ),
              );
            },
          ),
          // Percentage text
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
