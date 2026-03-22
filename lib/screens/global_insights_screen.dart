import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/insights_month_summary.dart';
import '../services/dv_auth_service.dart';
import '../services/habit_storage_service.dart';
import '../services/insight_share_service.dart';
import '../services/logical_date_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_typography.dart';
import '../utils/insights_period_bounds.dart';
import '../models/vision_components.dart';
import '../widgets/insights/insights_period_selector.dart';
import '../widgets/insights/share/insight_share_templates.dart';
import '../widgets/insights/stat_card.dart';
import '../widgets/insights/today_progress_card.dart';
import '../widgets/insights/weekly_activity_card.dart';

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
    final habit = _focusHabit;
    if (habit == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Choose a habit to share an insight card.',
            style: AppTypography.body(context),
          ),
        ),
      );
      return;
    }
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing images is not supported on web yet.'),
        ),
      );
      return;
    }

    final kind = await showInsightShareTemplatePicker(context);
    if (!mounted || kind == null) return;

    final summary = InsightsMonthSummary.forMonth(_year, _month);
    final payload = InsightSharePayload.fromHabit(
      habit: habit,
      summary: summary,
      logicalToday: LogicalDateService.today(),
    );
    final card = InsightShareTemplateCard(kind: kind, payload: payload);
    final ok = await InsightShareService.shareInsightCard(
      context: context,
      card: card,
      fileName: 'insight_${habit.id}_$_year$_month',
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

    final now = LogicalDateService.now();
    final today = DateTime(now.year, now.month, now.day);
    final todaysHabits = allHabits.where((h) => h.isScheduledOnDate(today)).toList();
    final completedHabitsToday =
        todaysHabits.where((h) => h.isCompletedOnDate(today)).length;
    final completionRate = todaysHabits.isNotEmpty
        ? (completedHabitsToday / todaysHabits.length * 100)
        : 0.0;

    final summary = InsightsMonthSummary.forMonth(_year, _month);
    final focus = _focusHabit;

    return ListView(
      key: ValueKey(widget.components.length),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        TodayProgressCard(
          completionRate: completionRate,
          completedToday: completedHabitsToday,
          totalHabits: todaysHabits.length,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Month',
          style: AppTypography.heading3(context),
        ),
        const SizedBox(height: AppSpacing.sm),
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
        const SizedBox(height: AppSpacing.md),
        Text(
          'Habit',
          style: AppTypography.heading3(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        _HabitDropdown(
          habits: allHabits,
          selectedId: _focusHabitId,
          onChanged: (id) => setState(() => _focusHabitId = id),
        ),
        const SizedBox(height: AppSpacing.lg),
        HabitTrendsChart(
          habits: allHabits,
          year: _year,
          month: _month,
          focusHabit: focus,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (focus != null) _HabitInsightStrip(habit: focus, summary: summary),
        if (focus == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'Select a habit to see scheduled days, seeds, and streak for this month — and to share a card.',
              style: AppTypography.secondary(context),
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.5,
          children: [
            StatCard(
              title: 'Active Habits',
              value: allHabits.length.toString(),
              icon: Icons.check_circle_outline,
              color: colorScheme.primary,
            ),
            StatCard(
              title: 'Longest Streak',
              value: _calculateLongestStreak(allHabits).toString(),
              icon: Icons.local_fire_department,
              color: AppColors.seedGold,
            ),
          ],
        ),
      ],
    );
  }

  static int _calculateLongestStreak(List<HabitItem> habits) {
    final logicalToday = LogicalDateService.today();
    var maxStreak = 0;
    for (final habit in habits) {
      final streak = habit.currentStreakAsOf(logicalToday);
      if (streak > maxStreak) maxStreak = streak;
    }
    return maxStreak;
  }
}

class _HabitDropdown extends StatelessWidget {
  const _HabitDropdown({
    required this.habits,
    required this.selectedId,
    required this.onChanged,
  });

  final List<HabitItem> habits;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: selectedId,
          hint: Text(
            'All habits',
            style: AppTypography.body(context),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'All habits',
                style: AppTypography.body(context),
              ),
            ),
            ...habits.map(
              (h) => DropdownMenuItem<String?>(
                value: h.id,
                child: Text(
                  h.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(context),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _HabitInsightStrip extends StatelessWidget {
  const _HabitInsightStrip({
    required this.habit,
    required this.summary,
  });

  final HabitItem habit;
  final InsightsMonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scheduled = InsightsMonthSummary.scheduledDaysInMonth(habit, summary);
    final done = InsightsMonthSummary.completedScheduledDaysInMonth(
      habit,
      summary,
    );
    final seeds = InsightsMonthSummary.seedsEarnedInMonth(habit, summary);
    final est = InsightsMonthSummary.estimatedMinutesInvested(habit, summary);
    final streak = habit.currentStreakAsOf(LogicalDateService.today());
    final run = InsightsMonthSummary.longestCompletionRunInMonth(
      habit,
      summary,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              habit.name,
              style: AppTypography.heading3(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$done of $scheduled scheduled days completed this month',
              style: AppTypography.body(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$seeds seeds this month',
              style: AppTypography.bodySmall(context).copyWith(
                color: AppColors.honeyText,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (est != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'About $est minutes invested (from your session length)',
                style: AppTypography.bodySmall(context),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Streak: $streak · Best run this month: $run days',
              style: AppTypography.secondary(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Small steps add up. Your garden grows at its own pace.',
              style: AppTypography.caption(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
