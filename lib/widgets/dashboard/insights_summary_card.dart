import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../utils/app_typography.dart';
import '../../models/vision_components.dart';
import '../../screens/global_insights_screen.dart';
import '../../services/habit_storage_service.dart';
import '../../services/logical_date_service.dart';
import 'glass_card.dart';

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

    return GlassCard(
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
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Insights',
                    style: AppTypography.heading3(context).copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                ),
              ],
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!_loaded)
                    SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        backgroundColor:
                            colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                      ),
                    )
                  else if (total == 0)
                    Text(
                      'No habits tracked yet',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    )
                  else ...[
                    Text(
                      '${(rate * 100).toStringAsFixed(0)}%',
                      style: AppTypography.heading1(context).copyWith(
                        fontSize: 38,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '$completedToday of $total done',
                      style: AppTypography.caption(context).copyWith(
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
                            colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
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
    );
  }
}
