import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/challenge.dart';
import '../../models/habit_item.dart';
import '../../services/challenge_storage_service.dart';
import '../../services/habit_storage_service.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_typography.dart';
import '../rituals/interactive_progress_growth_image.dart';
import '../rituals/habit_form_constants.dart';
import 'glass_card.dart';

class HabitProgressCompletionCard extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onStartChallenge;
  final int dataVersion;

  const HabitProgressCompletionCard({
    super.key,
    this.onTap,
    this.onStartChallenge,
    this.dataVersion = 0,
  });

  @override
  State<HabitProgressCompletionCard> createState() =>
      _HabitProgressCompletionCardState();
}

class _HabitProgressCompletionCardState extends State<HabitProgressCompletionCard>
    with WidgetsBindingObserver {
  bool _loaded = false;
  SharedPreferences? _prefs;
  List<HabitItem> _habits = const [];
  Challenge? _activeChallenge;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
    _load();
  }

  @override
  void didUpdateWidget(covariant HabitProgressCompletionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataVersion != widget.dataVersion) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final habits = await HabitStorageService.loadAll(prefs: prefs);
    final challenge = await ChallengeStorageService.getActiveChallenge(prefs: prefs);

    if (!mounted) return;
    setState(() {
      _habits = habits;
      _activeChallenge = (challenge?.isActive ?? false) ? challenge : null;
      _loaded = true;
    });
  }

  /// Fixed-width leading columns so every completion icon and category icon
  /// shares the same horizontal start.
  Widget _buildHabitProgressListRow(
    BuildContext context, {
    required HabitItem h,
    required DateTime today,
    required Color checkDoneColor,
    required Color checkTodoColor,
    required Color nameColorWhenDone,
    required Color nameColorWhenTodo,
    required Color categoryIconColor,
  }) {
    final done = h.isCompletedOnDate(today);
    final iconIdx = h.iconIndex ?? 0;
    final iconData = (iconIdx < habitIcons.length)
        ? habitIcons[iconIdx].$1
        : Icons.check_circle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                size: 16,
                color: done ? checkDoneColor : checkTodoColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(iconData, size: 14, color: categoryIconColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              h.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(context).copyWith(
                color: done ? nameColorWhenDone : nameColorWhenTodo,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = LogicalDateService.now();
    final today = DateTime(now.year, now.month, now.day);

    final todaysHabits = _habits.where((h) => h.isScheduledOnDate(today)).toList();
    final totalHabits = todaysHabits.length;
    final completedHabits = todaysHabits.where((h) => h.isCompletedOnDate(today)).length;
    final dailyProgress = totalHabits > 0
        ? (completedHabits / totalHabits).clamp(0.0, 1.0)
        : 0.0;
    final hasChallenge = _activeChallenge != null;

    if (!_loaded) {
      return GlassCard(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LinearProgressIndicator(
            backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.2),
          ),
        ),
      );
    }

    if (hasChallenge) {
      return _buildActiveChallengeLayout(
        context,
        _activeChallenge!,
        today,
        todaysHabits: todaysHabits,
      );
    }

    return _buildDailyProgressLayout(
      context,
      today: today,
      todaysHabits: todaysHabits,
      completedHabits: completedHabits,
      totalHabits: totalHabits,
      dailyProgress: dailyProgress,
    );
  }

  Widget _buildDailyProgressLayout(
    BuildContext context, {
    required DateTime today,
    required List<HabitItem> todaysHabits,
    required int completedHabits,
    required int totalHabits,
    required double dailyProgress,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 112,
                    child: _buildGrowthIndicator(
                      context,
                      progress: dailyProgress,
                      title: '${(dailyProgress * 100).round()}%',
                      subtitle: '',
                      textColor: cs.onPrimaryContainer,
                      subtitleColor: cs.onPrimaryContainer.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...todaysHabits.take(4).map(
                        (h) => _buildHabitProgressListRow(
                          context,
                          h: h,
                          today: today,
                          checkDoneColor: cs.primary,
                          checkTodoColor: cs.onPrimaryContainer.withValues(
                            alpha: 0.35,
                          ),
                          nameColorWhenDone: cs.onPrimaryContainer.withValues(
                            alpha: 0.45,
                          ),
                          nameColorWhenTodo: cs.onPrimaryContainer,
                          categoryIconColor: cs.onPrimaryContainer.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      if (todaysHabits.isEmpty)
                        Text(
                          'No habits today',
                          style: AppTypography.caption(context).copyWith(
                            color: cs.onPrimaryContainer.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: dailyProgress,
                minHeight: 5,
                backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$completedHabits of $totalHabits habits completed today',
              style: AppTypography.caption(context).copyWith(
                color: cs.onPrimaryContainer.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveChallengeLayout(
    BuildContext context,
    Challenge challenge,
    DateTime today,
    {required List<HabitItem> todaysHabits}
  ) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.onPrimaryContainer;
    final completedToday =
        todaysHabits.where((h) => h.isCompletedOnDate(today)).length;
    final totalHabits = todaysHabits.length;
    final allDoneToday = completedToday >= totalHabits && totalHabits > 0;

    return GlassCard(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Day ${challenge.currentDay}/${challenge.totalDays}',
                  style: AppTypography.caption(context).copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 112,
                    child: _buildGrowthIndicator(
                      context,
                      progress: challenge.progress,
                      title: '',
                      subtitle: '',
                      textColor: accent,
                      subtitleColor: accent.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (allDoneToday) ...[
                        Text(
                          'All done today!',
                          style: AppTypography.bodySmall(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                      ],
                      ...todaysHabits.take(6).map(
                        (h) => _buildHabitProgressListRow(
                          context,
                          h: h,
                          today: today,
                          checkDoneColor: cs.primary,
                          checkTodoColor: accent.withValues(alpha: 0.35),
                          nameColorWhenDone: accent.withValues(alpha: 0.45),
                          nameColorWhenTodo: accent,
                          categoryIconColor: accent.withValues(alpha: 0.5),
                        ),
                      ),
                      if (todaysHabits.isEmpty)
                        Text(
                          'No habits today',
                          style: AppTypography.caption(context).copyWith(
                            color: accent.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalHabits > 0 ? completedToday / totalHabits : 0,
                minHeight: 5,
                backgroundColor: accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  allDoneToday ? cs.primary : accent,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$completedToday of $totalHabits tasks completed today',
              style: AppTypography.caption(context).copyWith(
                color: accent.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthIndicator(
    BuildContext context, {
    required double progress,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final showTitle = title.trim().isNotEmpty;
    final showSubtitle = subtitle.trim().isNotEmpty;
    final imageSize = showTitle || showSubtitle ? 64.0 : 76.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: imageSize,
          height: imageSize,
          child: InteractiveProgressGrowthImage(
            progress: progress,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
            useGifAsDefault: true,
          ),
        ),
        if (showTitle) ...[
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.bodySmall(context).copyWith(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
        if (showSubtitle)
          Text(
            subtitle,
            style: AppTypography.caption(context).copyWith(
              color: subtitleColor,
            ),
          ),
      ],
    );
  }
}

