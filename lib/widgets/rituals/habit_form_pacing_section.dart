import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';

// --- STEP 5: PACING (Weekdays only; start time and duration are in Reminders) ---
class Step5Pacing extends StatelessWidget {
  final Color habitColor;
  final Set<int> weekdays;
  final ValueChanged<int> onWeekdayToggled;

  const Step5Pacing({
    super.key,
    required this.habitColor,
    required this.weekdays,
    required this.onWeekdayToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CupertinoListSection.insetGrouped(
      header: Text(
        "Schedule",
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      decoration: habitSectionDecoration(colorScheme),
      separatorColor: habitSectionSeparatorColor(colorScheme),
      children: [
        // Weekdays row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final selected = weekdays.contains(index);
              return AnimatedDayChip(
                label: days[index],
                isSelected: selected,
                accentColor: habitColor,
                onTap: () => onWeekdayToggled(index),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// Animated Day Chip
class AnimatedDayChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final Color? accentColor;
  final VoidCallback onTap;

  const AnimatedDayChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.accentColor,
    required this.onTap,
  });

  @override
  State<AnimatedDayChip> createState() => _AnimatedDayChipState();
}

class _AnimatedDayChipState extends State<AnimatedDayChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.85).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (widget.accentColor ?? colorScheme.primary)
                : colorScheme.surfaceContainerHigh,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected
                  ? (widget.accentColor ?? colorScheme.primary)
                  : colorScheme.outlineVariant,
              width: widget.isSelected ? 0 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppTypography.bodySmall(context).copyWith(
              color: widget.isSelected
                  ? contrastColor(widget.accentColor ?? colorScheme.primary)
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
