import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit_item.dart';
import '../../services/ad_free_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class PresetShopScreen extends StatefulWidget {
  final int totalCoins;
  final ValueNotifier<int>? coinNotifier;
  final List<HabitItem> allHabits;

  const PresetShopScreen({
    super.key,
    this.totalCoins = 0,
    this.coinNotifier,
    this.allHabits = const [],
  });

  @override
  State<PresetShopScreen> createState() => _PresetShopScreenState();
}

class _PresetShopScreenState extends State<PresetShopScreen> {
  bool _isAdFreeToday = false;
  late int _currentCoins;

  @override
  void initState() {
    super.initState();
    _currentCoins = widget.totalCoins;
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
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Preset Shop')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CoinsAndAdFreeCard(
            currentCoins: _currentCoins,
            isActiveToday: _isAdFreeToday,
            onRedeem: _redeemAdFree,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 44,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Upcoming feature',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Soon you will be able to shop presets uploaded by approved users.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinsAndAdFreeCard extends StatelessWidget {
  final int currentCoins;
  final bool isActiveToday;
  final VoidCallback onRedeem;

  const _CoinsAndAdFreeCard({
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActiveToday
              ? [
                  colorScheme.primaryContainer,
                  colorScheme.primary.withValues(alpha: 0.12),
                ]
              : isDark
              ? [colorScheme.surfaceContainerHigh, colorScheme.surfaceContainer]
              : [const Color(0xFFFFF8E1), const Color(0xFFFFF3CD)],
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
                  '$currentCoins coins',
                  style: AppTypography.heading1(context).copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isActiveToday ? 'Ad-Free Active Today' : 'Go Ad-Free Today!',
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
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(fontSize: 13, color: colorScheme.onSurfaceVariant),
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
                  horizontal: 14,
                  vertical: 10,
                ),
                elevation: canAfford ? 2 : 0,
              ),
            ),
        ],
      ),
    );
  }
}
