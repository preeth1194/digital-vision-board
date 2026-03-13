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
      appBar: AppBar(
        title: Text('Preset Shop', style: AppTypography.heading3(context)),
      ),
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
                    size: 40,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preset marketplace',
                    style: AppTypography.heading3(context).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Curated presets will appear here soon.',
                    style: AppTypography.bodySmall(context).copyWith(
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
    final ctaText = canAfford
        ? 'Redeem ${AdFreeService.adFreeCoinCost}'
        : 'Need ${AdFreeService.adFreeCoinCost}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cloudDark : AppColors.cloudWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActiveToday
              ? colorScheme.primary.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : AppColors.forestDeep.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActiveToday
                  ? colorScheme.primary.withValues(alpha: 0.16)
                  : null,
              gradient: isActiveToday
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.goldLight, AppColors.goldDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: isActiveToday
                  ? null
                  : Border.all(
                      color: isDark
                          ? colorScheme.outline.withValues(alpha: 0.45)
                          : colorScheme.surface.withValues(alpha: 0.95),
                      width: 1.25,
                    ),
              boxShadow: isActiveToday
                  ? null
                  : [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.28)
                            : AppColors.forestDeep.withValues(alpha: 0.14),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Center(
              child: Icon(
                isActiveToday
                    ? Icons.check_circle_rounded
                    : Icons.monetization_on_rounded,
                size: 22,
                color: isActiveToday
                    ? colorScheme.primary
                    : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$currentCoins coins',
                  style: AppTypography.heading3(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActiveToday ? 'Ad-free is active today' : 'Remove ads for today',
                  style: AppTypography.bodySmall(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActiveToday
                      ? 'Enjoy a cleaner experience.'
                      : 'Use coins once for a 24-hour ad-free session.',
                  style: AppTypography.caption(context).copyWith(
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
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
            )
          else
            ElevatedButton(
              onPressed: canAfford ? onRedeem : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHigh,
                foregroundColor: canAfford
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                minimumSize: const Size(0, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                elevation: 0,
              ),
              child: Text(
                ctaText,
                style: AppTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: canAfford
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
