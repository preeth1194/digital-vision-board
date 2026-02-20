import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class AnimatedBottomNavBar extends StatelessWidget {
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

  static const double _barHeight = 64.0;
  static const double _centerBtnSize = 52.0;
  static const double _centerBtnBorder = 4.0;
  static const double _centerBtnTotalSize = _centerBtnSize + 2 * _centerBtnBorder;
  static const double _centerBtnOverflow = 20.0;
  static const double _totalHeight = _barHeight + _centerBtnOverflow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCenterButton = onCenterTap != null;
    final slotCount = items.length + (hasCenterButton ? 1 : 0);
    final midSlot = items.length ~/ 2;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _totalHeight + bottomPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final slotWidth = totalWidth / slotCount;

          final centerSlotX = hasCenterButton
              ? (midSlot + 0.5) * slotWidth
              : null;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Bar background
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _barHeight + bottomPadding,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.forestDeep,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab icons + labels
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

                    final tabIndex = hasCenterButton && slotIndex > midSlot
                        ? slotIndex - 1
                        : slotIndex;

                    if (tabIndex < 0 || tabIndex >= items.length) {
                      return SizedBox(width: slotWidth);
                    }

                    final isSelected =
                        tabIndex == currentIndex && !suppressHighlight;
                    final item = items[tabIndex];

                    return SizedBox(
                      width: slotWidth,
                      child: GestureDetector(
                        onTap: () => onTap(tabIndex),
                        behavior: HitTestBehavior.opaque,
                        child: _NavTabItem(
                          icon: isSelected ? item.activeIcon : item.icon,
                          label: item.label,
                          isSelected: isSelected,
                          colorScheme: colorScheme,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Elevated center "+" button
              if (hasCenterButton && centerSlotX != null)
                Positioned(
                  left: centerSlotX - _centerBtnTotalSize / 2,
                  top: 0,
                  child: _AnimatedCenterButton(
                    onTap: onCenterTap!,
                    colorScheme: colorScheme,
                    isExpanded: suppressHighlight,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual nav tab — icon-only highlight with smooth transitions
// ---------------------------------------------------------------------------

class _NavTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final ColorScheme colorScheme;

  const _NavTabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.colorScheme,
  });

  static const Color _activeColor = AppColors.sproutGreen;
  static const Color _inactiveColor = Color(0xFFAAB4AA);

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? _activeColor : _inactiveColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: isSelected ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Icon(
              icon,
              key: ValueKey<bool>(isSelected),
              color: color,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          style: AppTypography.caption(context).copyWith(
            color: color,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            decoration: TextDecoration.none,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Animated center "+" button (pulse, tap scale, rotation)
// ---------------------------------------------------------------------------

class _AnimatedCenterButton extends StatefulWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isExpanded;

  const _AnimatedCenterButton({
    required this.onTap,
    required this.colorScheme,
    this.isExpanded = false,
  });

  @override
  State<_AnimatedCenterButton> createState() => _AnimatedCenterButtonState();
}

class _AnimatedCenterButtonState extends State<_AnimatedCenterButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _tapController;
  late AnimationController _expandController;
  late Animation<double> _pulseScale;
  late Animation<double> _tapScale;
  late Animation<double> _expandRotation;

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

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isExpanded ? 1.0 : 0.0,
    );

    _expandRotation = Tween<double>(begin: 0.0, end: math.pi / 4).animate(
      CurvedAnimation(parent: _expandController, curve: Curves.easeOutBack),
    );

    if (widget.isExpanded) {
      _pulseController.stop();
    }
  }

  @override
  void didUpdateWidget(_AnimatedCenterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _pulseController.stop();
        _expandController.forward();
      } else {
        _expandController.reverse().then((_) {
          if (mounted) _pulseController.repeat(reverse: true);
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!widget.isExpanded) {
      _pulseController.stop();
    }
    await _tapController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _tapController,
        _expandController,
      ]),
      builder: (context, child) {
        final isTapping = _tapController.isAnimating;
        final scale = isTapping
            ? _tapScale.value
            : (widget.isExpanded ? 1.0 : _pulseScale.value);
        final rotation = _expandRotation.value;
        final glowOpacity = widget.isExpanded
            ? 0.35
            : (isTapping ? 0.5 : 0.25 + (_pulseScale.value - 1.0) * 2.5);

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
                  color: cs.onPrimaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.surface,
                    width: _border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.onPrimaryContainer
                          .withValues(alpha: glowOpacity.clamp(0.0, 1.0)),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: cs.primaryContainer,
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
