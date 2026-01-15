import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class HabitInsightsTab extends StatelessWidget {
  final ScrollController scrollController;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onFocusedDayChanged;
  final ValueChanged<DateTime> onSelectedDayChanged;

  final bool Function(DateTime day) isAnyHabitCompletedOnDate;
  final List<Map<String, dynamic>> last7DaysData;
  final int maxCount;

  const HabitInsightsTab({
    super.key,
    required this.scrollController,
    required this.focusedDay,
    required this.selectedDay,
    required this.onFocusedDayChanged,
    required this.onSelectedDayChanged,
    required this.isAnyHabitCompletedOnDate,
    required this.last7DaysData,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Calendar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: focusedDay,
                  selectedDayPredicate: (day) {
                    final normalizedDay = DateTime(day.year, day.month, day.day);
                    final normalizedSelected =
                        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                    return normalizedDay == normalizedSelected;
                  },
                  onDaySelected: (selected, focused) {
                    onSelectedDayChanged(selected);
                    onFocusedDayChanged(focused);
                  },
                  onPageChanged: (focused) => onFocusedDayChanged(focused),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  eventLoader: (day) => isAnyHabitCompletedOnDate(day) ? [1] : const [],
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return null;
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration:
                              const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last 7 Days',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxCount > 0 ? maxCount.toDouble() + 1 : 1,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.grey[800]!,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= last7DaysData.length) return const Text('');
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  last7DaysData[idx]['dayName'] as String,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              if (value == value.toInt()) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey[200]!,
                          strokeWidth: 1,
                        ),
                      ),
                      barGroups: last7DaysData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final count = entry.value['count'] as int;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: count.toDouble(),
                              color: Theme.of(context).colorScheme.primary,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

