import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A floating bottom navigation bar with a curved notch that slides between
/// tabs. The selected tab's icon pops up through the notch in a circular
/// highlight, with its label shown inside the bar below.
class AnimatedBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AnimatedNavItem> items;
  final VoidCallback? onCenterTap;
  final bool suppressHighlight;

  const AnimatedBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.onCenterTap,
    this.suppressHighlight = false,
  });

  @override
  State<AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<AnimatedBottomNavBar>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  int _previousIndex = 0;

  static const double _barHeight = 64.0;
  static const double _circleSize = 48.0;
  static const double _circleBorder = 4.0;
  static const double _circleOverflow = 20.0;
  static const double _totalHeight = _barHeight + _circleOverflow;
  static const double _circleTotalRadius = (_circleSize + 2 * _circleBorder) / 2;
  static const double _cutoutGap = 4.0;
  static const double _cutoutRadius = _circleTotalRadius + _cutoutGap;
  static const double _cutoutCenterY = _circleTotalRadius - _circleOverflow;

  static const double _centerBtnSize = 52.0;
  static const double _centerBtnBorder = 4.0;
  static const double _centerBtnTotalRadius =
      (_centerBtnSize + 2 * _centerBtnBorder) / 2;
  static const double _centerCutoutRadius = _centerBtnTotalRadius + _cutoutGap;
  static const double _centerCutoutCenterY =
      _centerBtnTotalRadius - _circleOverflow;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..value = 1.0;

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_bounceController);

    _slideController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _bounceController.forward(from: 0.0);
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _slideController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  int _tabToSlot(int tabIndex) {
    final mid = widget.items.length ~/ 2;
    if (widget.onCenterTap == null) return tabIndex;
    return tabIndex < mid ? tabIndex : tabIndex + 1;
  }

  double _slotCenterX(int tabIndex, double totalWidth) {
    final slotCount =
        widget.items.length + (widget.onCenterTap != null ? 1 : 0);
    final slotWidth = totalWidth / slotCount;
    final slot = _tabToSlot(tabIndex);
    return (slot + 0.5) * slotWidth;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCenterButton = widget.onCenterTap != null;
    final slotCount = widget.items.length + (hasCenterButton ? 1 : 0);
    final midSlot = widget.items.length ~/ 2;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _totalHeight + bottomPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final slotWidth = totalWidth / slotCount;
              final oldX = _slotCenterX(_previousIndex, totalWidth);
              final newX = _slotCenterX(widget.currentIndex, totalWidth);

              final centerSlotX = hasCenterButton
                  ? (midSlot + 0.5) * slotWidth
                  : null;

              return AnimatedBuilder(
                animation:
                    Listenable.merge([_slideController, _bounceController]),
                builder: (context, _) {
                  final t = _slideAnimation.value;
                  final currentX = ui.lerpDouble(oldX, newX, t)!;
                  final bounceScale = _bounceAnimation.value;
                  final currentItem = widget.items[widget.currentIndex];

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Bar body with dual cutouts (extends into safe area)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _barHeight + bottomPadding,
                        child: CustomPaint(
                          painter: _NotchedBarPainter(
                            notchCenterX: currentX,
                            cutoutCenterY: _cutoutCenterY,
                            cutoutRadius: widget.suppressHighlight ? 0 : _cutoutRadius,
                            centerBtnX: centerSlotX,
                            centerBtnCutoutCenterY: _centerCutoutCenterY,
                            centerBtnCutoutRadius: _centerCutoutRadius,
                            color: colorScheme.onSurface,
                            shadowColor: colorScheme.shadow,
                            borderRadius: 0,
                          ),
                          size: Size(totalWidth, _barHeight + bottomPadding),
                        ),
                      ),

                      // Icon row (unselected icons only, center slot is empty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: bottomPadding,
                        height: _barHeight,
                        child: Row(
                          children: List.generate(slotCount, (slotIndex) {
                            if (hasCenterButton && slotIndex == midSlot) {
                              return SizedBox(width: slotWidth);
                            }

                            final tabIndex = hasCenterButton &&
                                    slotIndex > midSlot
                                ? slotIndex - 1
                                : slotIndex;

                            if (tabIndex < 0 ||
                                tabIndex >= widget.items.length) {
                              return SizedBox(width: slotWidth);
                            }

                            final isSelected =
                                tabIndex == widget.currentIndex;
                            final item = widget.items[tabIndex];

                            final showIcon = !isSelected || widget.suppressHighlight;

                            return SizedBox(
                              width: slotWidth,
                              child: GestureDetector(
                                onTap: () => widget.onTap(tabIndex),
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showIcon)
                                      Icon(
                                        item.icon,
                                        color: colorScheme.outlineVariant,
                                        size: 24,
                                      )
                                    else
                                      const SizedBox(height: 24),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        color: colorScheme.outlineVariant,
                                        fontSize: 10,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        decoration: TextDecoration.none,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Elevated center "+" button
                      if (hasCenterButton && centerSlotX != null)
                        Positioned(
                          left: centerSlotX - _centerBtnTotalRadius,
                          top: 0,
                          child: _AnimatedCenterButton(
                            onTap: widget.onCenterTap!,
                            colorScheme: colorScheme,
                          ),
                        ),

                      // Pop-up circle for selected tab
                      if (!widget.suppressHighlight) ...[
                        // #region agent log
                        if (t >= 1.0) Builder(builder: (_) { try { File('/Users/preeth/digital-vision-board/.cursor/debug-aa6b4f.log').writeAsStringSync(jsonEncode({'sessionId':'aa6b4f','hypothesisId':'FIX-verify','location':'build:circle-pos','message':'circle vs cutout alignment','data':{'currentX':currentX,'centerSlotX':centerSlotX,'circleTotalRadius':_circleTotalRadius,'cutoutRadius':_cutoutRadius,'centerBtnTotalRadius':_centerBtnTotalRadius,'centerCutoutRadius':_centerCutoutRadius,'totalWidth':totalWidth,'tabIndex':widget.currentIndex},'timestamp':DateTime.now().millisecondsSinceEpoch})+'\n', mode: FileMode.append); } catch(_) {} return const SizedBox.shrink(); }),
                        // #endregion
                        Positioned(
                          left: currentX - _circleSize / 2 - _circleBorder,
                          top: 0,
                          child: Transform.scale(
                            scale: bounceScale,
                            child: Container(
                              width: _circleSize + _circleBorder * 2,
                              height: _circleSize + _circleBorder * 2,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: _circleBorder,
                                ),
                              ),
                              child: Icon(
                                currentItem.activeIcon,
                                color: colorScheme.onPrimaryContainer,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],

                      
                    ],
                  );
                },
              );
            },
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notched bar painter — subtracts a circle cutout from a rounded bar
// ---------------------------------------------------------------------------

class _NotchedBarPainter extends CustomPainter {
  final double notchCenterX;
  final double cutoutCenterY;
  final double cutoutRadius;
  final double? centerBtnX;
  final double? centerBtnCutoutCenterY;
  final double? centerBtnCutoutRadius;
  final Color color;
  final Color shadowColor;
  final double borderRadius;

  _NotchedBarPainter({
    required this.notchCenterX,
    required this.cutoutCenterY,
    required this.cutoutRadius,
    this.centerBtnX,
    this.centerBtnCutoutCenterY,
    this.centerBtnCutoutRadius,
    required this.color,
    required this.shadowColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // #region agent log
    try { File('/Users/preeth/digital-vision-board/.cursor/debug-aa6b4f.log').writeAsStringSync(jsonEncode({'sessionId':'aa6b4f','hypothesisId':'FIX-verify','location':'_NotchedBarPainter.paint','message':'dual-cutout geometry','data':{'canvasW':size.width,'canvasH':size.height,'notchCenterX':notchCenterX,'cutoutCenterY':cutoutCenterY,'cutoutRadius':cutoutRadius,'centerBtnX':centerBtnX,'centerBtnCutoutCenterY':centerBtnCutoutCenterY,'centerBtnCutoutRadius':centerBtnCutoutRadius,'borderRadius':borderRadius},'timestamp':DateTime.now().millisecondsSinceEpoch})+'\n', mode: FileMode.append); } catch(_) {}
    // #endregion
    final path = _buildPath(size);
    canvas.drawShadow(path, shadowColor, 10.0, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  Path _buildPath(Size size) {
    final barPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final tabCutout = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(notchCenterX, cutoutCenterY),
        radius: cutoutRadius,
      ));

    var result = Path.combine(PathOperation.difference, barPath, tabCutout);

    if (centerBtnX != null) {
      final centerCutout = Path()
        ..addOval(Rect.fromCircle(
          center: Offset(centerBtnX!, centerBtnCutoutCenterY!),
          radius: centerBtnCutoutRadius!,
        ));
      result = Path.combine(PathOperation.difference, result, centerCutout);
    }

    return result;
  }

  @override
  bool shouldRepaint(_NotchedBarPainter oldDelegate) {
    return oldDelegate.notchCenterX != notchCenterX ||
        oldDelegate.cutoutCenterY != cutoutCenterY ||
        oldDelegate.centerBtnX != centerBtnX ||
        oldDelegate.color != color ||
        oldDelegate.shadowColor != shadowColor;
  }
}

// ---------------------------------------------------------------------------
// Animated center "+" button (pulse, tap scale, rotation)
// ---------------------------------------------------------------------------

class _AnimatedCenterButton extends StatefulWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _AnimatedCenterButton({
    required this.onTap,
    required this.colorScheme,
  });

  @override
  State<_AnimatedCenterButton> createState() => _AnimatedCenterButtonState();
}

class _AnimatedCenterButtonState extends State<_AnimatedCenterButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _tapController;
  late Animation<double> _pulseScale;
  late Animation<double> _tapScale;
  late Animation<double> _tapRotation;

  static const double _innerSize = 52.0;
  static const double _border = 4.0;
  static const double _totalSize = _innerSize + 2 * _border;
  static const double _iconSize = 26.0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_tapController);

    _tapRotation = Tween<double>(begin: 0.0, end: math.pi / 2).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    _pulseController.stop();
    widget.onTap();
    await _tapController.forward(from: 0.0);
    if (mounted) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _tapController]),
      builder: (context, child) {
        final isTapping = _tapController.isAnimating;
        final scale = isTapping ? _tapScale.value : _pulseScale.value;
        final rotation = isTapping ? _tapRotation.value : 0.0;
        final glowOpacity =
            isTapping ? 0.5 : 0.25 + (_pulseScale.value - 1.0) * 2.5;

        return GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: Container(
                width: _totalSize,
                height: _totalSize,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.surface,
                    width: _border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          cs.primary.withOpacity(glowOpacity.clamp(0.0, 1.0)),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: cs.onPrimary,
                  size: _iconSize,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Data class for navigation items.
class AnimatedNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const AnimatedNavItem({
    required this.icon,
    required this.label,
    IconData? activeIcon,
  }) : activeIcon = activeIcon ?? icon;
}
