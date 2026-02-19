import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dv_auth_service.dart';

/// Subscription plan definition.
class SubscriptionPlan {
  final String productId;
  final String label;
  final String duration;
  final String price;
  final String? savings;

  const SubscriptionPlan({
    required this.productId,
    required this.label,
    required this.duration,
    required this.price,
    this.savings,
  });
}

/// Wraps the `in_app_purchase` plugin for App Store / Play Store subscriptions.
class SubscriptionService {
  SubscriptionService._();

  static const String _subscribedKey = 'is_subscribed';
  static const String _activePlanKey = 'active_plan_id';

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      productId: 'dvb_premium_1month',
      label: '1 Month',
      duration: 'monthly',
      price: '\$4.99/mo',
    ),
    SubscriptionPlan(
      productId: 'dvb_premium_3month',
      label: '3 Months',
      duration: 'quarterly',
      price: '\$11.99/qtr',
      savings: 'Save 20%',
    ),
    SubscriptionPlan(
      productId: 'dvb_premium_6month',
      label: '6 Months',
      duration: 'semi-annual',
      price: '\$19.99/6mo',
      savings: 'Save 33%',
    ),
    SubscriptionPlan(
      productId: 'dvb_premium_1year',
      label: '1 Year',
      duration: 'annual',
      price: '\$34.99/yr',
      savings: 'Best Value - Save 42%',
    ),
  ];

  static Set<String> get _productIds =>
      plans.map((p) => p.productId).toSet();

  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static final ValueNotifier<bool> isSubscribed = ValueNotifier(false);
  static final ValueNotifier<String?> activePlanId = ValueNotifier(null);

  // Cached product details from the store (populated after query).
  static final Map<String, ProductDetails> storeProducts = {};

  // ------------------------------------------------------------------
  // Initialization
  // ------------------------------------------------------------------

  static Future<void> initialize({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    isSubscribed.value = p.getBool(_subscribedKey) ?? false;
    activePlanId.value = p.getString(_activePlanKey);

    if (!await InAppPurchase.instance.isAvailable()) {
      debugPrint('In-app purchases not available on this device.');
      return;
    }

    _subscription?.cancel();
    _subscription =
        InAppPurchase.instance.purchaseStream.listen(_onPurchaseUpdate);

    // Fetch real prices from the store
    final response =
        await InAppPurchase.instance.queryProductDetails(_productIds);
    for (final detail in response.productDetails) {
      storeProducts[detail.id] = detail;
    }

    await InAppPurchase.instance.restorePurchases();
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  // ------------------------------------------------------------------
  // Purchase flow
  // ------------------------------------------------------------------

  static Future<bool> buyPlan(String productId) async {
    if (!await InAppPurchase.instance.isAvailable()) return false;

    final detail = storeProducts[productId];
    if (detail == null) {
      // Fallback: query just this product
      final response = await InAppPurchase.instance
          .queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        debugPrint('No product found for $productId');
        return false;
      }
      storeProducts[productId] = response.productDetails.first;
    }

    final product = storeProducts[productId]!;
    final param = PurchaseParam(productDetails: product);
    return InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
  }

  /// Restore previous purchases (e.g. after reinstall).
  static Future<void> restorePurchases() async {
    if (!await InAppPurchase.instance.isAvailable()) return;
    await InAppPurchase.instance.restorePurchases();
  }

  /// Get the store price for a plan, falling back to the hardcoded price.
  static String priceForPlan(SubscriptionPlan plan) {
    final detail = storeProducts[plan.productId];
    return detail?.price ?? plan.price;
  }

  // ------------------------------------------------------------------
  // Purchase stream handler
  // ------------------------------------------------------------------

  static Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (_productIds.contains(purchase.productID)) {
          await _grantSubscription(purchase.productID, source: 'store');
        }
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchase.error}');
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending...');
      }
    }
  }

  static Future<void> _grantSubscription(String productId, {String? source}) async {
    isSubscribed.value = true;
    activePlanId.value = productId;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_subscribedKey, true);
    await p.setString(_activePlanKey, productId);
    unawaited(_syncSubscriptionToBackend(productId, true, source: source));
  }

  static Future<void> _syncSubscriptionToBackend(
      String planId, bool active, {String? source}) async {
    try {
      await DvAuthService.putUserSettings(
        subscriptionPlanId: planId,
        subscriptionActive: active,
        subscriptionSource: source,
      );
    } catch (e) {
      debugPrint('Subscription backend sync failed: $e');
    }
  }

  /// Restore subscription state from backend bootstrap data.
  static Future<void> applyBootstrapData({
    required bool subscriptionActive,
    String? subscriptionPlanId,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    isSubscribed.value = subscriptionActive;
    activePlanId.value = subscriptionPlanId;
    await p.setBool(_subscribedKey, subscriptionActive);
    if (subscriptionPlanId != null && subscriptionPlanId.isNotEmpty) {
      await p.setString(_activePlanKey, subscriptionPlanId);
    } else {
      await p.remove(_activePlanKey);
    }
  }

  // ------------------------------------------------------------------
  // Gift code redemption
  // ------------------------------------------------------------------

  static Future<({bool valid, String? planId, String? error})>
      validateGiftCode(String code) async {
    try {
      final token = await DvAuthService.getDvToken();
      if (token == null) {
        return (valid: false, planId: null, error: 'not_authenticated');
      }
      final uri = Uri.parse(
        '${DvAuthService.backendBaseUrl()}/gift-codes/validate?code=${Uri.encodeComponent(code.trim().toUpperCase())}',
      );
      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'accept': 'application/json',
      });
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (valid: false, planId: null, error: 'server_error');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['valid'] == true) {
        return (
          valid: true,
          planId: body['plan_id'] as String?,
          error: null,
        );
      }
      return (
        valid: false,
        planId: null,
        error: (body['error'] as String?) ?? 'invalid_code',
      );
    } catch (e) {
      debugPrint('validateGiftCode error: $e');
      return (valid: false, planId: null, error: 'network_error');
    }
  }

  static Future<({bool ok, String? planId, String? error})>
      redeemGiftCode(String code) async {
    try {
      final token = await DvAuthService.getDvToken();
      if (token == null) {
        return (ok: false, planId: null, error: 'not_authenticated');
      }
      final uri = Uri.parse(
        '${DvAuthService.backendBaseUrl()}/gift-codes/redeem',
      );
      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({'code': code.trim().toUpperCase()}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return (ok: false, planId: null, error: 'server_error');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] == true) {
        final planId = body['plan_id'] as String? ?? 'dvb_premium_1year';
        await _grantSubscription(planId);
        return (ok: true, planId: planId, error: null);
      }
      return (
        ok: false,
        planId: null,
        error: (body['error'] as String?) ?? 'redeem_failed',
      );
    } catch (e) {
      debugPrint('redeemGiftCode error: $e');
      return (ok: false, planId: null, error: 'network_error');
    }
  }
}
