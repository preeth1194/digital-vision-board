import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Simple tap-to-flip card (front/back).
///
/// Uses a Y-axis rotation; children are wrapped in [RepaintBoundary] to keep it smooth.
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final Duration duration;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 550),
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  bool _showFront = true;

  void _toggle() {
    if (_c.isAnimating) return;
    setState(() => _showFront = !_showFront);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          final angle = (_showFront ? t : (1 - t)) * math.pi;
          final isFrontVisible = angle <= (math.pi / 2);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: RepaintBoundary(
              child: isFrontVisible
                  ? widget.front
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: widget.back,
                    ),
            ),
          );
        },
      ),
    );
  }
}

