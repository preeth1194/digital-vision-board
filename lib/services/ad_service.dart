import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages AdMob banner and rewarded ads.
class AdService {
  AdService._();

  static bool _initialized = false;

  // ------------------------------------------------------------------
  // Test ad unit IDs (replace with real IDs for production builds)
  // ------------------------------------------------------------------
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return '';
  }

  // ------------------------------------------------------------------
  // Initialization
  // ------------------------------------------------------------------
  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    loadRewardedAd();
  }

  // ------------------------------------------------------------------
  // Banner ads
  // ------------------------------------------------------------------
  static BannerAd? _bannerAd;
  static final ValueNotifier<bool> bannerAdReady = ValueNotifier(false);

  static void loadBannerAd({AdSize size = AdSize.banner}) {
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => bannerAdReady.value = true,
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
          bannerAdReady.value = false;
        },
      ),
    )..load();
  }

  static BannerAd? get bannerAd => _bannerAd;

  static void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    bannerAdReady.value = false;
  }

  // ------------------------------------------------------------------
  // Rewarded ads
  // ------------------------------------------------------------------
  static RewardedAd? _rewardedAd;
  static final ValueNotifier<bool> rewardedAdReady = ValueNotifier(false);

  static void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          rewardedAdReady.value = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _rewardedAd = null;
          rewardedAdReady.value = false;
        },
      ),
    );
  }

  /// Show a rewarded ad. [onRewarded] is called when the user earns the reward.
  /// Returns `true` if the ad was shown, `false` if no ad was ready.
  static Future<bool> showRewardedAd({
    required void Function() onRewarded,
  }) async {
    if (_rewardedAd == null) return false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        rewardedAdReady.value = false;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        rewardedAdReady.value = false;
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) => onRewarded(),
    );
    return true;
  }

  // ------------------------------------------------------------------
  // Reward-ad watch tracking (per habit unlock session)
  // ------------------------------------------------------------------
  static const String _watchCountPrefix = 'reward_ads_watched_';
  static const int requiredAdsPerHabit = 5;

  /// Number of reward ads the user has watched for a given unlock session.
  static Future<int> getWatchedCount(String sessionKey,
      {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getInt('$_watchCountPrefix$sessionKey') ?? 0;
  }

  /// Increment the watched count for a session. Returns the new count.
  static Future<int> incrementWatchedCount(String sessionKey,
      {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final current = p.getInt('$_watchCountPrefix$sessionKey') ?? 0;
    final next = current + 1;
    await p.setInt('$_watchCountPrefix$sessionKey', next);
    return next;
  }

  /// Whether the user has watched enough ads to unlock a new habit.
  static Future<bool> isSessionComplete(String sessionKey,
      {SharedPreferences? prefs}) async {
    final count = await getWatchedCount(sessionKey, prefs: prefs);
    return count >= requiredAdsPerHabit;
  }

  /// Clear a completed session so the key doesn't linger.
  static Future<void> clearSession(String sessionKey,
      {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove('$_watchCountPrefix$sessionKey');
  }

  /// Get the current active unlock session key (if any).
  static Future<String?> getActiveSession(
      {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getString('active_ad_unlock_session');
  }

  /// Set the active unlock session key.
  static Future<void> setActiveSession(String? sessionKey,
      {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    if (sessionKey == null) {
      await p.remove('active_ad_unlock_session');
    } else {
      await p.setString('active_ad_unlock_session', sessionKey);
    }
  }
}
