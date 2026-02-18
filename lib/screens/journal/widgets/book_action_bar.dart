import 'package:flutter/material.dart';

/// Bottom action bar for the journal book with circular buttons.
class BookActionBar extends StatelessWidget {
  final VoidCallback onColor;
  final VoidCallback onDelete;
  final VoidCallback onAdd;
  final bool isVisible;

  const BookActionBar({
    super.key,
    required this.onColor,
    required this.onDelete,
    required this.onAdd,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(0, 0.5),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
              icon: Icons.palette_outlined,
              onTap: onColor,
              tooltip: 'Change cover color',
            ),
            const SizedBox(width: 12),
            _ActionButton(
              icon: Icons.delete_outline_rounded,
              onTap: onDelete,
              tooltip: 'Delete',
            ),
            const SizedBox(width: 12),
            _ActionButton(
              icon: Icons.add_rounded,
              onTap: onAdd,
              tooltip: 'New entry',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHigh
                : Colors.white,
            shape: BoxShape.circle,
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                    if (!isDark)
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        offset: const Offset(-1, -1),
                        blurRadius: 4,
                      ),
                  ],
          ),
          child: Icon(
            widget.icon,
            size: 22,
            color: colorScheme.onSurface.withOpacity(_isPressed ? 0.5 : 0.7),
          ),
        ),
      ),
    );
  }
}
