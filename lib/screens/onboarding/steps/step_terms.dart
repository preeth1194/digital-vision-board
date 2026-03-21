import 'package:flutter/material.dart';

import '../../../services/dv_auth_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../../privacy_policy_screen.dart';
import '../../terms_and_conditions_screen.dart';
import '_step_header.dart';

class StepTerms extends StatefulWidget {
  final VoidCallback onNext;

  const StepTerms({super.key, required this.onNext});

  @override
  State<StepTerms> createState() => _StepTermsState();
}

class _StepTermsState extends State<StepTerms> {
  bool _agreed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    DvAuthService.isLegalConsentAccepted().then((accepted) {
      if (accepted && mounted) setState(() => _agreed = true);
    });
  }

  Future<void> _acceptAndContinue() async {
    if (!_agreed || _saving) return;
    setState(() => _saving = true);
    await DvAuthService.markLegalConsentAccepted();
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onNext();
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

  @override
  Widget build(BuildContext context) {
    final white50 = Colors.white.withValues(alpha: 0.5);
    final white60 = Colors.white.withValues(alpha: 0.6);
    final white70 = Colors.white.withValues(alpha: 0.7);

    return Container(
      color: AppColors.sproutGreen,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              StepHeader(
                overline: 'BEFORE WE START',
                title: 'One last\nthing.',
                subtitle: 'Please read and agree to continue.',
                titleColor: Colors.white,
                subtitleColor: white60,
                overlineColor: white50,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusCard),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      'Welcome to Habit Seeding. By using this app you agree to our '
                      'Terms of Service and Privacy Policy.\n\n'
                      'We collect the information you provide to personalise your '
                      'experience. Your data is encrypted and never sold to third '
                      'parties.\n\n'
                      'You may delete your account at any time from Settings. '
                      'For support, contact us at support@habitseeding.app.\n\n'
                      'By tapping "Accept & Continue" you confirm you are 13 years '
                      'of age or older and agree to be bound by these terms.',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _openTerms,
                    child: Text(
                      'Full Terms',
                      style: AppTypography.caption(context).copyWith(
                        color: white70,
                        decoration: TextDecoration.underline,
                        decorationColor: white50,
                      ),
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: AppTypography.caption(context).copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openPrivacy,
                    child: Text(
                      'Privacy Policy',
                      style: AppTypography.caption(context).copyWith(
                        color: white70,
                        decoration: TextDecoration.underline,
                        decorationColor: white50,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: AppSpacing.lg,
                      height: AppSpacing.lg,
                      decoration: BoxDecoration(
                        color: _agreed ? Colors.white : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusBadge),
                        border: Border.all(
                          color: Colors.white
                              .withValues(alpha: _agreed ? 1 : 0.5),
                          width: 2,
                        ),
                      ),
                      child: _agreed
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.sproutGreen,
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'I agree to the Terms of Service and Privacy Policy',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_agreed && !_saving) ? _acceptAndContinue : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.3),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusInput),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.sproutGreen,
                          ),
                        )
                      : Text(
                          'Accept & Continue',
                          style: AppTypography.button(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.sproutGreen,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
