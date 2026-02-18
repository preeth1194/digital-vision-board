import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../services/ad_service.dart';

/// Displays an AdMob banner ad. Auto-loads on init and disposes on removal.
///
/// Optionally auto-hides after [autoDismissDuration].
class BannerAdWidget extends StatefulWidget {
  final AdSize adSize;
  final Duration? autoDismissDuration;

  const BannerAdWidget({
    super.key,
    this.adSize = AdSize.banner,
    this.autoDismissDuration,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
          _scheduleAutoDismiss();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  void _scheduleAutoDismiss() {
    final duration = widget.autoDismissDuration;
    if (duration == null) return;
    Future.delayed(duration, () {
      if (mounted) setState(() => _dismissed = true);
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return AnimatedOpacity(
      opacity: _isLoaded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        alignment: Alignment.center,
        width: widget.adSize.width.toDouble(),
        height: widget.adSize.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
