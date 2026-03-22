import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ad_free_service.dart';
import '../../services/ad_service.dart';
import '../../services/coins_service.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import 'glass_card.dart';

class RewardAdsCoinCard extends StatefulWidget {
  const RewardAdsCoinCard({super.key, this.coinNotifier});

  final ValueNotifier<int>? coinNotifier;

  @override
  State<RewardAdsCoinCard> createState() => _RewardAdsCoinCardState();
}

class _RewardAdsCoinCardState extends State<RewardAdsCoinCard> {
  static const String _cycleWatchCountKey = 'dashboard_reward_cycle_watches_v1';
  /// Segments in the progress row (visual rhythm only; coins grant every ad).
  static const int _adsPerReward = 3;
  static const int _coinsPerAd = 20;

  SharedPreferences? _prefs;
  int _watchedInCycle = 0;
  bool _isLoading = false;
  bool _showAds = true;

  @override
  void initState() {
    super.initState();
    SubscriptionService.isSubscribed.addListener(_handleSubscriptionChanged);
    _loadState();
  }

  @override
  void dispose() {
    SubscriptionService.isSubscribed.removeListener(_handleSubscriptionChanged);
    super.dispose();
  }

  void _handleSubscriptionChanged() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final watched =
        ((prefs.getInt(_cycleWatchCountKey) ?? 0) % _adsPerReward).clamp(
      0,
      _adsPerReward - 1,
    );
    final showAds = await AdFreeService.shouldShowAds(prefs: prefs);
    if (!mounted) return;
    setState(() {
      _watchedInCycle = watched;
      _showAds = showAds;
    });
  }

  Future<void> _onWatchAdTap() async {
    if (_isLoading) return;
    if (!_showAds) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ads are disabled in ad-free mode.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final shown = await AdService.showRewardedAd(onRewarded: _handleRewardEarned);

    if (!shown && mounted) {
      AdService.loadRewardedAd();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reward ad not ready yet. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRewardEarned() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final previousRaw = prefs.getInt(_cycleWatchCountKey) ?? 0;
    final previousCount = previousRaw % _adsPerReward;
    final nextCount = (previousCount + 1) % _adsPerReward;

    await prefs.setInt(_cycleWatchCountKey, nextCount);
    final newTotal = await CoinsService.addCoins(_coinsPerAd, prefs: prefs);

    if (!mounted) return;
    setState(() => _watchedInCycle = nextCount);
    widget.coinNotifier?.value = newTotal;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Great! +$_coinsPerAd coins added.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Segment bar
    final segmentBar = Row(
      children: List.generate(_adsPerReward, (i) {
        final isFilled = i < _watchedInCycle;
        return Expanded(
          child: Container(
            height: AppSpacing.xs,
            margin: EdgeInsets.only(right: i < _adsPerReward - 1 ? AppSpacing.xs : 0),
            decoration: BoxDecoration(
              color: isFilled ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
          ),
        );
      }),
    );

    // Watch button — three states
    Widget watchButton;
    if (_isLoading) {
      watchButton = SizedBox(
        width: 72,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
        ),
      );
    } else if (!_showAds) {
      watchButton = FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          minimumSize: const Size(72, 36),
          shape: const StadiumBorder(),
        ),
        child: const Text('Off'),
      );
    } else {
      watchButton = FilledButton.icon(
        onPressed: _onWatchAdTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size(72, 36),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 14),
        label: const Text('Watch'),
      );
    }

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.ondemand_video_rounded, size: 18, color: cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rewards',
                    style: AppTypography.caption(context).copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  segmentBar,
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _showAds
                        ? '$_watchedInCycle of $_adsPerReward · +$_coinsPerAd coins per ad'
                        : 'Ads disabled',
                    style: AppTypography.caption(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            watchButton,
          ],
        ),
      ),
    );
  }
}
