import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ad_free_service.dart';
import '../../services/ad_service.dart';
import '../../services/coins_service.dart';
import '../../services/subscription_service.dart';
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

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.ondemand_video_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reward Ads',
                    style: AppTypography.heading3(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$_coinsPerAd',
                    style: AppTypography.caption(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600, color: cs.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$_watchedInCycle/$_adsPerReward',
              style: AppTypography.heading1(context).copyWith(height: 1.0),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(_adsPerReward, (index) {
                final isFilled = index < _watchedInCycle;
                return Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(right: index == _adsPerReward - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: isFilled ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _showAds ? 'Each ad earns $_coinsPerAd coins' : 'Ads disabled',
              style: AppTypography.caption(context).copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _onWatchAdTap,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle_fill_rounded, size: 18),
                label: _isLoading
                    ? const Text('Loading')
                    : Text(_showAds ? 'Watch ad' : 'Disabled'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
