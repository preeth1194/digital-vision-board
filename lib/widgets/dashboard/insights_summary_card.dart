import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/vision_components.dart';
import '../../screens/global_insights_screen.dart';
import '../../services/habit_storage_service.dart';
import '../../services/logical_date_service.dart';

class InsightsSummaryCard extends StatefulWidget {
  const InsightsSummaryCard({super.key});

  @override
  State<InsightsSummaryCard> createState() => _InsightsSummaryCardState();
}

class _InsightsSummaryCardState extends State<InsightsSummaryCard>
    with WidgetsBindingObserver {
  List<HabitItem> _habits = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHabits();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
    _loadHabits();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadHabits();
  }

  Future<void> _loadHabits() async {
    final habits = await HabitStorageService.loadAll();
    if (mounted) setState(() { _habits = habits; _loaded = true; });
  }

  void _openInsights() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Insights')),
          body: const GlobalInsightsScreen(
            components: <VisionComponent>[],
          ),
        ),
      ),
    );
    _loadHabits();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final now = LogicalDateService.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedToday =
        _habits.where((h) => h.isCompletedOnDate(today)).length;
    final total = _habits.length;
    final rate = total > 0 ? completedToday / total : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openInsights,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Insights',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_loaded)
                      SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          backgroundColor:
                              colorScheme.onPrimary.withValues(alpha: 0.3),
                        ),
                      )
                    else if (total == 0)
                      Text(
                        'No habits tracked yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      )
                    else ...[
                      Text(
                        '${(rate * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '$completedToday of $total done',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.end,
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: rate,
                          minHeight: 5,
                          backgroundColor:
                              colorScheme.onPrimary.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation(
                            colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
