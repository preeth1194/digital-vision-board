import 'package:flutter/material.dart';

import '../../../utils/app_typography.dart';

/// Pinned header bar for the journal screen — title and add-book button.
class JournalBrowseSection extends StatelessWidget {
  final VoidCallback? onAddBook;

  const JournalBrowseSection({
    super.key,
    this.onAddBook,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 12),
      color: Colors.transparent,
      child: Row(
        children: [
          const Spacer(),
          if (onAddBook != null)
            Tooltip(
              message: 'Add book',
              child: TextButton(
                onPressed: onAddBook,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add book',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.add_rounded, color: colorScheme.primary, size: 22),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Neumorphic styled filter chip with pill shape and press animation.
class NeumorphicFilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const NeumorphicFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<NeumorphicFilterChip> createState() => _NeumorphicFilterChipState();
}

class _NeumorphicFilterChipState extends State<NeumorphicFilterChip>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = widget.selected
        ? colorScheme.primary
        : (isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface);
    final textColor = widget.selected
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final shadowDark = isDark
        ? colorScheme.shadow.withOpacity(0.3)
        : colorScheme.onSurface.withOpacity(0.08);
    final shadowLight = isDark
        ? colorScheme.surface.withOpacity(0.05)
        : colorScheme.surface.withOpacity(0.9);

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _scaleController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _scaleController.reverse();
        widget.onSelected();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _scaleController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.selected || _isPressed
                ? []
                : [
                    BoxShadow(
                      color: shadowDark,
                      offset: const Offset(2, 2),
                      blurRadius: 6,
                    ),
                    BoxShadow(
                      color: shadowLight,
                      offset: const Offset(-2, -2),
                      blurRadius: 6,
                    ),
                  ],
          ),
          child: Text(
            widget.label,
            style: AppTypography.bodySmall(context).copyWith(
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
