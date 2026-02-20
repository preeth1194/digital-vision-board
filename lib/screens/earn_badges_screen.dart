import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/habit_item.dart';
import '../services/logical_date_service.dart';
import '../services/ad_free_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_typography.dart';

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
  final ValueNotifier<int>? coinNotifier;

  const EarnBadgesScreen({
    super.key,
    required this.allHabits,
    required this.totalCoins,
    this.coinNotifier,
  });

  @override
  State<EarnBadgesScreen> createState() => _EarnBadgesScreenState();
}

class _EarnBadgesScreenState extends State<EarnBadgesScreen> {
  late List<_BadgeProgress> _progress;
  bool _isAdFreeToday = false;
  int _currentCoins = 0;

  @override
  void initState() {
    super.initState();
    _currentCoins = widget.totalCoins;
    _progress = _computeProgress();
    _loadAdFreeStatus();
  }

  Future<void> _loadAdFreeStatus() async {
    final adFree = await AdFreeService.isAdFreeToday();
    if (mounted) setState(() => _isAdFreeToday = adFree);
  }

  Future<void> _redeemAdFree() async {
    final newTotal = await AdFreeService.goAdFreeWithCoins();
    if (newTotal == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough coins! You need 20 coins.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (mounted) {
      widget.coinNotifier?.value = newTotal;
      setState(() {
        _isAdFreeToday = true;
        _currentCoins = newTotal;
      });
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Ad-free for today!'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    final unlockedCount = _progress.where((p) => p.isUnlocked).length;

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.skyGradient(isDark: isDarkTheme),
      ),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Colors.transparent,
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
              totalCoins: _currentCoins,
              unlockedCount: unlockedCount,
              totalCount: _progress.length,
            ),
          ),
          // Go Ad-Free card
          SliverToBoxAdapter(
            child: _GoAdFreeCard(
              currentCoins: _currentCoins,
              isActiveToday: _isAdFreeToday,
              onRedeem: _redeemAdFree,
            ),
          ),
          // Section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Badges',
                style: AppTypography.heading2(context).copyWith(
                  color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;

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
              ? colorScheme.onSurface.withValues(alpha: 0.08)
              : AppColors.gold.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? colorScheme.shadow.withValues(alpha: 0.3)
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
                  style: AppTypography.heading1(context).copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$unlockedCount of $totalCount badges earned',
                  style: AppTypography.secondary(context),
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
    final colorScheme = Theme.of(context).colorScheme;
    final badge = progress.badge;
    final unlocked = progress.isUnlocked;

    final bgColor = isDark
        ? (unlocked
            ? badge.color.withValues(alpha: 0.18)
            : colorScheme.onSurface.withValues(alpha: 0.05))
        : (unlocked
            ? badge.color.withValues(alpha: 0.10)
            : colorScheme.onSurface.withValues(alpha: 0.08));

    final iconColor = unlocked
        ? badge.color
        : (isDark
            ? colorScheme.onSurface.withValues(alpha: 0.25)
            : colorScheme.outline);

    final textColor = unlocked
        ? colorScheme.onSurface
        : (isDark
            ? colorScheme.onSurface.withValues(alpha: 0.35)
            : colorScheme.onSurfaceVariant);

    final subtitleColor = unlocked
        ? colorScheme.onSurfaceVariant
        : (isDark
            ? colorScheme.onSurface.withValues(alpha: 0.2)
            : colorScheme.outline);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? badge.color.withValues(alpha: isDark ? 0.35 : 0.25)
              : (isDark
                  ? colorScheme.onSurface.withValues(alpha: 0.06)
                  : colorScheme.onSurface.withValues(alpha: 0.15)),
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
                          ? colorScheme.onSurface.withValues(alpha: 0.06)
                          : colorScheme.onSurface.withValues(alpha: 0.10)),
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
                      color: colorScheme.outlineVariant,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: isDark
                          ? colorScheme.onSurface.withValues(alpha: 0.54)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            badge.name,
            style: AppTypography.bodySmall(context).copyWith(
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
            style: AppTypography.caption(context).copyWith(
              fontSize: 11,
              color: subtitleColor,
            ),
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
                    ? colorScheme.onSurface.withValues(alpha: 0.08)
                    : colorScheme.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  badge.color.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${progress.current} / ${badge.target}',
              style: AppTypography.caption(context).copyWith(
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
                style: AppTypography.caption(context).copyWith(
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

// ── Go Ad-Free card (daily reset) ──────────────────────────────────────────

class _GoAdFreeCard extends StatelessWidget {
  final int currentCoins;
  final bool isActiveToday;
  final VoidCallback onRedeem;

  const _GoAdFreeCard({
    required this.currentCoins,
    required this.isActiveToday,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final canAfford = currentCoins >= AdFreeService.adFreeCoinCost;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActiveToday
              ? [
                  colorScheme.primaryContainer,
                  colorScheme.primary.withValues(alpha: 0.12),
                ]
              : isDark
                  ? [
                      colorScheme.surfaceContainerHigh,
                      colorScheme.surfaceContainer,
                    ]
                  : [
                      const Color(0xFFFFF8E1),
                      const Color(0xFFFFF3CD),
                    ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActiveToday
              ? colorScheme.primary.withValues(alpha: 0.4)
              : AppColors.coinGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isActiveToday
                    ? colorScheme.primary
                    : AppColors.coinGold)
                .withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isActiveToday
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.goldLight, AppColors.goldDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: isActiveToday
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : null,
              border: isActiveToday
                  ? null
                  : Border.all(color: AppColors.amberBorder, width: 2),
              boxShadow: isActiveToday
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.goldDark.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Center(
              child: Icon(
                isActiveToday
                    ? Icons.check_circle_rounded
                    : Icons.monetization_on_rounded,
                size: 26,
                color: isActiveToday ? colorScheme.primary : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActiveToday
                      ? 'Ad-Free Active Today'
                      : 'Go Ad-Free Today!',
                  style: AppTypography.body(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActiveToday
                      ? 'Enjoy your ad-free experience'
                      : 'Use ${AdFreeService.adFreeCoinCost} coins to remove ads for today',
                  style: AppTypography.bodySmall(context).copyWith(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isActiveToday)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: canAfford ? onRedeem : null,
              icon: Icon(
                Icons.monetization_on_rounded,
                size: 18,
                color: canAfford
                    ? Colors.white
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              label: Text(
                '${AdFreeService.adFreeCoinCost}',
                style: AppTypography.button(context).copyWith(
                  color: canAfford
                      ? Colors.white
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford
                    ? AppColors.coinGold
                    : (isDark
                        ? colorScheme.surfaceContainerHigh
                        : colorScheme.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                elevation: canAfford ? 2 : 0,
              ),
            ),
        ],
      ),
    );
  }
}
