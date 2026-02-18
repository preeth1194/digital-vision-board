import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/ad_service.dart';
import '../../utils/app_colors.dart';

/// A card styled like [AnimatedHabitCard] that tracks reward-ad progress
/// (X/5) for unlocking a new habit beyond the free limit.
///
/// When all 5 ads have been watched the card transitions to a "completed" state
/// and calls [onAllAdsWatched].
class RewardAdCard extends StatefulWidget {
  final String sessionKey;
  final int watchedCount;
  final VoidCallback onAdWatched;
  final VoidCallback onAllAdsWatched;

  const RewardAdCard({
    super.key,
    required this.sessionKey,
    required this.watchedCount,
    required this.onAdWatched,
    required this.onAllAdsWatched,
  });

  @override
  State<RewardAdCard> createState() => _RewardAdCardState();
}

class _RewardAdCardState extends State<RewardAdCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isPressed = false;
  bool _isLoading = false;

  bool get _isComplete =>
      widget.watchedCount >= AdService.requiredAdsPerHabit;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant RewardAdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget._wasComplete && _isComplete) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onAllAdsWatched();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_isComplete || _isLoading) return;

    setState(() => _isLoading = true);

    final shown = await AdService.showRewardedAd(
      onRewarded: () {
        widget.onAdWatched();
      },
    );

    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad not ready yet. Please try again in a moment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final watched = widget.watchedCount;
    final total = AdService.requiredAdsPerHabit;

    final textColor = isDark ? Colors.white : AppColors.nearBlack;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : AppColors.dimGrey;

    final progressFraction = (watched / total).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (!_isComplete) {
            setState(() => _isPressed = true);
            HapticFeedback.selectionClick();
          }
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..setEntry(0, 0, _isPressed ? 0.98 : 1.0)
            ..setEntry(1, 1, _isPressed ? 0.98 : 1.0),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isComplete
                  ? AppColors.coinGold.withValues(alpha: 0.5)
                  : colorScheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isPressed ? 0.04 : 0.08),
                blurRadius: _isPressed ? 4 : 12,
                offset: Offset(0, _isPressed ? 1 : 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isComplete
                      ? AppColors.coinGold.withValues(alpha: 0.2)
                      : colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(
                        _isComplete
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_fill_rounded,
                        color: _isComplete
                            ? AppColors.coinGold
                            : colorScheme.primary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 14),
              // Title + progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isComplete
                          ? 'Habit Unlocked!'
                          : 'Watch Ads to Unlock Habit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        decoration: _isComplete
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressFraction,
                        minHeight: 4,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isComplete
                              ? AppColors.coinGold
                              : colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isComplete
                          ? 'All ads watched!'
                          : 'Tap to watch ad',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Duration-style badge showing X/5
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_rounded,
                    size: 16,
                    color: subtitleColor,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$watched/$total',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isComplete
                          ? AppColors.coinGold
                          : subtitleColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on RewardAdCard {
  bool get _wasComplete =>
      watchedCount >= AdService.requiredAdsPerHabit;
}
