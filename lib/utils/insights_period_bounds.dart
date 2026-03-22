/// Month/year picker limits for Insights: from first install through logical "today".
///
/// If install time is missing, earliest month is January of the current logical year.
final class InsightsPeriodBounds {
  InsightsPeriodBounds._();

  /// First day of the earliest selectable month.
  static DateTime firstSelectableMonth({
    required int? firstInstallMs,
    required DateTime logicalToday,
  }) {
    final todayMonth = DateTime(logicalToday.year, logicalToday.month, 1);
    if (firstInstallMs != null && firstInstallMs > 0) {
      final d = DateTime.fromMillisecondsSinceEpoch(
        firstInstallMs,
        isUtc: false,
      );
      final installMonth = DateTime(d.year, d.month, 1);
      if (installMonth.isAfter(todayMonth)) return todayMonth;
      return installMonth;
    }
    return DateTime(logicalToday.year, 1, 1);
  }

  /// First day of the latest selectable month (inclusive).
  static DateTime lastSelectableMonth(DateTime logicalToday) {
    return DateTime(logicalToday.year, logicalToday.month, 1);
  }

  static int _monthIndex(DateTime m) => m.year * 12 + m.month - 1;

  /// Whether [year]/[month] (calendar month) is within [first]..[last] inclusive.
  static bool isSelectable({
    required int year,
    required int month,
    required DateTime firstMonthStart,
    required DateTime lastMonthStart,
  }) {
    final candidate = DateTime(year, month, 1);
    final i = _monthIndex(candidate);
    return i >= _monthIndex(firstMonthStart) && i <= _monthIndex(lastMonthStart);
  }

  /// Clamp [year]/[month] into the allowed range.
  static ({int year, int month}) clampMonth({
    required int year,
    required int month,
    required DateTime firstMonthStart,
    required DateTime lastMonthStart,
  }) {
    var y = year;
    var m = month;
    if (m < 1) {
      y -= 1;
      m = 12;
    } else if (m > 12) {
      y += 1;
      m = 1;
    }
    var candidate = DateTime(y, m, 1);
    if (_monthIndex(candidate) < _monthIndex(firstMonthStart)) {
      return (
        year: firstMonthStart.year,
        month: firstMonthStart.month,
      );
    }
    if (_monthIndex(candidate) > _monthIndex(lastMonthStart)) {
      return (
        year: lastMonthStart.year,
        month: lastMonthStart.month,
      );
    }
    return (year: y, month: m);
  }
}
