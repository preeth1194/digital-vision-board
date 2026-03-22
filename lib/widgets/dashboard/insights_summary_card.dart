import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../utils/app_spacing.dart';
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
    final todaysHabits = _habits.where((h) => h.isScheduledOnDate(today)).toList();
    final completed = todaysHabits.where((h) => h.isCompletedOnDate(today)).length;
    final total = todaysHabits.length;
    final rate = total > 0 ? completed / total : 0.0;
    final pct = (rate * 100).toStringAsFixed(0);

    return GlassCard(
      onTap: _openInsights,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_loaded) ...[
              SizedBox(
                height: AppSpacing.xs,
                child: LinearProgressIndicator(
                  backgroundColor:
                      colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                ),
              ),
            ] else if (total == 0) ...[
              Text(
                _habits.isEmpty ? 'No habits tracked yet' : 'No habits today',
                style: AppTypography.bodySmall(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Icon(Icons.insights_rounded, size: 22, color: colorScheme.primary),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$pct%',
                style: AppTypography.heading2(context)
                    .copyWith(color: colorScheme.primary),
              ),
              Text(
                '$completed of $total done',
                style: AppTypography.caption(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: rate,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Insights ›',
                style: AppTypography.caption(context).copyWith(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
