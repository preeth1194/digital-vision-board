import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../services/subscription_service.dart';
import '../utils/app_typography.dart';
import '../widgets/layout/morning_garden_scaffold.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedIndex = 3; // Default to 1-year (best value)
  List<SubscriptionPlan> get _plans => SubscriptionService.plans;

  @override
  void initState() {
    super.initState();
    SubscriptionService.availablePlans.addListener(_onPlansChanged);
  }

  @override
  void dispose() {
    SubscriptionService.availablePlans.removeListener(_onPlansChanged);
    super.dispose();
  }

  void _onPlansChanged() {
    if (!mounted) return;
    final plans = _plans;
    if (plans.isEmpty) return;
    if (_selectedIndex >= plans.length) {
      setState(() => _selectedIndex = plans.length - 1);
      return;
    }
    setState(() {});
  }

  Future<PaywallResult?> _presentHostedPaywall() async {
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(
        SubscriptionService.entitlementId,
        displayCloseButton: true,
      );
      await SubscriptionService.refreshCustomerInfo(
        source: 'revenuecat_hosted_paywall',
      );
      if (!mounted) return null;
      switch (result) {
        case PaywallResult.purchased:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription activated. Welcome to Pro!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return result;
        case PaywallResult.restored:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return result;
        case PaywallResult.error:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open paywall. You can use plan picker.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return result;
        case PaywallResult.cancelled:
        case PaywallResult.notPresented:
          return result;
      }
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hosted paywall unavailable. Use plan picker below.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }
  }

  Future<void> _openCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter(
        onRestoreCompleted: (info) async {
          await SubscriptionService.refreshCustomerInfo(
            source: 'revenuecat_customer_center_restore',
          );
        },
      );
      await SubscriptionService.refreshCustomerInfo(
        source: 'revenuecat_customer_center_close',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer Center unavailable. Try Restore Purchases.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return MorningGardenScaffold(
      appBar: AppBar(
        title: Text(
          'Habit Seeding',
          style: AppTypography.heading3(context),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: SubscriptionService.isSubscribed,
        builder: (context, subscribed, _) {
          if (subscribed) {
            return _buildActiveSubscription(isDark, colorScheme);
          }
          return _buildSubscriptionPicker(isDark, colorScheme);
        },
      ),
    );
  }

  // ── Active subscription state ──────────────────────────────────────

  Widget _buildActiveSubscription(bool isDark, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.secondary,
                    colorScheme.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: colorScheme.onPrimary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You\'re Premium!',
              style: AppTypography.heading1(context).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enjoy your ad-free experience and all premium features.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(context).copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _openCustomerCenter,
              icon: const Icon(Icons.manage_accounts_rounded),
              label: const Text('Manage Subscription'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await SubscriptionService.restorePurchases();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Purchases restored.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Restore Purchases'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Subscription picker ────────────────────────────────────────────

  Widget _buildSubscriptionPicker(bool isDark, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHigh
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium',
                      style: AppTypography.heading3(context).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No ads. Unlimited habits. Full access.',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!SubscriptionService.isRevenueCatConfigured)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.errorContainer.withValues(alpha: 0.45),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              SubscriptionService.configNotice.value ??
                  'RevenueCat is not configured for this build.',
              style: AppTypography.caption(context).copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        if (!SubscriptionService.isRevenueCatConfigured)
          const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: SubscriptionService.isRevenueCatConfigured
              ? _presentHostedPaywall
              : null,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Continue to paywall'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openCustomerCenter,
          icon: const Icon(Icons.manage_accounts_rounded),
          label: const Text('Manage subscription'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () async {
            await SubscriptionService.restorePurchases();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Purchases restored.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Text(
            'Restore Purchases',
            style: AppTypography.secondary(context),
          ),
        ),
      ],
    );
  }

}
