import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/sun_times_service.dart';

/// Enhanced header widget showing sunrise/sunset with animated sun/moon arc visualization.
/// Features:
/// - Sky gradient background that changes based on time of day
/// - Sun visualization with animated rays during day (6 AM - 6 PM)
/// - Moon visualization with craters and twinkling stars during night (6 PM - 6 AM)
/// - Interactive timeline slider to preview different times
/// - Smooth animations for all celestial bodies
/// - Tap on sunrise/sunset labels to refresh location
/// - External previewTime control for scroll-linked animations
class SunTimesHeader extends StatefulWidget {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime currentTime;
  /// External preview time (e.g., from timeline scroll position)
  /// When set, overrides internal slider preview and shows this time
  final DateTime? previewTime;
  final ValueChanged<DateTime>? onTimePreview;
  final VoidCallback? onRefreshLocation;

  const SunTimesHeader({
    super.key,
    required this.sunrise,
    required this.sunset,
    required this.currentTime,
    this.previewTime,
    this.onTimePreview,
    this.onRefreshLocation,
  });

  @override
  State<SunTimesHeader> createState() => _SunTimesHeaderState();
}

class _SunTimesHeaderState extends State<SunTimesHeader>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _sunPulseController;
  late AnimationController _rayController;
  late AnimationController _starController;
  
  // Display time priority: external previewTime > current time
  DateTime get _displayTime => widget.previewTime ?? widget.currentTime;

  @override
  void initState() {
    super.initState();
    
    // Sun pulse animation (2s cycle)
    _sunPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    // Ray opacity animation (1.5s cycle)
    _rayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Star twinkle animation (2s cycle)
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sunPulseController.dispose();
    _rayController.dispose();
    _starController.dispose();
    super.dispose();
  }

  // Convert DateTime to minutes since midnight
  int _toMinutes(DateTime time) {
    return time.hour * 60 + time.minute;
  }

  // Check if sun should be visible (between sunrise and sunset)
  bool get _isSunVisible {
    final currentMinutes = _toMinutes(_displayTime);
    final sunriseMinutes = _toMinutes(widget.sunrise);
    final sunsetMinutes = _toMinutes(widget.sunset);
    return currentMinutes >= sunriseMinutes && currentMinutes <= sunsetMinutes;
  }

  // Check if moon should be visible (before sunrise or after sunset)
  bool get _isMoonVisible {
    final currentMinutes = _toMinutes(_displayTime);
    final sunriseMinutes = _toMinutes(widget.sunrise);
    final sunsetMinutes = _toMinutes(widget.sunset);
    return currentMinutes < sunriseMinutes || currentMinutes > sunsetMinutes;
  }

  // Get sun position on arc (0 = sunrise/left, 1 = sunset/right)
  double get _sunPosition {
    final currentMinutes = _toMinutes(_displayTime);
    final sunriseMinutes = _toMinutes(widget.sunrise);
    final sunsetMinutes = _toMinutes(widget.sunset);
    
    if (currentMinutes < sunriseMinutes) return -0.2; // Below horizon (before sunrise)
    if (currentMinutes > sunsetMinutes) return 1.2; // Below horizon (after sunset)
    
    final dayDuration = sunsetMinutes - sunriseMinutes;
    if (dayDuration <= 0) return 0.5; // Fallback
    
    return (currentMinutes - sunriseMinutes) / dayDuration;
  }

  // Get moon position on arc (0 = sunset/left, 1 = sunrise/right)
  double get _moonPosition {
    final currentMinutes = _toMinutes(_displayTime);
    final sunriseMinutes = _toMinutes(widget.sunrise);
    final sunsetMinutes = _toMinutes(widget.sunset);
    
    // Moon is visible from sunset to sunrise (next day)
    // Night duration = (24*60 - sunsetMinutes) + sunriseMinutes
    final nightDuration = (24 * 60 - sunsetMinutes) + sunriseMinutes;
    if (nightDuration <= 0) return 0.5; // Fallback
    
    if (currentMinutes >= sunriseMinutes && currentMinutes <= sunsetMinutes) {
      return -0.2; // Below horizon (during day)
    }
    
    // Calculate position based on time since sunset
    int minutesSinceSunset;
    if (currentMinutes > sunsetMinutes) {
      // Evening (after sunset, same day)
      minutesSinceSunset = currentMinutes - sunsetMinutes;
    } else {
      // Morning (before sunrise, next day from sunset's perspective)
      minutesSinceSunset = (24 * 60 - sunsetMinutes) + currentMinutes;
    }
    
    return minutesSinceSunset / nightDuration;
  }

  // Get gradient colors based on time relative to sunrise/sunset
  List<Color> get _skyGradientColors {
    final currentMinutes = _toMinutes(_displayTime);
    final sunriseMinutes = _toMinutes(widget.sunrise);
    final sunsetMinutes = _toMinutes(widget.sunset);
    
    // Calculate midday
    final middayMinutes = (sunriseMinutes + sunsetMinutes) ~/ 2;
    
    // Dawn/dusk transition periods (1 hour before/after sunrise/sunset)
    final dawnStart = sunriseMinutes - 60;
    final dawnEnd = sunriseMinutes + 60;
    final duskStart = sunsetMinutes - 60;
    final duskEnd = sunsetMinutes + 60;
    
    if (currentMinutes >= dawnStart && currentMinutes < sunriseMinutes) {
      // Dawn (before sunrise)
      return [
        const Color(0xFF2C3E50), // Dark blue
        const Color(0xFFE67E22), // Sunrise orange
        const Color(0xFF5D6D7E), // Muted blue
      ];
    } else if (currentMinutes >= sunriseMinutes && currentMinutes < dawnEnd) {
      // Early morning (just after sunrise)
      return [
        const Color(0xFF87CEEB), // Sky blue
        const Color(0xFFFDB462), // Orange
        const Color(0xFFe8f0e0), // Light green
      ];
    } else if (currentMinutes >= dawnEnd && currentMinutes < middayMinutes) {
      // Morning
      return [
        const Color(0xFF87CEEB), // Sky blue
        const Color(0xFFFDB462), // Orange
        const Color(0xFFe8f0e0), // Light green
      ];
    } else if (currentMinutes >= middayMinutes && currentMinutes < duskStart) {
      // Afternoon
      return [
        const Color(0xFF87CEEB), // Sky blue
        const Color(0xFFFFB347), // Light orange
        const Color(0xFFe8f0e0), // Light green
      ];
    } else if (currentMinutes >= duskStart && currentMinutes <= sunsetMinutes) {
      // Evening (approaching sunset)
      return [
        const Color(0xFF5D6D7E), // Muted blue
        const Color(0xFFE67E22), // Sunset orange
        const Color(0xFF2C3E50), // Dark blue
      ];
    } else if (currentMinutes > sunsetMinutes && currentMinutes < duskEnd) {
      // Dusk (just after sunset)
      return [
        const Color(0xFF2C3E50), // Dark blue
        const Color(0xFFE67E22), // Sunset orange
        const Color(0xFF34495E), // Darker blue
      ];
    } else {
      // Night
      return [
        const Color(0xFF0D1B2A), // Deep navy
        const Color(0xFF1B263B), // Dark blue
        const Color(0xFF415A77), // Muted blue
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _skyGradientColors,
          ),
        ),
        child: Stack(
          children: [
            // Time labels (sunrise/sunset) - tappable to refresh location
            Positioned(
              top: 8,
              left: 12,
              child: GestureDetector(
                onTap: widget.onRefreshLocation,
                child: _buildTimeLabel(
                  'Sunrise: ${SunTimesService.formatTime(widget.sunrise)}',
                  showRefreshHint: widget.onRefreshLocation != null,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: GestureDetector(
                onTap: widget.onRefreshLocation,
                child: _buildTimeLabel(
                  'Sunset: ${SunTimesService.formatTime(widget.sunset)}',
                  showRefreshHint: widget.onRefreshLocation != null,
                ),
              ),
            ),
            
            // Arc visualization
            Positioned(
              top: 30,
              left: 16,
              right: 16,
              bottom: 8,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _sunPulseController,
                    _rayController,
                    _starController,
                  ]),
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(double.infinity, 70),
                      painter: _SunMoonArcPainter(
                        sunPosition: _sunPosition,
                        moonPosition: _moonPosition,
                        isSunVisible: _isSunVisible,
                        isMoonVisible: _isMoonVisible,
                        sunPulseValue: _sunPulseController.value,
                        rayValue: _rayController.value,
                        starValue: _starController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeLabel(String text, {bool showRefreshHint = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          if (showRefreshHint) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.refresh,
              size: 12,
              color: Colors.white.withOpacity(0.8),
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

}

/// Custom painter for the sun/moon arc visualization
class _SunMoonArcPainter extends CustomPainter {
  final double sunPosition;
  final double moonPosition;
  final bool isSunVisible;
  final bool isMoonVisible;
  final double sunPulseValue;
  final double rayValue;
  final double starValue;

  _SunMoonArcPainter({
    required this.sunPosition,
    required this.moonPosition,
    required this.isSunVisible,
    required this.isMoonVisible,
    required this.sunPulseValue,
    required this.rayValue,
    required this.starValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    // Arc spans the full width, so radius is half the width
    final radius = size.width / 2;
    // Position center so the arc's highest point is within the visible area
    // The highest point of the arc is at centerY - radius
    // We want the highest point to be around 20-25px from top
    final centerY = size.height + radius - 50;

    // Arc line is hidden - only sun/moon are visible

    // Draw sun if visible
    if (isSunVisible && sunPosition >= 0 && sunPosition <= 1) {
      final sunPoint = _getArcPoint(sunPosition, centerX, centerY, radius);
      _drawSun(canvas, sunPoint);
    }

    // Draw moon if visible
    if (isMoonVisible && moonPosition >= 0 && moonPosition <= 1) {
      final moonPoint = _getArcPoint(moonPosition, centerX, centerY, radius);
      _drawMoon(canvas, moonPoint);
    }
  }

  Offset _getArcPoint(double progress, double centerX, double centerY, double radius) {
    final angle = math.pi * progress;
    final x = centerX + math.cos(math.pi - angle) * radius;
    final y = centerY - math.sin(math.pi - angle) * radius;
    return Offset(x, y);
  }

  void _drawSun(Canvas canvas, Offset center) {
    final sunRadius = 16.0 + (sunPulseValue * 2);
    
    // Sun glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFDB462).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, sunRadius + 8, glowPaint);

    // Sun body
    final sunPaint = Paint()..color = const Color(0xFFFFD700);
    canvas.drawCircle(center, sunRadius, sunPaint);

    // Sun rays
    _drawSunRays(canvas, center, sunRadius);
  }

  void _drawSunRays(Canvas canvas, Offset center, double sunRadius) {
    final rayPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * math.pi / 180;
      final opacity = 0.5 + (rayValue * 0.5) * ((i % 2 == 0) ? 1 : (1 - rayValue));
      
      rayPaint.color = const Color(0xFFFFD700).withOpacity(opacity);
      
      final innerRadius = sunRadius + 4;
      final outerRadius = sunRadius + 12;
      
      final x1 = center.dx + math.cos(angle) * innerRadius;
      final y1 = center.dy + math.sin(angle) * innerRadius;
      final x2 = center.dx + math.cos(angle) * outerRadius;
      final y2 = center.dy + math.sin(angle) * outerRadius;
      
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), rayPaint);
    }
  }

  void _drawMoon(Canvas canvas, Offset center) {
    const moonRadius = 14.0;
    
    // Moon glow
    final glowPaint = Paint()
      ..color = const Color(0xFFE0E0E0).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, moonRadius + 8, glowPaint);

    // Moon body
    final moonPaint = Paint()..color = const Color(0xFFF0F0F0);
    canvas.drawCircle(center, moonRadius, moonPaint);

    // Moon craters
    final craterPaint = Paint()..color = const Color(0xFFD0D0D0);
    canvas.drawCircle(Offset(center.dx - 4, center.dy - 2), 3, craterPaint);
    canvas.drawCircle(Offset(center.dx + 3, center.dy + 4), 2, craterPaint);
    canvas.drawCircle(Offset(center.dx + 5, center.dy - 3), 1.5, craterPaint);

    // Twinkling stars around moon
    _drawStars(canvas, center);
  }

  void _drawStars(Canvas canvas, Offset moonCenter) {
    final starPaint = Paint()..color = Colors.white;
    final random = math.Random(42); // Fixed seed for consistent positions

    for (int i = 0; i < 5; i++) {
      final angle = (i * 72) * math.pi / 180;
      final distance = 30 + random.nextDouble() * 15;
      final x = moonCenter.dx + math.cos(angle) * distance;
      final y = moonCenter.dy + math.sin(angle) * distance;
      
      // Staggered twinkle effect
      final staggerOffset = i * 0.2;
      final twinkle = ((starValue + staggerOffset) % 1.0);
      final opacity = 0.3 + (twinkle * 0.7);
      final scale = 1.0 + (twinkle * 0.5);
      
      starPaint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), 1.5 * scale, starPaint);
    }
  }

  @override
  bool shouldRepaint(_SunMoonArcPainter oldDelegate) {
    return oldDelegate.sunPosition != sunPosition ||
        oldDelegate.moonPosition != moonPosition ||
        oldDelegate.isSunVisible != isSunVisible ||
        oldDelegate.isMoonVisible != isMoonVisible ||
        oldDelegate.sunPulseValue != sunPulseValue ||
        oldDelegate.rayValue != rayValue ||
        oldDelegate.starValue != starValue;
  }
}
