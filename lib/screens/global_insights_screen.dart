import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/insights_month_summary.dart';
import '../services/dv_auth_service.dart';
import '../services/habit_storage_service.dart';
import '../services/insight_share_service.dart';
import '../services/logical_date_service.dart';
import '../utils/app_spacing.dart';
import '../utils/app_typography.dart';
import '../utils/insights_period_bounds.dart';
import '../models/vision_components.dart';
import '../widgets/insights/insights_period_selector.dart';
import '../widgets/insights/insights_habit_chips.dart';
import '../widgets/insights/habit_heatmap_card.dart';
import '../widgets/insights/insights_aggregate_chart.dart';
import '../widgets/insights/insights_stat_grid.dart';
import '../widgets/insights/insights_consistency_card.dart';
import '../widgets/insights/insights_month_overview_card.dart';

class GlobalInsightsScreen extends StatefulWidget {
  final List<VisionComponent> components;

  const GlobalInsightsScreen({super.key, required this.components});

  @override
  State<GlobalInsightsScreen> createState() => _GlobalInsightsScreenState();
}

class _GlobalInsightsScreenState extends State<GlobalInsightsScreen> {
  List<HabitItem> _habits = const [];
  int? _firstInstallMs;
  int _year = 0;
  int _month = 0;
  String? _focusHabitId;
  bool _loadedMeta = false;
  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: prefs);
    final installMs = await DvAuthService.getFirstInstallMs(prefs: prefs);
    final logicalToday = LogicalDateService.today();
    final first = InsightsPeriodBounds.firstSelectableMonth(
      firstInstallMs: installMs,
      logicalToday: logicalToday,
    );
    final last = InsightsPeriodBounds.lastSelectableMonth(logicalToday);
    final clamped = InsightsPeriodBounds.clampMonth(
      year: logicalToday.year,
      month: logicalToday.month,
      firstMonthStart: first,
      lastMonthStart: last,
    );
    if (!mounted) return;
    setState(() {
      _firstInstallMs = installMs;
      _year = clamped.year;
      _month = clamped.month;
      _loadedMeta = true;
    });
    await _loadHabits();
  }

  @override
  void didUpdateWidget(GlobalInsightsScreen old) {
    super.didUpdateWidget(old);
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final habits = await HabitStorageService.loadAll();
    if (!mounted) return;
    setState(() {
      _habits = habits;
      if (_focusHabitId != null &&
          !habits.any((h) => h.id == _focusHabitId)) {
        _focusHabitId = null;
      }
    });
  }

  DateTime get _firstMonth {
    final logicalToday = LogicalDateService.today();
    return InsightsPeriodBounds.firstSelectableMonth(
      firstInstallMs: _firstInstallMs,
      logicalToday: logicalToday,
    );
  }

  DateTime get _lastMonth =>
      InsightsPeriodBounds.lastSelectableMonth(LogicalDateService.today());

  HabitItem? get _focusHabit {
    final id = _focusHabitId;
    if (id == null) return null;
    for (final h in _habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> _onShare() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing images is not supported on web yet.'),
        ),
      );
      return;
    }

    final habit = _focusHabit;
    final fileName = habit != null
        ? 'insight_${habit.id}_$_year$_month'
        : 'insight_all_$_year$_month';

    final ok = await InsightShareService.shareWidgetBoundary(
      key: _chartKey,
      fileName: fileName,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the share sheet. Fully stop the app and run '
            '`flutter run` again — hot restart does not load new native plugins.',
            style: AppTypography.body(context),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allHabits = _habits;

    if (!_loadedMeta) {
      return const Center(child: CircularProgressIndicator());
    }

    if (allHabits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No activity to analyze yet',
              style: AppTypography.heading3(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final summary = InsightsMonthSummary.forMonth(_year, _month);
    final focus = _focusHabit;

    return ListView(
      key: ValueKey(widget.components.length),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        InsightsPeriodSelector(
          year: _year,
          month: _month,
          firstMonthStart: _firstMonth,
          lastMonthStart: _lastMonth,
          onMonthChanged: (v) {
            setState(() {
              _year = v.year;
              _month = v.month;
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        InsightsHabitChips(
          habits: allHabits,
          selectedId: _focusHabitId,
          onChanged: (id) => setState(() => _focusHabitId = id),
        ),
        const SizedBox(height: AppSpacing.lg),
        RepaintBoundary(
          key: _chartKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (focus == null)
                InsightsAggregateChart(
                  habits: allHabits,
                  year: _year,
                  month: _month,
                )
              else
                HabitHeatmapCard(
                  habit: focus,
                  habits: allHabits,
                  year: _year,
                  month: _month,
                ),
              const SizedBox(height: AppSpacing.md),
              if (focus != null) ...[
                InsightsStatGrid(habit: focus, summary: summary),
                const SizedBox(height: AppSpacing.md),
              ],
              if (focus == null) ...[
                InsightsMonthOverviewCard(
                  habits: allHabits,
                  summary: summary,
                ),
                const SizedBox(height: AppSpacing.md),
                InsightsConsistencyCard(
                  habits: allHabits,
                  year: _year,
                  month: _month,
                  onSelect: (id) => setState(() => _focusHabitId = id),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              // Branding footer — appears in shared image
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icon/app_icon.png',
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Habit Seeding',
                    style: AppTypography.caption(context).copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          label: 'Share insight card',
          button: true,
          child: FilledButton.icon(
            onPressed: _onShare,
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(
              'Share insight',
              style: AppTypography.button(context),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
