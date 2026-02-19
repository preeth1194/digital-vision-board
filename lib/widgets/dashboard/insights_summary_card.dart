import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/vision_components.dart';
import '../../screens/global_insights_screen.dart';
import '../../services/habit_storage_service.dart';

class InsightsSummaryCard extends StatefulWidget {
  const InsightsSummaryCard({super.key});

  @override
  State<InsightsSummaryCard> createState() => _InsightsSummaryCardState();
}

class _InsightsSummaryCardState extends State<InsightsSummaryCard> {
  List<HabitItem> _habits = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final habits = await HabitStorageService.loadAll();
    if (mounted) setState(() { _habits = habits; _loaded = true; });
  }

  void _openInsights() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Insights')),
          body: const GlobalInsightsScreen(
            components: <VisionComponent>[],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Insights',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onPrimaryContainer.withOpacity(0.6),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                )
              else ...[
                Text(
                  '${(rate * 100).toStringAsFixed(0)}% complete today',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedToday of $total habits completed',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 6,
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
      ),
    );
  }
}
