import 'package:flutter/material.dart';

/// An expandable floating action button that shows multiple action options.
/// When collapsed, shows a single FAB. When expanded, shows multiple FABs in a speed dial style.
class ExpandableFAB extends StatefulWidget {
  final VoidCallback onCreateBoard;
  final VoidCallback onCreateRoutine;

  const ExpandableFAB({
    super.key,
    required this.onCreateBoard,
    required this.onCreateRoutine,
  });

  @override
  State<ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends State<ExpandableFAB>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _handleAction(VoidCallback action) {
    _toggleExpansion();
    Future.delayed(const Duration(milliseconds: 150), action);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded action buttons
        if (_isExpanded) ...[
          // Create Routine button
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _scaleAnimation,
              child: _ActionButton(
                icon: Icons.list_alt,
                label: 'Routine',
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
                onTap: () => _handleAction(widget.onCreateRoutine),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Create Vision Board button
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _scaleAnimation,
              child: _ActionButton(
                icon: Icons.dashboard_outlined,
                label: 'Vision Board',
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                onTap: () => _handleAction(widget.onCreateBoard),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Main FAB
        RotationTransition(
          turns: _rotateAnimation,
          child: FloatingActionButton(
            onPressed: _toggleExpansion,
            child: Icon(_isExpanded ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      heroTag: null, // Important: each FAB needs unique heroTag
    );
  }
}
