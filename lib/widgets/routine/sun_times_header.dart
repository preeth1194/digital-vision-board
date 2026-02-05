import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/sun_times_service.dart';
import '../../utils/app_colors.dart';

/// Header widget showing sunrise and sunset times with an arc visualization.
class SunTimesHeader extends StatelessWidget {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime currentTime;

  const SunTimesHeader({
    super.key,
    required this.sunrise,
    required this.sunset,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final progress = SunTimesService.getDayProgress(
      currentTime: currentTime,
      sunrise: sunrise,
      sunset: sunset,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.dark.withOpacity(0.5)
            : AppColors.lightest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
              ? AppColors.medium.withOpacity(0.3)
              : AppColors.light.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Times row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TimeDisplay(
                icon: Icons.wb_sunny_rounded,
                iconColor: const Color(0xFFFFB300),
                label: 'Sunrise',
                time: SunTimesService.formatTime(sunrise),
                isDark: isDark,
              ),
              _TimeDisplay(
                icon: Icons.nightlight_round,
                iconColor: const Color(0xFF5C6BC0),
                label: 'Sunset',
                time: SunTimesService.formatTime(sunset),
                isDark: isDark,
                isRight: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Arc visualization
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: _SunArcPainter(
                progress: progress,
                isDark: isDark,
                arcColor: isDark ? AppColors.medium : AppColors.dark,
                sunColor: const Color(0xFFFFB300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String time;
  final bool isDark;
  final bool isRight;

  const _TimeDisplay({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.time,
    required this.isDark,
    this.isRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isRight) ...[
          _buildIcon(),
          const SizedBox(width: 8),
        ],
        Column(
          crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.light : AppColors.medium,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.lightest : AppColors.darkest,
              ),
            ),
          ],
        ),
        if (isRight) ...[
          const SizedBox(width: 8),
          _buildIcon(),
        ],
      ],
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: iconColor.withOpacity(0.15),
      ),
      child: Icon(
        icon,
        size: 20,
        color: iconColor,
      ),
    );
  }
}

class _SunArcPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color arcColor;
  final Color sunColor;

  _SunArcPainter({
    required this.progress,
    required this.isDark,
    required this.arcColor,
    required this.sunColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height + 10;
    final radius = size.width * 0.4;

    // Draw the arc track (dashed)
    final trackPaint = Paint()
      ..color = arcColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: radius,
    );

    // Draw arc from left to right (180 degrees arc)
    canvas.drawArc(
      arcRect,
      math.pi, // Start angle (left)
      math.pi, // Sweep angle (180 degrees)
      false,
      trackPaint,
    );

    // Draw progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = arcColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        arcRect,
        math.pi,
        math.pi * progress,
        false,
        progressPaint,
      );
    }

    // Draw sun indicator
    final angle = math.pi + (math.pi * progress);
    final sunX = centerX + radius * math.cos(angle);
    final sunY = centerY + radius * math.sin(angle);

    // Sun glow
    final glowPaint = Paint()
      ..color = sunColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(sunX, sunY), 12, glowPaint);

    // Sun circle
    final sunPaint = Paint()..color = sunColor;
    canvas.drawCircle(Offset(sunX, sunY), 8, sunPaint);

    // Sun inner highlight
    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.5);
    canvas.drawCircle(Offset(sunX - 2, sunY - 2), 3, highlightPaint);

    // Draw horizon line
    final horizonPaint = Paint()
      ..color = arcColor.withOpacity(0.1)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(centerX - radius - 20, centerY),
      Offset(centerX + radius + 20, centerY),
      horizonPaint,
    );

    // Draw time markers
    _drawTimeMarker(canvas, centerX - radius, centerY, '6AM', arcColor);
    _drawTimeMarker(canvas, centerX, centerY - radius - 5, '12PM', arcColor);
    _drawTimeMarker(canvas, centerX + radius, centerY, '6PM', arcColor);
  }

  void _drawTimeMarker(Canvas canvas, double x, double y, String label, Color color) {
    // Small adjustment for text positioning would be done with TextPainter
    // For simplicity, we skip text here as Flutter handles it better in widgets
  }

  @override
  bool shouldRepaint(_SunArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
