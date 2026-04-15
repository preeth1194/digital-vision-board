import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../services/dv_auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import '../../widgets/layout/morning_garden_scaffold.dart';
import '../auth/auth_gateway_screen.dart';
import '../dashboard_screen.dart';
import '../legal_consent_screen.dart';
import '../privacy_policy_screen.dart';
import '../terms_and_conditions_screen.dart';
import 'onboarding_screen.dart';
import 'steps/step_terms.dart';

/// First-launch gate: start full onboarding or sign in with Google (returning users).
class InstallWelcomeScreen extends StatefulWidget {
  const InstallWelcomeScreen({super.key});

  @override
  State<InstallWelcomeScreen> createState() => _InstallWelcomeScreenState();
}

class _InstallWelcomeScreenState extends State<InstallWelcomeScreen> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;
  bool _authNavigating = false;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = _openTerms;
    _privacyTap = TapGestureRecognizer()..onTap = _openPrivacy;
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _openTerms() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _onGetStarted() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  Future<void> _onHaveAccount() async {
    if (_authNavigating) return;
    setState(() => _authNavigating = true);
    try {
      final termsDone = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (termsContext) => Scaffold(
            backgroundColor: AppColors.sproutGreen,
            body: StepTerms(
              onNext: () => Navigator.of(termsContext).pop(true),
              onBack: () => Navigator.of(termsContext).pop(false),
            ),
          ),
        ),
      );
      if (!mounted || termsDone != true) return;

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const AuthGatewayScreen(googleOnly: true),
        ),
      );
      if (!mounted) return;
      if (result == true) {
        await DvAuthService.markOnboardingCompleted();
        if (!mounted) return;
        final legalOk = await DvAuthService.isLegalConsentAccepted();
        if (!mounted) return;
        final next = legalOk
            ? const DashboardScreen()
            : const LegalConsentScreen();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => next),
        );
      }
    } finally {
      if (mounted) setState(() => _authNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return MorningGardenScaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  _BrandHero(colorScheme: colorScheme, isDark: isDark),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Hi there,',
                    textAlign: TextAlign.left,
                    style: AppTypography.welcomeGreeting(context).copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Welcome to\nHabit Seeding',
                    textAlign: TextAlign.left,
                    style: AppTypography.welcomeTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Plant small habits and watch your vision grow — a little each day.',
                    textAlign: TextAlign.left,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Semantics(
                    label: "Let's get started",
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _onGetStarted,
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusInput,
                            ),
                          ),
                        ),
                        child: Text(
                          "Let's get started",
                          style: AppTypography.button(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    label: 'I already have an account',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _authNavigating ? null : _onHaveAccount,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onSurface,
                          side: BorderSide(color: colorScheme.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusInput,
                            ),
                          ),
                        ),
                        child: _authNavigating
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                            : Text(
                                'I already have an account',
                                style: AppTypography.button(context).copyWith(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      style: AppTypography.caption(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(
                          text: 'By continuing, you agree to our ',
                        ),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _termsTap,
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _privacyTap,
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero({
    required this.colorScheme,
    required this.isDark,
  });

  static const String _logoAsset = 'assets/icon/app_icon.png';

  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mist = isDark ? colorScheme.surface : AppColors.mistBackground;
    const double logoDiameter = 120;
    // Decorative star fill sampled from AppColors.seedGold (icon, not text).
    final starFill = AppColors.seedGold.withValues(alpha: 0.85);

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 48,
            top: 24,
            child: Icon(
              Icons.star_rounded,
              size: 28,
              color: starFill,
            ),
          ),
          Positioned(
            left: 40,
            bottom: 36,
            child: Icon(
              Icons.auto_awesome,
              size: 22,
              color: AppColors.lavenderDew.withValues(alpha: 0.7),
            ),
          ),
          Container(
            width: 152,
            height: 152,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sageContainer.withValues(alpha: isDark ? 0.25 : 0.65),
              boxShadow: [
                BoxShadow(
                  color: AppColors.forestDeep.withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Habit Seeding app logo',
            image: true,
            child: Container(
              width: logoDiameter,
              height: logoDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mist,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.forestDeep.withValues(alpha: isDark ? 0.15 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  _logoAsset,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.eco_rounded,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
