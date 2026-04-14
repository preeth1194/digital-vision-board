import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';

/// Checkpoint circle for the timeline — orange with checkmark when completed,
/// grey outline when incomplete.
class TimelineCheckpoint extends StatelessWidget {
  final bool isCompleted;
  final VoidCallback? onTap;
  const TimelineCheckpoint({super.key, required this.isCompleted, this.onTap});

  static const _completedColor = AppColors.completedOrange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.3)
        : colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted ? _completedColor : Colors.transparent,
          border: Border.all(
            color: isCompleted ? _completedColor : borderColor,
            width: isCompleted ? 0 : 1.5,
          ),
        ),
        child: isCompleted
            ? Icon(Icons.check_rounded, color: colorScheme.onPrimary, size: 16)
            : null,
      ),
    );
  }
}

/// Vertical dashed line segment for the timeline.
class TimelineDash extends StatelessWidget {
  const TimelineDash({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.15)
        : colorScheme.outline;

    return SizedBox(
      width: 2,
      child: CustomPaint(
        painter: DashedLinePainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Paints a vertical dashed line.
class DashedLinePainter extends CustomPainter {
  final Color color;
  const DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashHeight = 4.0;
    const gapHeight = 4.0;
    final centerX = size.width / 2;
    double y = 0;

    while (y < size.height) {
      canvas.drawLine(
        Offset(centerX, y),
        Offset(centerX, (y + dashHeight).clamp(0, size.height)),
        paint,
      );
      y += dashHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
