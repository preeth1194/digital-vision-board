import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

/// Opens a bottom sheet to pick any month between [firstMonthStart] and [lastMonthStart].
class InsightsPeriodSelector extends StatelessWidget {
  const InsightsPeriodSelector({
    super.key,
    required this.year,
    required this.month,
    required this.firstMonthStart,
    required this.lastMonthStart,
    required this.onMonthChanged,
  });

  final int year;
  final int month;
  final DateTime firstMonthStart;
  final DateTime lastMonthStart;
  final ValueChanged<({int year, int month})> onMonthChanged;

  String get _label {
    return DateFormat.yMMMM().format(DateTime(year, month));
  }

  static List<DateTime> _monthsInRange(
    DateTime first,
    DateTime last,
  ) {
    final out = <DateTime>[];
    var y = first.year;
    var m = first.month;
    while (true) {
      final current = DateTime(y, m, 1);
      out.add(current);
      if (current.year == last.year && current.month == last.month) break;
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return out;
  }

  Future<void> _openSheet(BuildContext context) async {
    final months = _monthsInRange(firstMonthStart, lastMonthStart);
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusCard),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Month',
                  style: AppTypography.heading3(ctx),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  itemCount: months.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (ctx, i) {
                    final d = months[i];
                    final selected =
                        d.year == year && d.month == month;
                    final label = DateFormat.yMMMM().format(d);
                    return Semantics(
                      label: label,
                      button: true,
                      selected: selected,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            onMonthChanged((year: d.year, month: d.month));
                            Navigator.of(ctx).pop();
                          },
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusInput),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusInput,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: AppTypography.body(ctx).copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: selected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: colorScheme.primary,
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Selected period $_label, change month',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSheet(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _label,
                    style: AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
