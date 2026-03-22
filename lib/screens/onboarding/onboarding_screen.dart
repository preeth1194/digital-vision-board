import 'package:flutter/material.dart';

import '../../services/dv_auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../dashboard_screen.dart';
import 'onboarding_first_habit_draft.dart';
import 'steps/step_first_habit.dart';
import 'steps/step_first_habit_photos.dart';
import 'steps/step_first_habit_routine.dart';
import 'steps/step_profile_setup.dart';
import 'steps/step_signin.dart';
import 'steps/step_terms.dart';

class OnboardingScreen extends StatefulWidget {
  /// When true, finishing pops without re-marking onboarding (e.g. internal replay entry points).
  final bool replayMode;

  const OnboardingScreen({super.key, this.replayMode = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final OnboardingFirstHabitDraft _habitDraft = OnboardingFirstHabitDraft();
  int _currentPage = 0;
  static const int _totalPages = 6;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  VoidCallback? _backForPage(int pageIndex) {
    if (pageIndex > 0) return _previousPage;
    if (widget.replayMode) {
      return () {
        if (!mounted) return;
        Navigator.of(context).pop();
      };
    }
    return null;
  }

  void _notifyHabitDraft() => setState(() {});

  Future<void> _completeOnboarding() async {
    if (!widget.replayMode) {
      await DvAuthService.markOnboardingCompleted();
    }
    if (!mounted) return;
    if (widget.replayMode) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
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
              StepProfileSetup(onNext: _nextPage, onBack: _backForPage(0)),
              StepFirstHabit(
                draft: _habitDraft,
                notifyParent: _notifyHabitDraft,
                onNext: _nextPage,
                onBack: _backForPage(1),
              ),
              StepFirstHabitRoutine(
                draft: _habitDraft,
                notifyParent: _notifyHabitDraft,
                onNext: _nextPage,
                onBack: _backForPage(2),
              ),
              StepFirstHabitPhotos(
                draft: _habitDraft,
                notifyParent: _notifyHabitDraft,
                onNext: _nextPage,
                onBack: _backForPage(3),
              ),
              StepTerms(onNext: _nextPage, onBack: _backForPage(4)),
              StepSignIn(
                onComplete: _completeOnboarding,
                onBack: _backForPage(5),
              ),
            ],
          ),
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
    final isDarkStep = current >= 1 && current <= 3;

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
                ? AppColors.cloudWhite.withValues(alpha: 0.2)
                : AppColors.forestDeep.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              isDarkStep ? AppColors.seedGold : AppColors.sproutGreen,
            ),
          ),
        ),
      ),
    );
  }
}
