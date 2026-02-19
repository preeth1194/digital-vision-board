import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedIndex = 3; // Default to 1-year (best value)
  bool _purchasing = false;

  final List<SubscriptionPlan> _plans = SubscriptionService.plans;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Go Premium'),
        backgroundColor: colorScheme.surface,
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enjoy your ad-free experience and all premium features.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
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
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // Hero section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              colorScheme.secondary,
                              colorScheme.primary,
                            ]
                          : [
                              colorScheme.primary,
                              colorScheme.primaryContainer,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: colorScheme.onPrimary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Unlock Premium',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Remove all ads and unlock unlimited habits',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Benefits
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                _BenefitRow(
                  icon: Icons.block_rounded,
                  text: 'No ads ever',
                ),
                const SizedBox(height: 12),
                _BenefitRow(
                  icon: Icons.all_inclusive_rounded,
                  text: 'Unlimited habits',
                ),
                const SizedBox(height: 12),
                _BenefitRow(
                  icon: Icons.star_rounded,
                  text: 'Support development',
                ),
              ],
            ),
          ),
        ),

        // Plan cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final plan = _plans[index];
                final isSelected = _selectedIndex == index;
                return _PlanCard(
                  plan: plan,
                  isSelected: isSelected,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () => setState(() => _selectedIndex = index),
                );
              },
              childCount: _plans.length,
            ),
          ),
        ),

        // Subscribe button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: FilledButton(
              onPressed: _purchasing ? null : _onSubscribe,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: _purchasing
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onSecondary,
                      ),
                    )
                  : Text(
                      'Subscribe — ${SubscriptionService.priceForPlan(_plans[_selectedIndex])}'),
            ),
          ),
        ),

        // Restore purchases
        SliverToBoxAdapter(
          child: Center(
            child: TextButton(
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
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),

        // Legal text
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 4, 32, 40),
            child: Text(
              'Payment will be charged to your App Store or Google Play account. '
              'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. '
              'Manage subscriptions in your device settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.35
                        : 0.7),
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onSubscribe() async {
    final plan = _plans[_selectedIndex];
    setState(() => _purchasing = true);

    try {
      final ok = await SubscriptionService.buyPlan(plan.productId);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Subscription not available. Make sure you are signed in to your store account.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }
}

// ── Benefit row ──────────────────────────────────────────────────────

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.secondary.withValues(alpha: isDark ? 0.25 : 0.1),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark
                ? colorScheme.primaryContainer
                : colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ── Plan card ────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final bool isDark;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.isDark,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final storePrice = SubscriptionService.priceForPlan(plan);
    final hasSavings = plan.savings != null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? colorScheme.secondary.withValues(alpha: 0.2)
                  : colorScheme.primaryContainer.withValues(alpha: 0.15))
              : (isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? colorScheme.secondary
                : (isDark
                    ? colorScheme.outlineVariant.withValues(alpha: 0.3)
                    : colorScheme.outlineVariant.withValues(alpha: 0.15)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.secondary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colorScheme.secondary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.secondary
                      : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded,
                      size: 14, color: colorScheme.onSecondary)
                  : null,
            ),
            const SizedBox(width: 16),
            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (hasSavings) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary
                                .withValues(alpha: isDark ? 0.3 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            plan.savings!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? colorScheme.primaryContainer
                                  : colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Price
            Text(
              storePrice,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (isDark
                        ? colorScheme.primaryContainer
                        : colorScheme.secondary)
                    : colorScheme.onSurfaceVariant.withValues(
                        alpha: isDark ? 0.7 : 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
