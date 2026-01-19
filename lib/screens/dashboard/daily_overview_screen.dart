import 'package:flutter/material.dart';

import '../../services/utils/daily_overview_service.dart';
import '../../services/utils/logical_date_service.dart';
import '../../widgets/dashboard/mood_contribution_graph.dart';

class DailyOverviewScreen extends StatefulWidget {
  const DailyOverviewScreen({super.key});

  @override
  State<DailyOverviewScreen> createState() => _DailyOverviewScreenState();
}

class _DailyOverviewScreenState extends State<DailyOverviewScreen> {
  bool _loading = true;
  List<BoardHabitMoodSummary> _byBoard = const [];

  final DateTime _today = LogicalDateService.today();
  _ProgressRange _range = _ProgressRange.year;
  int _quarterIndex = 0; // 0=Jan-Apr, 1=May-Aug, 2=Sep-Dec

  @override
  void initState() {
    super.initState();
    _quarterIndex = _quarterForMonth(_today.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final byBoard = await DailyOverviewService.buildHabitMoodByBoard();
      if (!mounted) return;
      setState(() {
        _byBoard = byBoard;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = _today;
    final year = now.year;
    final period = _range == _ProgressRange.year
        ? _yearRange(year)
        : _quarterRange(year, _quarterIndex);
    final rangeStart = period.start;
    final rangeEnd = period.end;
    final periodLabel = _range == _ProgressRange.year
        ? 'Year $year'
        : switch (_quarterIndex.clamp(0, 2)) {
            0 => 'Jan–Apr $year',
            1 => 'May–Aug $year',
            _ => 'Sep–Dec $year',
          };

    return Scaffold(
      appBar: null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Minimal header: title + active period + range controls.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your progress',
                          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          periodLabel,
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<_ProgressRange>(
                                segments: const [
                                  ButtonSegment<_ProgressRange>(
                                    value: _ProgressRange.quarter,
                                    label: Text('Quarter'),
                                  ),
                                  ButtonSegment<_ProgressRange>(
                                    value: _ProgressRange.year,
                                    label: Text('Year'),
                                  ),
                                ],
                                selected: {_range},
                                onSelectionChanged: (s) {
                                  if (s.isEmpty) return;
                                  setState(() => _range = s.first);
                                },
                                showSelectedIcon: false,
                              ),
                            ),
                            if (_range == _ProgressRange.quarter) ...[
                              const SizedBox(width: 12),
                              _QuarterPicker(
                                value: _quarterIndex,
                                onChanged: (q) => setState(() => _quarterIndex = q),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_byBoard.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: Text('No boards yet.')),
                    )
                  else
                    for (final b in _byBoard) ...[
                      _BoardSection(
                        board: b,
                        start: rangeStart,
                        end: rangeEnd,
                        isYear: _range == _ProgressRange.year,
                      ),
                      const SizedBox(height: 10),
                      Divider(height: 1, color: cs.outlineVariant),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
    );
  }
}

class _BoardSection extends StatelessWidget {
  final BoardHabitMoodSummary board;
  final DateTime start;
  final DateTime end;
  final bool isYear;

  const _BoardSection({
    required this.board,
    required this.start,
    required this.end,
    required this.isYear,
  });

  static String _toIso(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  ({String name, int completions, double avgRating, int ratingCount})? _bestHabitByCompletions() {
    final startIso = _toIso(start);
    final endIso = _toIso(end);
    ({String name, int completions, double avgRating, int ratingCount})? best;

    for (final series in board.habitsByName.values) {
      // Completion count in range
      int completions = 0;
      for (final iso in series.completedIsoDates) {
        if (iso.compareTo(startIso) < 0) continue;
        if (iso.compareTo(endIso) > 0) continue;
        completions += 1;
      }

      // Rating stats in range (tie-breakers + display)
      int sum = 0;
      int ratingCount = 0;
      for (final entry in series.ratingByIsoDate.entries) {
        final iso = entry.key;
        if (iso.compareTo(startIso) < 0) continue;
        if (iso.compareTo(endIso) > 0) continue;
        final r = entry.value;
        if (r <= 0) continue;
        sum += r;
        ratingCount += 1;
      }
      if (completions == 0) continue;
      final avg = ratingCount == 0 ? 0.0 : (sum / ratingCount);
      final candidate = (
        name: series.name,
        completions: completions,
        avgRating: avg,
        ratingCount: ratingCount,
      );
      if (best == null) {
        best = candidate;
        continue;
      }
      if (candidate.completions > best!.completions) {
        best = candidate;
        continue;
      }
      if (candidate.completions < best!.completions) {
        continue;
      }
      if (candidate.avgRating > best!.avgRating) {
        best = candidate;
        continue;
      }
      if (candidate.avgRating == best!.avgRating && candidate.ratingCount > best!.ratingCount) {
        best = candidate;
        continue;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final best = _bestHabitByCompletions();
    final bestName = best?.name ?? '—';
    final bestCompletions = best?.completions ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            board.boardTitle,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          MoodContributionGraph(
            byIsoDate: board.byIsoDate,
            startDate: start,
            endDate: end,
            fixedDayColumns: 25,
            // Start from bottom-right and fill upwards, then continue right->left.
            startFromBottomRight: true,
            cellSize: isYear ? 12 : 12,
            cellGap: isYear ? 2 : 3,
          ),
          const SizedBox(height: 10),
          _MinimalStatsRow(
            mostCompletedName: best == null ? null : bestName,
            avg: best == null || best.avgRating <= 0 ? null : best.avgRating,
            ratingCount: best?.ratingCount ?? 0,
            completionCount: bestCompletions,
          ),
        ],
      ),
    );
  }
}

class _MinimalStatsRow extends StatelessWidget {
  final String? mostCompletedName;
  final double? avg;
  final int ratingCount;
  final int completionCount;

  const _MinimalStatsRow({
    required this.mostCompletedName,
    required this.avg,
    required this.ratingCount,
    required this.completionCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final baseSize = (tt.bodySmall?.fontSize ?? 12) + 2;
    final labelStyle = tt.bodySmall?.copyWith(
      fontSize: baseSize,
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final valueStyle = tt.bodySmall?.copyWith(
      fontSize: baseSize,
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final valueBoldStyle = valueStyle?.copyWith(fontWeight: FontWeight.w900);

    Widget dot() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('·', style: labelStyle),
        );

    final avgText = avg == null ? '—' : '${avg!.toStringAsFixed(1)} / 5';

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Completions ', style: labelStyle),
          Text('$completionCount', style: valueStyle),
          dot(),
          Text('Ratings ', style: labelStyle),
          Text('$ratingCount', style: valueStyle),
          dot(),
          Text('Avg ', style: labelStyle),
          Text(avgText, style: valueStyle),
          dot(),
          Text('Most completed ', style: labelStyle),
          Text(
            mostCompletedName ?? '—',
            style: valueBoldStyle,
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

enum _ProgressRange { quarter, year }

int _quarterForMonth(int month) {
  // 0=Jan-Apr, 1=May-Aug, 2=Sep-Dec
  if (month >= 1 && month <= 4) return 0;
  if (month >= 5 && month <= 8) return 1;
  return 2;
}

({DateTime start, DateTime end}) _yearRange(int year) {
  final start = DateTime(year, 1, 1);
  final end = DateTime(year, 12, 31);
  return (start: start, end: end);
}

({DateTime start, DateTime end}) _quarterRange(int year, int quarterIndex) {
  final q = quarterIndex.clamp(0, 2);
  final startMonth = (q == 0) ? 1 : (q == 1 ? 5 : 9);
  final endMonth = (q == 0) ? 4 : (q == 1 ? 8 : 12);
  final start = DateTime(year, startMonth, 1);
  final end = DateTime(year, endMonth + 1, 0); // last day of endMonth
  return (start: start, end: end);
}

class _QuarterPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _QuarterPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = <int, String>{
      0: 'Jan–Apr',
      1: 'May–Aug',
      2: 'Sep–Dec',
    };
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value.clamp(0, 2),
        items: labels.entries
            .map(
              (e) => DropdownMenuItem<int>(
                value: e.key,
                child: Text(e.value),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          onChanged(v);
        },
      ),
    );
  }
}

