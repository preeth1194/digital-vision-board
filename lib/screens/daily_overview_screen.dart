import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/daily_overview_service.dart';
import '../services/logical_date_service.dart';

class DailyOverviewScreen extends StatefulWidget {
  const DailyOverviewScreen({super.key});

  @override
  State<DailyOverviewScreen> createState() => _DailyOverviewScreenState();
}

class _DailyOverviewScreenState extends State<DailyOverviewScreen> {
  bool _loading = true;
  Map<String, DailyMoodSummary> _byIso = const {};

  DateTime _focusedDay = LogicalDateService.today();
  DateTime _selectedDay = LogicalDateService.today();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final byIso = await DailyOverviewService.buildMoodByIsoDate();
      if (!mounted) return;
      setState(() => _byIso = byIso);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DailyMoodSummary? _summaryFor(DateTime day) {
    final iso = LogicalDateService.toIsoDate(day);
    return _byIso[iso];
  }

  Color? _bgForAvg(double avg, ColorScheme scheme) {
    // 1..5 -> red..green (simple buckets)
    if (avg >= 4.5) return Colors.green.withOpacity(0.35);
    if (avg >= 3.5) return Colors.lightGreen.withOpacity(0.28);
    if (avg >= 2.5) return Colors.amber.withOpacity(0.25);
    if (avg >= 1.5) return Colors.orange.withOpacity(0.25);
    return scheme.errorContainer.withOpacity(0.28);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final scheme = Theme.of(context).colorScheme;
    final selectedIso = LogicalDateService.toIsoDate(_selectedDay);
    final summary = _byIso[selectedIso];
    final avg = summary?.averageRating;
    final count = summary?.ratingCount ?? 0;
    final items = summary?.items ?? const <DailyRatingItem>[];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Daily Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableGestures: AvailableGestures.horizontalSwipe,
                selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focused) => setState(() => _focusedDay = focused),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, _) {
                    final s = _summaryFor(day);
                    final a = s?.averageRating;
                    if (a == null) return null;
                    return Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _bgForAvg(a, scheme),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text('${day.day}'),
                    );
                  },
                  todayBuilder: (context, day, _) {
                    final s = _summaryFor(day);
                    final a = s?.averageRating;
                    final color = a == null ? scheme.primaryContainer : _bgForAvg(a, scheme);
                    return Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.primary, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    );
                  },
                  selectedBuilder: (context, day, _) {
                    final s = _summaryFor(day);
                    final a = s?.averageRating;
                    final color = a == null ? scheme.primary.withOpacity(0.18) : _bgForAvg(a, scheme);
                    return Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedIso,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    avg == null ? 'No ratings yet' : 'Mood: ${avg.toStringAsFixed(2)} / 5',
                  ),
                  const SizedBox(height: 6),
                  Text('$count rating${count == 1 ? '' : 's'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: Text('No feedback entries for this day.')),
            )
          else ...[
            Text(
              'Entries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...items.map((it) {
              final subtitle = (it.note ?? '').trim().isEmpty ? it.boardTitle : '${it.boardTitle} • ${it.note}';
              final leading = switch (it.kind) {
                DailyRatingKind.habit => const Icon(Icons.check_circle_outline),
                DailyRatingKind.task => const Icon(Icons.task_alt),
                DailyRatingKind.checklistItem => const Icon(Icons.checklist),
              };
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: leading,
                  title: Text(it.title),
                  subtitle: Text(subtitle),
                  trailing: Text(
                    it.rating.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

