import 'package:flutter/material.dart';

import '../../services/daily_overview_service.dart';

/// GitHub-style contribution heatmap for daily mood/productivity.
///
/// - Columns are weeks, rows are weekdays (Mon..Sun).
/// - Each day is colored based on the day’s average rating (habits-only).
/// - Tapping a cell shows details in a bottom sheet.
class MoodContributionGraph extends StatelessWidget {
  final Map<String, HabitMoodDaySummary> byIsoDate;
  final DateTime? startDate;
  final DateTime endDate;
  final int rangeDays;
  final bool wrap; // for Year view: show full year without horizontal scrolling
  /// Render as a simple day grid with a fixed number of columns.
  ///
  /// This mode ignores weekday/week alignment and lays days sequentially into rows of
  /// `fixedDayColumns`. This is useful when you want consistent column counts (e.g. 25)
  /// and a uniform rectangular grid.
  ///
  /// Direction is controlled by `startFromBottomLeft` / `startFromBottomRight`.
  final int? fixedDayColumns;
  /// When `wrap` is true, force a fixed number of week-columns per wrapped row.
  /// Useful for keeping year views visually consistent across screens/boards (e.g. 26).
  final int? wrapColumns;
  /// Packed (non-calendar-aligned) layouts.
  ///
  /// If enabled, the grid is filled in sequential 7-day columns starting from `startDate`.
  /// - Bottom-left: `startFromBottomLeft = true` (old -> new left-to-right)
  /// - Bottom-right: `startFromBottomRight = true` (old -> new right-to-left)
  final bool startFromBottomLeft;
  final bool startFromBottomRight;

  // Layout tuning.
  /// Minimum desired cell size. If the calculated cell size would be smaller
  /// than this, wrap-mode will reduce columns-per-row to keep cells legible.
  final double cellSize;
  /// Maximum cell size for small ranges (e.g., 30D) so cells don't get huge.
  /// When capped, the grid is still justified by increasing horizontal spacing.
  final double maxCellSize;
  final double cellGap;
  final BorderRadius cellRadius;

