import 'package:flutter/material.dart';

import '../models/habit_item.dart';
import '../services/coins_service.dart';
import '../services/logical_date_service.dart';
import '../utils/app_colors.dart';

/// Definition of a single badge / achievement.
class _BadgeDef {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int target;

  const _BadgeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.target,
  });
}

/// Computed progress for a badge.
class _BadgeProgress {
  final _BadgeDef badge;
  final int current;
  bool get isUnlocked => current >= badge.target;
  double get progress =>
      badge.target > 0 ? (current / badge.target).clamp(0.0, 1.0) : 0.0;

  const _BadgeProgress({required this.badge, required this.current});
}

// ── Badge definitions ──────────────────────────────────────────────────────

const _badges = <_BadgeDef>[
  _BadgeDef(
    id: 'first_step',
    name: 'First Step',
    description: 'Complete your first habit',
    icon: Icons.flag_rounded,
    color: AppColors.badgeGreen,
    target: 1,
  ),
  _BadgeDef(
    id: 'week_warrior',
    name: 'Week Warrior',
    description: '7-day streak on any habit',
    icon: Icons.local_fire_department_rounded,
    color: AppColors.badgeOrangeRed,
    target: 7,
  ),
  _BadgeDef(
    id: 'consistency_king',
    name: 'Consistency King',
    description: '30-day streak on any habit',
    icon: Icons.diamond_rounded,
    color: AppColors.badgePurple,
    target: 30,
  ),
  _BadgeDef(
    id: 'century_club',
    name: 'Century Club',
    description: '100 total habit check-ins',
    icon: Icons.military_tech_rounded,
    color: AppColors.badgeAmber,
    target: 100,
  ),
  _BadgeDef(
    id: 'perfect_day',
    name: 'Perfect Day',
    description: 'Complete all habits in a day',
    icon: Icons.wb_sunny_rounded,
    color: AppColors.badgeYellow,
    target: 1,
  ),
  _BadgeDef(
    id: 'coin_collector',
    name: 'Coin Collector',
    description: 'Earn 500+ total coins',
    icon: Icons.savings_rounded,
    color: AppColors.badgeTeal,
    target: 500,
  ),
  _BadgeDef(
    id: 'coin_hoarder',
    name: 'Coin Hoarder',
    description: 'Earn 2 000+ total coins',
    icon: Icons.account_balance_rounded,
    color: AppColors.badgeOrchid,
    target: 2000,
  ),
  _BadgeDef(
    id: 'multi_tasker',
    name: 'Multi-Tasker',
    description: 'Have 5+ active habits',
    icon: Icons.dashboard_customize_rounded,
    color: AppColors.badgeSkyBlue,
    target: 5,
  ),
  _BadgeDef(
    id: 'coping_champion',
    name: 'Coping Champion',
    description: 'Set a coping plan on a habit',
    icon: Icons.psychology_rounded,
    color: AppColors.badgePink,
    target: 1,
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────

class EarnBadgesScreen extends StatefulWidget {
  final List<HabitItem> allHabits;
  final int totalCoins;

  const EarnBadgesScreen({
    super.key,
    required this.allHabits,
    required this.totalCoins,
  });

  @override
  State<EarnBadgesScreen> createState() => _EarnBadgesScreenState();
}

class _EarnBadgesScreenState extends State<EarnBadgesScreen> {
  late List<_BadgeProgress> _progress;

  @override
  void initState() {
    super.initState();
    _progress = _computeProgress();
  }

  List<_BadgeProgress> _computeProgress() {
    final habits = widget.allHabits;
    final coins = widget.totalCoins;

    // Max streak across all habits
    int maxStreak = 0;
    int totalCompletions = 0;
    for (final h in habits) {
      if (h.currentStreak > maxStreak) maxStreak = h.currentStreak;
      totalCompletions += h.completedDates.length;
    }

    // Perfect day: check if today's scheduled habits are all completed
    final now = LogicalDateService.now();
    final scheduledToday = habits.where((h) => h.isScheduledOnDate(now)).toList();
    final allCompletedToday = scheduledToday.isNotEmpty &&
        scheduledToday.every((h) => h.isCompletedForCurrentPeriod(now));

    // Coping champion: any habit that has a coping plan set
    final hasCopingPlan =
        habits.any((h) => h.cbtEnhancements?.ifThenPlan?.isNotEmpty == true);

    return _badges.map((badge) {
      int current;
      switch (badge.id) {
        case 'first_step':
          current = totalCompletions.clamp(0, 1);
          break;
        case 'week_warrior':
          current = maxStreak.clamp(0, 7);
          break;
        case 'consistency_king':
          current = maxStreak.clamp(0, 30);
          break;
        case 'century_club':
          current = totalCompletions.clamp(0, 100);
          break;
        case 'perfect_day':
          current = allCompletedToday ? 1 : 0;
          break;
        case 'coin_collector':
          current = coins.clamp(0, 500);
          break;
        case 'coin_hoarder':
          current = coins.clamp(0, 2000);
          break;
        case 'multi_tasker':
          current = habits.length.clamp(0, 5);
          break;
        case 'coping_champion':
          current = hasCopingPlan ? 1 : 0;
          break;
        default:
          current = 0;
      }
      return _BadgeProgress(badge: badge, current: current);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final unlockedCount = _progress.where((p) => p.isUnlocked).length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Summary card
          SliverToBoxAdapter(
            child: _SummaryCard(
              totalCoins: widget.totalCoins,
              unlockedCount: unlockedCount,
              totalCount: _progress.length,
            ),
          ),
          // Section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Badges',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.darkest,
                ),
              ),
            ),
          ),
          // Badge grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _BadgeCard(progress: _progress[index]),
                childCount: _progress.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Summary card ───────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int totalCoins;
  final int unlockedCount;
  final int totalCount;

  const _SummaryCard({
    required this.totalCoins,
    required this.unlockedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.badgeBgDarkStart, AppColors.badgeBgDarkEnd]
              : [AppColors.badgeBgLightStart, AppColors.badgeBgLightEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.gold.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : AppColors.gold.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Coin stack icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.goldLight, AppColors.goldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.amberBorder, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldDark.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.monetization_on_rounded,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalCoins coins',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.darkest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$unlockedCount of $totalCount badges earned',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.dark.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual badge card ──────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  final _BadgeProgress progress;

  const _BadgeCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badge = progress.badge;
    final unlocked = progress.isUnlocked;

    final bgColor = isDark
        ? (unlocked
            ? badge.color.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05))
        : (unlocked
            ? badge.color.withValues(alpha: 0.10)
            : Colors.grey.withValues(alpha: 0.08));

    final iconColor = unlocked
        ? badge.color
        : (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade400);

    final textColor = unlocked
        ? (isDark ? Colors.white : AppColors.darkest)
        : (isDark ? Colors.white.withValues(alpha: 0.35) : Colors.grey.shade500);

    final subtitleColor = unlocked
        ? (isDark
            ? Colors.white.withValues(alpha: 0.6)
            : AppColors.dark.withValues(alpha: 0.65))
        : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade400);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? badge.color.withValues(alpha: isDark ? 0.35 : 0.25)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.15)),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with lock overlay
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? badge.color.withValues(alpha: isDark ? 0.25 : 0.15)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.withValues(alpha: 0.10)),
                ),
                child: Icon(badge.icon, size: 28, color: iconColor),
              ),
              if (!unlocked)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.slateGrey : Colors.grey.shade300,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Description
          Text(
            badge.description,
            style: TextStyle(fontSize: 11, color: subtitleColor),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Progress bar
          if (!unlocked) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 5,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  badge.color.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${progress.current} / ${badge.target}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
          ],
          if (unlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: badge.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Earned',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badge.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
