import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

/// A modern, floating bottom navigation bar with fluid expanding pill animation.
///
/// Features:
/// - Dark pill-shaped container using AppColors
/// - Each icon in a circular background
/// - Selected item expands into a pill showing icon + label
/// - Smooth spring-like fluid animations
class AnimatedBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AnimatedNavItem> items;

  const AnimatedBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    // Use AppColors.darkest for the container (same for both themes)
    const containerColor = AppColors.darkest;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(items.length, (index) {
                  return _FluidNavItem(
                    item: items[index],
                    isSelected: index == currentIndex,
                    onTap: () => onTap(index),
                    totalItems: items.length,
                    availableWidth: constraints.maxWidth,
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FluidNavItem extends StatefulWidget {
  final AnimatedNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final int totalItems;
  final double availableWidth;

  const _FluidNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.totalItems,
    required this.availableWidth,
  });

  @override
  State<_FluidNavItem> createState() => _FluidNavItemState();
}

class _FluidNavItemState extends State<_FluidNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _iconColorAnimation;
  late Animation<double> _labelOpacity;
  late Animation<double> _labelSlide;

  static const double _circleSize = 48.0;
  static const double _iconSize = 22.0;
  static const double _spacing = 4.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _setupAnimations();

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  void _setupAnimations() {
    // Main expansion animation with smooth curve
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Icon color transition
    _iconColorAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    // Label fade in (starts after expansion begins)
    _labelOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Label slide in from left
    _labelSlide = Tween<double>(begin: -8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void didUpdateWidget(_FluidNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _measureLabelWidth() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.item.label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }

  @override
  Widget build(BuildContext context) {
    // Use AppColors for consistent theming
    final unselectedBgColor = AppColors.dark.withOpacity(0.6);
    const unselectedIconColor = AppColors.light;
    const selectedAccentColor = AppColors.lightest; // Accent color for selected pill
    const selectedIconColor = AppColors.darkest; // Dark icon on light background
    const selectedLabelColor = AppColors.darkest; // Dark text on light background

    // Calculate max width for expanded state
    final labelWidth = _measureLabelWidth();
    final expandedWidth = _circleSize + labelWidth + 16; // icon + label + padding

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final currentWidth = _circleSize + (_expandAnimation.value * (expandedWidth - _circleSize));

        // Interpolate background color
        final bgColor = Color.lerp(
          unselectedBgColor,
          selectedAccentColor,
          _expandAnimation.value,
        )!;

        // Interpolate icon color
        final iconColor = Color.lerp(
          unselectedIconColor,
          selectedIconColor,
          _iconColorAnimation.value,
        )!;

        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _spacing / 2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: _circleSize,
              width: currentWidth,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(_circleSize / 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_circleSize / 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Icon container
                    SizedBox(
                      width: _circleSize,
                      height: _circleSize,
                      child: Center(
                        child: Icon(
                          widget.isSelected ? widget.item.activeIcon : widget.item.icon,
                          color: iconColor,
                          size: _iconSize,
                        ),
                      ),
                    ),
                    // Label (fades and slides in)
                    if (_expandAnimation.value > 0.05)
                      Flexible(
                        child: Transform.translate(
                          offset: Offset(_labelSlide.value, 0),
                          child: Opacity(
                            opacity: _labelOpacity.value.clamp(0.0, 1.0),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Text(
                                widget.item.label,
                                style: const TextStyle(
                                  color: selectedLabelColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Data class for navigation items
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
