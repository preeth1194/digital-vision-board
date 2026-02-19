import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 12),
      color: colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Journal',
              style: GoogleFonts.merriweather(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (onAddBook != null)
            IconButton(
              icon: Icon(Icons.library_add_rounded, color: colorScheme.primary, size: 24),
              tooltip: 'New book',
              onPressed: onAddBook,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
