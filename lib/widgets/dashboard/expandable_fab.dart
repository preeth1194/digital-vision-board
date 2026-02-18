import 'package:flutter/material.dart';

/// A simple floating action button for creating a new vision board.
class ExpandableFAB extends StatelessWidget {
  final VoidCallback onCreateBoard;

  const ExpandableFAB({
    super.key,
    required this.onCreateBoard,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.extended(
      onPressed: onCreateBoard,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      icon: const Icon(Icons.add, size: 20),
      label: const Text(
        'Vision Board',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