  const MoodContributionGraph({
    super.key,
    required this.byIsoDate,
    this.startDate,
    required this.endDate,
    this.rangeDays = 365,
    this.wrap = false,
    this.fixedDayColumns,
    this.wrapColumns,
    this.startFromBottomLeft = false,
    this.startFromBottomRight = false,
    this.cellSize = 12,
    this.maxCellSize = 40,
    this.cellGap = 3,
    this.cellRadius = const BorderRadius.all(Radius.circular(3)),
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _startOfWeekMonday(DateTime d) {
    final date = _dateOnly(d);
    final delta = date.weekday - DateTime.monday; // monday=1
    return date.subtract(Duration(days: delta));
  }

  static String _toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static Color moodColorForAverage(BuildContext context, double? avg) {
    if (avg == null) return Colors.grey.shade300;
    if (avg >= 4.0) return Colors.green.shade700;
    if (avg >= 3.0) return Colors.green.shade400;
    return Colors.green.shade200;
  }

  void _showDayDetails(
    BuildContext context, {
    required DateTime date,
    required HabitMoodDaySummary? summary,
  }) {
    final iso = _toIsoDate(date);
    final avg = summary?.averageRating;
    final count = summary?.ratingCount ?? 0;
    final color = moodColorForAverage(context, avg);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  iso,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        avg == null
                            ? 'No data'
                            : 'Average rating: ${avg.toStringAsFixed(2)} / 5',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  count <= 0 ? '0 ratings' : '$count rating${count == 1 ? '' : 's'}',
                  style: TextStyle(color: onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final end = _dateOnly(endDate);
    final start = startDate == null
        ? end.subtract(Duration(days: (rangeDays - 1).clamp(0, 5000)))
        : _dateOnly(startDate!);

    final totalDays = end.difference(start).inDays + 1;
    if (totalDays <= 0) return const SizedBox.shrink();

    final packed = startFromBottomLeft || startFromBottomRight;
    assert(
      !(startFromBottomLeft && startFromBottomRight),
      'Only one of startFromBottomLeft/startFromBottomRight can be true.',
    );

    // Fixed day-grid mode: a rectangular grid with N columns (e.g. 25).
    if (fixedDayColumns != null) {
      final cols = fixedDayColumns!.clamp(1, 5000);
      final rows = ((totalDays + cols - 1) / cols).floor(); // ceil(totalDays/cols)
      final gridSlots = rows * cols;

      final List<DateTime?> slotDates = List<DateTime?>.filled(gridSlots, null);
      for (int i = 0; i < totalDays; i++) {
        final day = start.add(Duration(days: i));
        final rowFromBottom = i ~/ cols;
        final colFromStart = i % cols;

        final r = (rows - 1) - rowFromBottom;
        final c = startFromBottomRight
            ? (cols - 1) - colFromStart
            : startFromBottomLeft
                ? colFromStart
                : colFromStart;
        slotDates[(r * cols) + c] = day;
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          if (maxW <= 0) return const SizedBox.shrink();
          final square = (maxW - (cellGap * (cols - 1))) / cols;

          Widget cell(DateTime? day) {
            if (day == null) {
              return SizedBox(width: square, height: square);
            }
            final inRange = !day.isBefore(start) && !day.isAfter(end);
            final iso = _toIsoDate(day);
            final summary = inRange ? byIsoDate[iso] : null;
            final color = inRange ? moodColorForAverage(context, summary?.averageRating) : Colors.transparent;

            return InkWell(
              borderRadius: cellRadius,
              onTap: inRange ? () => _showDayDetails(context, date: day, summary: summary) : null,
              child: Ink(
                width: square,
                height: square,
                decoration: BoxDecoration(color: color, borderRadius: cellRadius),
              ),
            );
          }

          final rowWidgets = <Widget>[];
          for (int r = 0; r < rows; r++) {
            final children = <Widget>[];
            for (int c = 0; c < cols; c++) {
              children.add(cell(slotDates[(r * cols) + c]));
              if (c != cols - 1) children.add(SizedBox(width: cellGap));
            }
            rowWidgets.add(Row(children: children));
            if (r != rows - 1) rowWidgets.add(SizedBox(height: cellGap));
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowWidgets,
          );
        },
      );
    }

    // Column count:
    // - Default: calendar-week aligned (Mon..Sun) columns.
    // - Packed: sequential 7-day columns starting from startDate.
    final int colsTotal = packed
        ? ((totalDays + 6) / 7).ceil()
        : () {
            final alignedStart = _startOfWeekMonday(start);
            final alignedEndWeekStart = _startOfWeekMonday(end);
            return ((alignedEndWeekStart.difference(alignedStart).inDays) ~/ 7) + 1;
          }();

    // Column "base dates" in display order (left->right).
    // - Default: old->new (alignedStart .. alignedEnd)
    // - Packed bottom-left: old->new (start column at the left edge)
    // - Packed bottom-right: new->old (start column at the right edge)
    final List<DateTime> colBaseDates = startFromBottomRight
        ? [for (int c = colsTotal - 1; c >= 0; c--) start.add(Duration(days: c * 7))]
        : startFromBottomLeft
            ? [for (int c = 0; c < colsTotal; c++) start.add(Duration(days: c * 7))]
        : () {
            final alignedStart = _startOfWeekMonday(start);
            return [
              for (int c = 0; c < colsTotal; c++) alignedStart.add(Duration(days: c * 7)),
            ];
          }();

    // In packed mode, it can be useful to also have the base dates in chronological order
    // (old -> new) for deterministic chunking in wrap layouts.
    final List<DateTime> packedBaseDatesChrono = packed
        ? [for (int c = 0; c < colsTotal; c++) start.add(Duration(days: c * 7))]
        : const <DateTime>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (maxW <= 0) return const SizedBox.shrink();

        // "Justified" sizing:
        // itemSize = (availableWidth - (gap * (cols - 1))) / cols
        // - Non-wrap (30D/Quarter): use constant gap; if itemSize is capped, center the grid.
        // - Wrap (Year): wrap into rows when needed and justify each row.

        int colsPerRow = colsTotal.clamp(1, 5000);

        double sizeForCols(int cols) => (maxW - (cellGap * (cols - 1))) / cols;

        if (wrap && wrapColumns != null) {
          colsPerRow = wrapColumns!.clamp(1, colsPerRow);
        }

        double itemSize = sizeForCols(colsPerRow);
        final isCapped = !wrap && itemSize > maxCellSize;

        if (wrap && itemSize < cellSize) {
          // Reduce columns per row to keep cells at least ~cellSize.
          // If wrapColumns is set, we prefer uniformity over minimum size; otherwise, adapt.
          if (wrapColumns == null) {
            final colsThatFitAtMin = ((maxW + cellGap) / (cellSize + cellGap)).floor().clamp(1, colsPerRow);
            colsPerRow = colsThatFitAtMin;
            itemSize = sizeForCols(colsPerRow);
          }
        }

        final effectiveSize = isCapped ? maxCellSize : itemSize;
        final colHeight = (effectiveSize * 7) + (cellGap * 6);
        final cappedGridW = (effectiveSize * colsPerRow) + (cellGap * (colsPerRow - 1));

        Widget buildCell(DateTime day) {
          final inRange = !day.isBefore(start) && !day.isAfter(end);
          final iso = _toIsoDate(day);
          final summary = inRange ? byIsoDate[iso] : null;
          final color = inRange ? moodColorForAverage(context, summary?.averageRating) : Colors.transparent;

          return InkWell(
            borderRadius: cellRadius,
            onTap: inRange ? () => _showDayDetails(context, date: day, summary: summary) : null,
            child: Ink(
              width: effectiveSize,
              height: effectiveSize,
              decoration: BoxDecoration(color: color, borderRadius: cellRadius),
            ),
          );
        }

        Widget buildWeekColumn(DateTime base, {required bool isLastColumnInRow}) {
          final cells = <Widget>[];
          for (int row = 0; row < 7; row++) {
            final offsetDays = packed ? (6 - row) : row;
            final day = base.add(Duration(days: offsetDays));
            cells.add(buildCell(day));
            if (row != 6) cells.add(SizedBox(height: cellGap));
          }
          return SizedBox(
            width: effectiveSize,
            height: colHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: cells,
            ),
          );
        }

        // --- Non-wrap path (30D / Quarter): fixed gap, dynamic square sizing, full-width ---
        if (!wrap) {
          final cols = colsTotal.clamp(1, 5000);
          final rawSize = sizeForCols(cols);
          // Always occupy full available width by using the computed size.
          // (This can get large for small ranges like 30D, by design.)
          final square = rawSize;
          final gridW = (square * cols) + (cellGap * (cols - 1));
          final height = (square * 7) + (cellGap * 6);

          Widget weekColumn(DateTime base) {
            final cells = <Widget>[];
            for (int row = 0; row < 7; row++) {
              final offsetDays = packed ? (6 - row) : row;
              final day = base.add(Duration(days: offsetDays));
              final inRange = !day.isBefore(start) && !day.isAfter(end);
              final iso = _toIsoDate(day);
              final summary = inRange ? byIsoDate[iso] : null;
              final color = inRange ? moodColorForAverage(context, summary?.averageRating) : Colors.transparent;
              cells.add(
                InkWell(
                  borderRadius: cellRadius,
                  onTap: inRange ? () => _showDayDetails(context, date: day, summary: summary) : null,
                  child: Ink(
                    width: square,
                    height: square,
                    decoration: BoxDecoration(color: color, borderRadius: cellRadius),
                  ),
                ),
              );
              if (row != 6) cells.add(SizedBox(height: cellGap));
            }
            return SizedBox(
              width: square,
              height: height,
              child: Column(mainAxisSize: MainAxisSize.min, children: cells),
            );
          }

          final colsWidgets = <Widget>[];
          for (int i = 0; i < colBaseDates.length; i++) {
            colsWidgets.add(weekColumn(colBaseDates[i]));
            if (i != colBaseDates.length - 1) colsWidgets.add(SizedBox(width: cellGap));
          }

          final grid = SizedBox(
            width: gridW,
            height: height,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: colsWidgets),
          );

          // `gridW` will equal `maxW` (up to floating point error) with the formula above.
          return SizedBox(width: maxW, child: grid);
        }

        List<Widget> buildRowColumns(List<DateTime> chunk, double gap) {
          final widgets = <Widget>[];
          for (int i = 0; i < chunk.length; i++) {
            widgets.add(buildWeekColumn(chunk[i], isLastColumnInRow: i == chunk.length - 1));
            if (i != chunk.length - 1) widgets.add(SizedBox(width: gap));
          }
          return widgets;
        }

        final rows = <Widget>[];
        if (wrapColumns != null && packed) {
          // Deterministic wrap:
          // - Chunk from the start (chronological), so the first `colsPerRow` columns are together.
          // - Render chunks newest->oldest so the start date ends up at the bottom-right.
          final chunks = <List<DateTime>>[];
          for (int i = 0; i < packedBaseDatesChrono.length; i += colsPerRow) {
            chunks.add(
              packedBaseDatesChrono.sublist(
                i,
                (i + colsPerRow) > packedBaseDatesChrono.length
                    ? packedBaseDatesChrono.length
                    : (i + colsPerRow),
              ),
            );
          }

          for (int ci = chunks.length - 1; ci >= 0; ci--) {
            final chunkChrono = chunks[ci];
            var rowDates = startFromBottomRight
                ? chunkChrono.reversed.toList()
                : chunkChrono.toList();

            // Pad to a full row so every row has exactly `colsPerRow` columns.
            // For bottom-right packed mode, padding should appear on the left (future weeks).
            if (rowDates.length < colsPerRow) {
              final missing = colsPerRow - rowDates.length;
              if (chunkChrono.isNotEmpty) {
                final latestBase = chunkChrono.last;
                if (startFromBottomRight) {
                  final pad = <DateTime>[
                    for (int p = missing; p >= 1; p--) latestBase.add(Duration(days: p * 7)),
                  ];
                  rowDates = [...pad, ...rowDates];
                } else {
                  final pad = <DateTime>[
                    for (int p = 1; p <= missing; p++) latestBase.add(Duration(days: p * 7)),
                  ];
                  rowDates = [...rowDates, ...pad];
                }
              }
            }

            rows.add(
              SizedBox(
                width: maxW,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: buildRowColumns(rowDates, cellGap),
                ),
              ),
            );
            if (ci != 0) rows.add(SizedBox(height: cellGap * 2));
          }
        } else {
          // Adaptive wrap (legacy): chunk in display order.
          for (int i = 0; i < colBaseDates.length; i += colsPerRow) {
            final chunk = colBaseDates.sublist(
              i,
              (i + colsPerRow) > colBaseDates.length ? colBaseDates.length : (i + colsPerRow),
            );
            // Wrap mode: keep a consistent gap so the grid stays visually aligned.
            final gap = cellGap;
            rows.add(
              SizedBox(
                width: maxW,
                child: Row(
                  mainAxisAlignment: startFromBottomRight ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: buildRowColumns(chunk, gap),
                ),
              ),
            );
            if (i + colsPerRow < colBaseDates.length) {
              rows.add(SizedBox(height: cellGap * 2));
            }
          }
        }

        final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);

        return content;
      },
    );
  }
}

