import 'package:shared_preferences/shared_preferences.dart';

import 'coins_service.dart';
import 'logical_date_service.dart';
import 'subscription_service.dart';

/// Centralized gating logic for whether ads should be shown.
///
/// A user is ad-free if:
///   1. They hold an active subscription (permanent), **or**
///   2. They redeemed 20 coins **today** (daily reset).
class AdFreeService {
  AdFreeService._();

  static const String _adFreeCoinDateKey = 'ad_free_coin_date';
  static const int adFreeCoinCost = 20;

  /// Returns `true` when the user should see ads (i.e. is NOT ad-free).
  static Future<bool> shouldShowAds({SharedPreferences? prefs}) async {
    if (SubscriptionService.isSubscribed.value) return false;
    return !(await isAdFreeToday(prefs: prefs));
  }

  /// Whether the user redeemed coins for ad-free **today**.
  static Future<bool> isAdFreeToday({SharedPreferences? prefs}) async {
    if (SubscriptionService.isSubscribed.value) return true;
    final p = prefs ?? await SharedPreferences.getInstance();
    final storedDate = p.getString(_adFreeCoinDateKey);
    if (storedDate == null) return false;
    return storedDate == LogicalDateService.isoToday();
  }

  /// Deduct 20 coins and mark today as ad-free.
  /// Returns the new coin total, or `null` if the user doesn't have enough coins.
  static Future<int?> goAdFreeWithCoins({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final balance = await CoinsService.getTotalCoins(prefs: p);
    if (balance < adFreeCoinCost) return null;

    final newTotal = await CoinsService.addCoins(-adFreeCoinCost, prefs: p);
    await p.setString(_adFreeCoinDateKey, LogicalDateService.isoToday());
    return newTotal;
  }
}
