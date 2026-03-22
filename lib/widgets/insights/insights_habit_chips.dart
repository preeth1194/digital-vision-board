import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../utils/app_spacing.dart';
import '../rituals/habit_form_constants.dart';

class InsightsHabitChips extends StatelessWidget {
  const InsightsHabitChips({
    super.key,
    required this.habits,
    required this.selectedId,
    required this.onChanged,
  });

  final List<HabitItem> habits;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chips = <Widget>[
      _buildChip(
        context: context,
        colorScheme: colorScheme,
        isSelected: selectedId == null,
        onTap: selectedId == null ? null : () => onChanged(null),
        child: Text('All', style: _chipTextStyle(context, colorScheme, selectedId == null)),
      ),
      ...habits.map((h) {
        final isSelected = h.id == selectedId;
        final icon = habitIcons[(h.iconIndex ?? 0).clamp(0, habitIcons.length - 1)].$1;
        return _buildChip(
          context: context,
          colorScheme: colorScheme,
          isSelected: isSelected,
          onTap: () => onChanged(isSelected ? null : h.id),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                h.name.length > 18 ? '${h.name.substring(0, 18)}…' : h.name,
                style: _chipTextStyle(context, colorScheme, isSelected),
              ),
            ],
          ),
        );
      }),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required ColorScheme colorScheme,
    required bool isSelected,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        ),
        child: child,
      ),
    );
  }

  TextStyle _chipTextStyle(
      BuildContext context, ColorScheme colorScheme, bool isSelected) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        );
  }
}
