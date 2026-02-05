import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Overlay widget that displays animated coins flying from a source to a target.
class CoinAnimationOverlay extends StatefulWidget {
  final Offset sourcePosition;
  final Offset targetPosition;
  final int coinCount;
  final VoidCallback onComplete;

  const CoinAnimationOverlay({
    super.key,
    required this.sourcePosition,
    required this.targetPosition,
    this.coinCount = 8,
    required this.onComplete,
  });

  @override
  State<CoinAnimationOverlay> createState() => _CoinAnimationOverlayState();
}

class _CoinAnimationOverlayState extends State<CoinAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_CoinParticle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initializeParticles();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  void _initializeParticles() {
    _particles = List.generate(widget.coinCount, (index) {
      // Stagger the start times
      final delay = index * 0.08;
      // Random horizontal offset for spread effect
      final spreadX = (_random.nextDouble() - 0.5) * 60;
      final spreadY = (_random.nextDouble() - 0.5) * 40;
      // Random size variation
      final size = 20.0 + _random.nextDouble() * 8;
      // Random rotation speed
      final rotationSpeed = 2 + _random.nextDouble() * 4;

      return _CoinParticle(
        delay: delay,
        spreadX: spreadX,
        spreadY: spreadY,
        size: size,
        rotationSpeed: rotationSpeed,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _CoinPainter(
              particles: _particles,
              progress: _controller.value,
              source: widget.sourcePosition,
              target: widget.targetPosition,
            ),
          );
        },
      ),
    );
  }
}

class _CoinParticle {
  final double delay;
  final double spreadX;
  final double spreadY;
  final double size;
  final double rotationSpeed;

  _CoinParticle({
    required this.delay,
    required this.spreadX,
    required this.spreadY,
    required this.size,
    required this.rotationSpeed,
  });
}

class _CoinPainter extends CustomPainter {
  final List<_CoinParticle> particles;
  final double progress;
  final Offset source;
  final Offset target;

  _CoinPainter({
    required this.particles,
    required this.progress,
    required this.source,
    required this.target,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final adjustedProgress = ((progress - particle.delay) / (1 - particle.delay))
          .clamp(0.0, 1.0);
      
      if (adjustedProgress <= 0) continue;

      // Eased progress for smooth motion
      final easedProgress = Curves.easeInOutCubic.transform(adjustedProgress);
      
      // Calculate position along curved path
      final midX = (source.dx + target.dx) / 2 + particle.spreadX;
      final midY = source.dy - 80 + particle.spreadY; // Arc upward
      
      // Quadratic bezier curve
      final t = easedProgress;
      final x = (1 - t) * (1 - t) * source.dx +
          2 * (1 - t) * t * midX +
          t * t * target.dx;
      final y = (1 - t) * (1 - t) * source.dy +
          2 * (1 - t) * t * midY +
          t * t * target.dy;

      // Fade out near the end
      final opacity = (1 - easedProgress).clamp(0.3, 1.0);
      
      // Scale down as it approaches target
      final scale = 1.0 - (easedProgress * 0.4);
      
      // Rotation animation
      final rotation = progress * particle.rotationSpeed * pi;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.scale(scale);

      // Draw coin
      _drawCoin(canvas, particle.size, opacity);

      canvas.restore();
    }
  }

  void _drawCoin(Canvas canvas, double size, double opacity) {
    final center = Offset.zero;
    final radius = size / 2;

    // Coin gradient
    final gradient = RadialGradient(
      colors: [
        const Color(0xFFFFE082).withValues(alpha: opacity),
        const Color(0xFFFFD700).withValues(alpha: opacity),
        const Color(0xFFFFA000).withValues(alpha: opacity),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    // Outer shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: opacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center + const Offset(2, 2), radius, shadowPaint);

    // Main coin body
    canvas.drawCircle(center, radius, paint);

    // Inner circle (coin detail)
    final innerPaint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.7, innerPaint);

    // Shine effect
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.5);
    canvas.drawCircle(
      center + Offset(-radius * 0.3, -radius * 0.3),
      radius * 0.2,
      shinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CoinPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Controller for managing coin animations.
class CoinAnimationController {
  final List<_CoinAnimationEntry> _pendingAnimations = [];
  VoidCallback? _onUpdate;

  /// Adds an animation to the queue.
  void addAnimation(Offset source, Offset target, int coins, VoidCallback onComplete) {
    _pendingAnimations.add(_CoinAnimationEntry(
      source: source,
      target: target,
      coins: coins,
      onComplete: onComplete,
    ));
    _onUpdate?.call();
  }

  /// Consumes and returns all pending animations.
  List<CoinAnimationData> consumeAnimations() {
    final list = _pendingAnimations.map((e) => CoinAnimationData(
      source: e.source,
      target: e.target,
      coins: e.coins,
      onComplete: e.onComplete,
    )).toList();
    _pendingAnimations.clear();
    return list;
  }

  /// Sets the callback for when animations are added.
  void setUpdateCallback(VoidCallback callback) {
    _onUpdate = callback;
  }

  /// Disposes the controller.
  void dispose() {
    _onUpdate = null;
    _pendingAnimations.clear();
  }
}

/// Public data class for coin animation entries.
class CoinAnimationData {
  final Offset source;
  final Offset target;
  final int coins;
  final VoidCallback onComplete;

  CoinAnimationData({
    required this.source,
    required this.target,
    required this.coins,
    required this.onComplete,
  });
}

class _CoinAnimationEntry {
  final Offset source;
  final Offset target;
  final int coins;
  final VoidCallback onComplete;

  _CoinAnimationEntry({
    required this.source,
    required this.target,
    required this.coins,
    required this.onComplete,
  });
}
