import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
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

/// Wraps RevenueCat subscriptions while preserving existing app contracts.
class SubscriptionService {
  SubscriptionService._();

  static const String _subscribedKey = 'is_subscribed';
  static const String _activePlanKey = 'active_plan_id';
  static const String _rcAnonUserIdKey = 'rc_anon_user_id_v1';
  static const String _legacyGraceUntilMsKey = 'rc_legacy_grace_until_ms_v1';
  static const String _entitlementId = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'Habit-Seeding-Pro',
  );
  static const String _appleApiKey = String.fromEnvironment(
    'REVENUECAT_APPLE_API_KEY',
    defaultValue: '',
  );
  static const String _googleApiKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_API_KEY',
    defaultValue: '',
  );
  static const int _legacyGraceMs = 14 * 24 * 60 * 60 * 1000;

  static const List<SubscriptionPlan> _fallbackPlans = [
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

  static final ValueNotifier<bool> isSubscribed = ValueNotifier(false);
  static final ValueNotifier<String?> activePlanId = ValueNotifier(null);
  static final ValueNotifier<List<SubscriptionPlan>> availablePlans =
      ValueNotifier<List<SubscriptionPlan>>(List<SubscriptionPlan>.from(_fallbackPlans));
  static final ValueNotifier<String?> configNotice = ValueNotifier<String?>(null);

  static List<SubscriptionPlan> get plans => availablePlans.value;
  static String get entitlementId => _entitlementId;
  static bool get isRevenueCatConfigured => _revenueCatEnabled && _configured;

  static final Map<String, Package> _packagesByProductId = {};
  static bool _configured = false;
  static bool _listenerAttached = false;
  static bool _revenueCatEnabled = false;
  static SharedPreferences? _prefsRef;

  // ------------------------------------------------------------------
  // Initialization
  // ------------------------------------------------------------------

  static Future<void> initialize({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    _prefsRef = p;
    isSubscribed.value = p.getBool(_subscribedKey) ?? false;
    activePlanId.value = p.getString(_activePlanKey);
    availablePlans.value = List<SubscriptionPlan>.from(_fallbackPlans);

    final apiKey = _platformRevenueCatApiKey();
    if (kIsWeb || apiKey.isEmpty) {
      configNotice.value =
          'RevenueCat not configured. Add REVENUECAT_APPLE_API_KEY / REVENUECAT_GOOGLE_API_KEY.';
      debugPrint(
        'RevenueCat not configured for this platform. '
        'Set REVENUECAT_APPLE_API_KEY / REVENUECAT_GOOGLE_API_KEY.',
      );
      return;
    }
    configNotice.value = null;
    _revenueCatEnabled = true;

    final appUserId = await _resolveRevenueCatAppUserId(p);
    if (!_configured) {
      final config = PurchasesConfiguration(apiKey)..appUserID = appUserId;
      await Purchases.configure(config);
      _configured = true;
      debugPrint('RevenueCat configured (appUserId=$appUserId).');
    }

    if (!_listenerAttached) {
      Purchases.addCustomerInfoUpdateListener((customerInfo) async {
        await _applyCustomerInfo(
          customerInfo,
          source: 'revenuecat_listener',
          prefs: p,
        );
      });
      _listenerAttached = true;
    }

    await _refreshOfferings();
    await _refreshCustomerInfo(source: 'revenuecat_init', prefs: p);
  }

  static void dispose() {
    // Purchases SDK manages listener lifecycle; keep service stateful for app lifetime.
  }

  // ------------------------------------------------------------------
  // Purchase flow
  // ------------------------------------------------------------------

  static Future<bool> buyPlan(String productId) async {
    if (!_revenueCatEnabled) return false;
    var pkg = _packagesByProductId[productId];
    if (pkg == null) {
      await _refreshOfferings();
      pkg = _packagesByProductId[productId];
      if (pkg == null) {
        debugPrint('No RevenueCat package found for productId=$productId');
        return false;
      }
    }
    try {
      await Purchases.purchase(PurchaseParams.package(pkg));
      await _refreshCustomerInfo(source: 'revenuecat_purchase');
      return true;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('RevenueCat purchase failed ($code): ${e.message}');
      }
      return false;
    } catch (e) {
      debugPrint('RevenueCat purchase failed: $e');
      return false;
    }
  }

  /// Restore previous purchases (e.g. after reinstall).
  static Future<void> restorePurchases() async {
    if (!_revenueCatEnabled) return;
    try {
      await Purchases.restorePurchases();
      await _refreshCustomerInfo(source: 'revenuecat_restore');
    } catch (e) {
      debugPrint('RevenueCat restore failed: $e');
    }
  }

  /// Get the store price for a plan, falling back to known/static price.
  static String priceForPlan(SubscriptionPlan plan) {
    String? fromOfferings;
    for (final p in availablePlans.value) {
      if (p.productId == plan.productId) {
        fromOfferings = p.price;
        break;
      }
    }
    return fromOfferings ?? plan.price;
  }

  // ------------------------------------------------------------------
  // RevenueCat state handling
  // ------------------------------------------------------------------

  static Future<void> _refreshOfferings() async {
    if (!_revenueCatEnabled) return;
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        availablePlans.value = List<SubscriptionPlan>.from(_fallbackPlans);
        return;
      }
      final list = <SubscriptionPlan>[];
      _packagesByProductId.clear();
      for (final pkg in current.availablePackages) {
        final product = pkg.storeProduct;
        final productId = product.identifier;
        _packagesByProductId[productId] = pkg;
        list.add(
          SubscriptionPlan(
            productId: productId,
            label: product.title,
            duration: productId,
            price: product.priceString,
          ),
        );
      }
      if (list.isNotEmpty) {
        availablePlans.value = list;
      } else {
        availablePlans.value = List<SubscriptionPlan>.from(_fallbackPlans);
      }
      _logMissingExpectedPackages(current.availablePackages);
    } catch (e) {
      debugPrint('RevenueCat offerings fetch failed: $e');
      availablePlans.value = List<SubscriptionPlan>.from(_fallbackPlans);
    }
  }

  static Future<void> _refreshCustomerInfo({
    String source = 'revenuecat_refresh',
    SharedPreferences? prefs,
  }) async {
    if (!_revenueCatEnabled) return;
    try {
      final info = await Purchases.getCustomerInfo();
      await _applyCustomerInfo(info, source: source, prefs: prefs);
    } catch (e) {
      debugPrint('RevenueCat customer info fetch failed: $e');
      await _applyLegacyGraceIfNeeded(source: 'legacy_grace_fetch_failed', prefs: prefs);
    }
  }

  static Future<void> refreshCustomerInfo({
    String source = 'revenuecat_manual_refresh',
  }) async {
    await _refreshCustomerInfo(source: source);
  }

  static Future<void> _applyCustomerInfo(
    CustomerInfo info, {
    required String source,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? _prefsRef ?? await SharedPreferences.getInstance();
    final activeEntitlement = info.entitlements.active[_entitlementId];
    final productId = activeEntitlement?.productIdentifier ??
        (info.activeSubscriptions.isNotEmpty ? info.activeSubscriptions.first : null);
    final isActive = activeEntitlement != null || info.activeSubscriptions.isNotEmpty;

    if (isActive) {
      await _setSubscriptionState(
        isActive: true,
        planId: productId,
        source: source,
        prefs: p,
      );
      await p.remove(_legacyGraceUntilMsKey);
      return;
    }

    await _applyLegacyGraceIfNeeded(source: source, prefs: p);
  }

  static Future<void> _applyLegacyGraceIfNeeded({
    required String source,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? _prefsRef ?? await SharedPreferences.getInstance();
    final hadLegacyAccess = p.getBool(_subscribedKey) ?? false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var graceUntilMs = p.getInt(_legacyGraceUntilMsKey);
    if (hadLegacyAccess && graceUntilMs == null) {
      graceUntilMs = nowMs + _legacyGraceMs;
      await p.setInt(_legacyGraceUntilMsKey, graceUntilMs);
    }
    final graceActive = graceUntilMs != null && nowMs < graceUntilMs;
    if (graceActive && hadLegacyAccess) {
      await _setSubscriptionState(
        isActive: true,
        planId: activePlanId.value ?? p.getString(_activePlanKey),
        source: 'legacy_migration_grace',
        prefs: p,
        syncBackend: false,
      );
      return;
    }
    await _setSubscriptionState(
      isActive: false,
      planId: null,
      source: source,
      prefs: p,
    );
  }

  static Future<void> _setSubscriptionState({
    required bool isActive,
    required String? planId,
    required String source,
    SharedPreferences? prefs,
    bool syncBackend = true,
  }) async {
    final p = prefs ?? _prefsRef ?? await SharedPreferences.getInstance();
    final normalizedPlanId = (planId ?? '').trim().isEmpty ? null : planId!.trim();
    isSubscribed.value = isActive;
    activePlanId.value = normalizedPlanId;
    await p.setBool(_subscribedKey, isActive);
    if (normalizedPlanId != null) {
      await p.setString(_activePlanKey, normalizedPlanId);
    } else {
      await p.remove(_activePlanKey);
    }
    if (syncBackend) {
      unawaited(
        _syncSubscriptionToBackend(
          normalizedPlanId,
          isActive,
          source: source,
        ),
      );
    }
    debugPrint(
      'Subscription state updated: active=$isActive plan=$normalizedPlanId source=$source',
    );
  }

  static void _logMissingExpectedPackages(List<Package> packages) {
    final hasWeekly = packages.any(
      (p) =>
          p.packageType == PackageType.weekly ||
          p.identifier.toLowerCase().contains('weekly'),
    );
    final hasMonthly = packages.any(
      (p) =>
          p.packageType == PackageType.monthly ||
          p.identifier.toLowerCase().contains('monthly'),
    );
    final hasYearly = packages.any(
      (p) =>
          p.packageType == PackageType.annual ||
          p.identifier.toLowerCase().contains('yearly') ||
          p.identifier.toLowerCase().contains('annual'),
    );
    final missing = <String>[
      if (!hasWeekly) 'weekly',
      if (!hasMonthly) 'monthly',
      if (!hasYearly) 'yearly',
    ];
    if (missing.isNotEmpty) {
      debugPrint(
        'RevenueCat offerings missing expected package(s): ${missing.join(', ')}',
      );
    }
  }

  static String _platformRevenueCatApiKey() {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _appleApiKey;
      case TargetPlatform.android:
        return _googleApiKey;
      default:
        return '';
    }
  }

  static Future<String> _resolveRevenueCatAppUserId(
    SharedPreferences prefs,
  ) async {
    final userId = await DvAuthService.getUserId(prefs: prefs);
    if (userId != null && userId.isNotEmpty) return userId;
    final existingAnon = prefs.getString(_rcAnonUserIdKey);
    if (existingAnon != null && existingAnon.isNotEmpty) return existingAnon;
    final generated = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(_rcAnonUserIdKey, generated);
    return generated;
  }

  static Future<void> _syncSubscriptionToBackend(
    String? planId,
    bool active, {
    String? source,
  }) async {
    try {
      await DvAuthService.putUserSettings(
        subscriptionPlanId: planId,
        subscriptionActive: active,
        subscriptionSource: source ?? 'revenuecat',
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
    if (subscriptionActive) {
      await p.remove(_legacyGraceUntilMsKey);
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
        await _setSubscriptionState(
          isActive: true,
          planId: planId,
          source: 'gift_code',
        );
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
