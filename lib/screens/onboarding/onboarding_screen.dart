import 'package:flutter/material.dart';

import '../../services/dv_auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../dashboard_screen.dart';
import 'steps/step_body_activity.dart';
import 'steps/step_features.dart';
import 'steps/step_gender_dob.dart';
import 'steps/step_photo.dart';
import 'steps/step_signin.dart';
import 'steps/step_terms.dart';
import 'steps/step_welcome.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 7;

  // Name is passed to StepPhoto for personalised title.
  // Other fields are saved to SharedPreferences directly by each step widget.
  String _name = '';

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    await DvAuthService.markOnboardingCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              StepWelcome(
                onNext: (name) {
                  setState(() => _name = name);
                  _nextPage();
                },
              ),
              StepPhoto(
                name: _name,
                onNext: (_) => _nextPage(),
              ),
              StepGenderDob(
                onNext: (gender, dob) => _nextPage(),
              ),
              StepBodyActivity(
                onNext: (heightCm, weightKg, activityLevel) => _nextPage(),
              ),
              StepFeatures(onNext: _nextPage),
              StepTerms(onNext: _nextPage),
              StepSignIn(onComplete: _completeOnboarding),
            ],
          ),
          // Thin animated progress bar overlaid at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _OnboardingProgressBar(
              current: _currentPage,
              total: _totalPages,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _OnboardingProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = (current + 1) / total;
    // Screen 5 (index 4) uses AppColors.cloudDark background — use gold accent
    final isDarkStep = current == 4;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: isDarkStep
                ? Colors.white.withValues(alpha:0.2)
                : AppColors.forestDeep.withValues(alpha:0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDarkStep ? AppColors.seedGold : AppColors.sproutGreen,
            ),
          ),
        ),
      ),
    );
  }
}
