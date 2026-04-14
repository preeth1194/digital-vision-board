import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';

// ============================================================================
// HabitTrackingUnitSelector
// ============================================================================

/// Stateless widget extracted from [_buildTrackingUnitSelector] in add_habit_modal.dart.
/// Displays a segmented control for selecting the measurement unit for a habit.
class HabitTrackingUnitSelector extends StatelessWidget {
  final int selectedIconIndex;
  final String? trackingUnitId;
  final ValueChanged<String> onUnitChanged;

  const HabitTrackingUnitSelector({
    super.key,
    required this.selectedIconIndex,
    required this.trackingUnitId,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final units = iconTrackingUnits[selectedIconIndex];
    if (units == null || units.isEmpty) return const SizedBox.shrink();

    final segmentChildren = <int, Widget>{
      for (int i = 0; i < units.length; i++)
        i: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            units[i].$2,
            style: AppTypography.caption(context).copyWith(fontSize: 13),
          ),
        ),
    };

    final selectedIdx = units.indexWhere((u) => u.$1 == trackingUnitId);

    return CupertinoListSection.insetGrouped(
      header: Text(
        'Tracking Unit',
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.straighten, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Log ${habitIcons[selectedIconIndex].$2.toLowerCase()} in:',
                      style: AppTypography.body(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: selectedIdx >= 0 ? selectedIdx : 0,
                  children: segmentChildren,
                  onValueChanged: (idx) {
                    if (idx == null) return;
                    onUnitChanged(units[idx].$1);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
