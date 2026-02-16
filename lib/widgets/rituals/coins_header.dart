import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

/// Header widget displaying today's progress with a circular ring and coin counter.
class CoinsHeader extends StatefulWidget {
  final int totalCoins;
  final GlobalKey? coinTargetKey;
  final int completedCount;
  final int totalCount;

  const CoinsHeader({
    super.key,
    required this.totalCoins,
    this.coinTargetKey,
    this.completedCount = 0,
    this.totalCount = 0,
  });

  @override
  State<CoinsHeader> createState() => _CoinsHeaderState();
}

class _CoinsHeaderState extends State<CoinsHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _shineController;
  late Animation<double> _shineAnimation;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _shineAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shineController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Start the shine animation with a delay and repeat
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _shineController.repeat(
          period: const Duration(milliseconds: 3500),
        );
      }
    });
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = widget.totalCount > 0
        ? (widget.completedCount / widget.totalCount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.forestGreen,
                  AppColors.mossGreen.withValues(alpha: 0.8),
                ]
              : [
                  AppColors.mintGreen.withValues(alpha: 0.3),
                  AppColors.offWhite,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : AppColors.mossGreen.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Progress ring
          _buildProgressRing(progress, isDark),
          const SizedBox(width: 16),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Progress",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.lightest : AppColors.darkest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.completedCount} of ${widget.totalCount} rituals completed',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.lightest.withValues(alpha: 0.7)
                        : AppColors.dark.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Coins display with shine animation
          Container(
            key: widget.coinTargetKey,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Coin icon with subtle glow
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.gold, AppColors.gold.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '¢',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Animated shining coin counter
                AnimatedBuilder(
                  animation: _shineAnimation,
                  builder: (context, child) {
                    return ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            isDark
                                ? AppColors.gold
                                : AppColors.gold,
                            const Color(0xFFFFFFFF),
                            isDark
                                ? AppColors.gold
                                : AppColors.gold,
                          ],
                          stops: [
                            (_shineAnimation.value - 0.3).clamp(0.0, 1.0),
                            _shineAnimation.value.clamp(0.0, 1.0),
                            (_shineAnimation.value + 0.3).clamp(0.0, 1.0),
                          ],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcIn,
                      child: child,
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      '${widget.totalCoins}',
                      key: ValueKey(widget.totalCoins),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRing(double progress, bool isDark) {
    final progressColor = isDark ? AppColors.light : AppColors.medium;
    final trackColor = isDark
        ? AppColors.lightest.withValues(alpha: 0.2)
        : AppColors.dark.withValues(alpha: 0.15);
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
              strokeWidth: 5,
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
                  strokeWidth: 5,
                ),
              );
            },
          ),
          // Percentage text
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.lightest : AppColors.darkest,
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

    // Draw arc from top (-90 degrees = -pi/2)
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
