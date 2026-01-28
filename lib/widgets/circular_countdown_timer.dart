import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A circular countdown timer widget that displays remaining time/progress
/// as a reducing circle, similar to a clock countdown.
class CircularCountdownTimer extends StatelessWidget {
  /// Progress value from 0.0 to 1.0 representing remaining portion
  /// (1.0 = full circle, 0.0 = empty circle)
  final double progress;
  
  /// Remaining time text to display in center
  final String remainingText;
  
  /// Elapsed time text to display below
  final String? elapsedText;
  
  /// Target text to display (optional)
  final String? targetText;
  
  /// Size of the circular timer
  final double size;
  
  /// Stroke width of the circle
  final double strokeWidth;
  
  /// Background color of the circle
  final Color backgroundColor;
  
  /// Progress color (remaining portion)
  final Color progressColor;
  
  /// Text color for center text
  final Color textColor;

  const CircularCountdownTimer({
    super.key,
    required this.progress,
    required this.remainingText,
    this.elapsedText,
    this.targetText,
    this.size = 300,
    this.strokeWidth = 20,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.progressColor = const Color(0xFF2196F3),
    this.textColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor = backgroundColor;
    final effectiveProgressColor = progressColor;
    final effectiveTextColor = textColor;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress indicator
          CustomPaint(
            size: Size(size, size),
            painter: _CircularCountdownPainter(
              progress: progress.clamp(0.0, 1.0),
              backgroundColor: effectiveBackgroundColor,
              progressColor: effectiveProgressColor,
              strokeWidth: strokeWidth,
            ),
          ),
          // Center text with remaining time
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                remainingText,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: effectiveTextColor,
                  fontSize: size * 0.15,
                ),
                textAlign: TextAlign.center,
              ),
              if (elapsedText != null) ...[
                const SizedBox(height: 8),
                Text(
                  elapsedText!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: effectiveTextColor.withOpacity(0.7),
                    fontSize: size * 0.06,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (targetText != null) ...[
                const SizedBox(height: 4),
                Text(
                  targetText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: effectiveTextColor.withOpacity(0.5),
                    fontSize: size * 0.05,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing the circular countdown
class _CircularCountdownPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (remaining portion)
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularCountdownPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Draw background circle (full circle)
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Draw progress arc (remaining portion)
    // Start from top (-90 degrees) and sweep clockwise
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    // Calculate sweep angle: 360 degrees * progress
    // Progress of 1.0 = full circle, 0.0 = no circle
    final sweepAngle = 2 * math.pi * progress;
    
    // Draw arc starting from top (-π/2) and sweeping clockwise
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularCountdownPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
