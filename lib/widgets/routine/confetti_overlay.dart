import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';

/// A confetti celebration overlay that displays animated particles.
class ConfettiOverlay extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;
  final int particleCount;

  /// Optional emission origin in global coordinates. When provided, particles
  /// burst from this point instead of the center of the overlay.
  final Offset? origin;

  const ConfettiOverlay({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 1500),
    this.particleCount = 50,
    this.origin,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = math.Random();

  static const _colors = [
    AppColors.gold,
    AppColors.mossGreen,
    AppColors.mintGreen,
    AppColors.confettiPink,
    AppColors.confettiOrange,
    AppColors.sageGreen,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _particles = List.generate(widget.particleCount, (_) => _createParticle());

    // Trigger haptic feedback
    HapticFeedback.mediumImpact();

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  _Particle _createParticle() {
    // Bias upward: angles mostly in the upper half (-30 to 210 degrees)
    final angle = -math.pi * 0.15 + _random.nextDouble() * math.pi * 1.3;
    final speed = 40 + _random.nextDouble() * 80;
    final size = 4.0 + _random.nextDouble() * 5.0;
    final rotationSpeed = (_random.nextDouble() - 0.5) * 6;

    return _Particle(
      color: _colors[_random.nextInt(_colors.length)],
      angle: -angle, // negate so particles fly upward
      speed: speed,
      size: size,
      rotationSpeed: rotationSpeed,
      shape: _random.nextBool() ? _ParticleShape.circle : _ParticleShape.rectangle,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
            origin: widget.origin,
          ),
        );
      },
    );
  }
}

enum _ParticleShape { circle, rectangle }

class _Particle {
  final Color color;
  final double angle;
  final double speed;
  final double size;
  final double rotationSpeed;
  final _ParticleShape shape;

  _Particle({
    required this.color,
    required this.angle,
    required this.speed,
    required this.size,
    required this.rotationSpeed,
    required this.shape,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset? origin;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
    this.origin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = origin?.dx ?? size.width / 2;
    final centerY = origin?.dy ?? size.height / 2;

    // Gentle gravity — particles drift down slowly
    final gravity = progress * progress * 60;

    for (final particle in particles) {
      // Calculate position with physics
      final distance = particle.speed * progress;
      final x = centerX + math.cos(particle.angle) * distance;
      final y = centerY + math.sin(particle.angle) * distance + gravity;

      // Fade out
      final opacity = (1 - progress).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // Scale down as animation progresses
      final currentSize = particle.size * (1 - progress * 0.5);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotationSpeed * progress * math.pi);

      if (particle.shape == _ParticleShape.circle) {
        canvas.drawCircle(Offset.zero, currentSize / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: currentSize,
            height: currentSize * 0.6,
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// A widget that shows a celebration animation when triggered.
class CelebrationController extends ChangeNotifier {
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  void celebrate() {
    _isPlaying = true;
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    notifyListeners();
  }
}

/// Animated checkmark that scales and fades in
class AnimatedCheckmark extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  final VoidCallback? onComplete;

  const AnimatedCheckmark({
    super.key,
    this.size = 80,
    required this.color,
    this.duration = const Duration(milliseconds: 600),
    this.onComplete,
  });

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.15),
              ),
              child: Icon(
                Icons.check_rounded,
                size: widget.size * 0.6,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}
