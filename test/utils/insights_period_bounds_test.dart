import 'package:digital_vision_board/utils/insights_period_bounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InsightsPeriodBounds', () {
    test('firstSelectableMonth uses install month when present', () {
      final install = DateTime(2024, 6, 15);
      final logicalToday = DateTime(2026, 3, 10);
      final first = InsightsPeriodBounds.firstSelectableMonth(
        firstInstallMs: install.millisecondsSinceEpoch,
        logicalToday: logicalToday,
      );
      expect(first, DateTime(2024, 6, 1));
    });

    test('firstSelectableMonth falls back to January of logical year', () {
      final logicalToday = DateTime(2026, 3, 10);
      final first = InsightsPeriodBounds.firstSelectableMonth(
        firstInstallMs: null,
        logicalToday: logicalToday,
      );
      expect(first, DateTime(2026, 1, 1));
    });

    test('clampMonth keeps in range', () {
      final first = DateTime(2025, 2, 1);
      final last = DateTime(2026, 1, 1);
      final a = InsightsPeriodBounds.clampMonth(
        year: 2020,
        month: 1,
        firstMonthStart: first,
        lastMonthStart: last,
      );
      expect(a.year, 2025);
      expect(a.month, 2);
      final b = InsightsPeriodBounds.clampMonth(
        year: 2030,
        month: 6,
        firstMonthStart: first,
        lastMonthStart: last,
      );
      expect(b.year, 2026);
      expect(b.month, 1);
    });

    test('isSelectable respects bounds', () {
      final first = DateTime(2025, 3, 1);
      final last = DateTime(2025, 5, 1);
      expect(
        InsightsPeriodBounds.isSelectable(
          year: 2025,
          month: 4,
          firstMonthStart: first,
          lastMonthStart: last,
        ),
        isTrue,
      );
      expect(
        InsightsPeriodBounds.isSelectable(
          year: 2025,
          month: 2,
          firstMonthStart: first,
          lastMonthStart: last,
        ),
        isFalse,
      );
    });
  });
}
