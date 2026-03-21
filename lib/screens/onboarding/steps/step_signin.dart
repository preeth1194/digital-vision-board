import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';
import '../../auth/auth_gateway_screen.dart';

/// Final onboarding step — delegates sign-in to [AuthGatewayScreen].
/// When the user completes auth (Google or Guest), [AuthGatewayScreen] pops
/// with `true` and we call [onComplete] to finish onboarding.
class StepSignIn extends StatefulWidget {
  final VoidCallback onComplete;

  const StepSignIn({super.key, required this.onComplete});

  @override
  State<StepSignIn> createState() => _StepSignInState();
}

class _StepSignInState extends State<StepSignIn> {
  bool _loading = false;

  Future<void> _openAuth() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AuthGatewayScreen()),
      );
      if (result == true && mounted) {
        widget.onComplete();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mistBackground,
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
              Text(
                'ALMOST THERE',
                style: AppTypography.caption(context).copyWith(
                  color: AppColors.forestDeep.withOpacity(0.4),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Save your\njourney.',
                style: AppTypography.heading1(context).copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forestDeep,
                  height: 1.15,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sign in to sync across devices and\nnever lose your progress.',
                style: AppTypography.body(context).copyWith(
                  color: AppColors.forestDeep.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              // Illustration / icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.sproutGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.eco_outlined,
                    size: 40,
                    color: AppColors.sproutGreen,
                  ),
                ),
              ),
              const Spacer(),
              // Sign in / Guest CTA — opens AuthGatewayScreen
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _openAuth,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sproutGreen,
                    disabledBackgroundColor:
                        AppColors.sproutGreen.withOpacity(0.4),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusInput),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Sign in / Continue as Guest',
                          style: AppTypography.button(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  'Guest sessions last 10 days · Sign in anytime from Settings',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(context).copyWith(
                    color: AppColors.forestDeep.withOpacity(0.35),
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
