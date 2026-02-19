import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/google_drive_backup_service.dart';
import '../dashboard_screen.dart';

const _onboardingCompletedKey = 'onboarding_completed_v1';

/// Check if onboarding has been completed.
Future<bool> isOnboardingCompleted({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  return p.getBool(_onboardingCompletedKey) ?? false;
}

/// Mark onboarding as completed.
Future<void> markOnboardingCompleted({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  await p.setBool(_onboardingCompletedKey, true);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _linkingGoogle = false;

  static const _slides = [
    _OnboardingSlide(
      icon: Icons.image_outlined,
      title: 'A Goal Operating System',
      body:
          'This isn\u2019t a standard vision board. Create visual boards '
          '(Goal Canvas or Grid) and turn them into a system you can '
          'execute every day.',
    ),
    _OnboardingSlide(
      icon: Icons.check_circle_outline,
      title: 'Attach Habits + Todo to goals',
      body:
          'Link actionable Habits and Todo items directly to your visuals, '
          'so each goal becomes trackable and measurable\u2014not just '
          'inspirational.',
    ),
    _OnboardingSlide(
      icon: Icons.mood_outlined,
      title: 'Daily tracking + mood',
      body:
          'Track completions with feedback and see your daily mood over '
          'time. Stay consistent, reflect, and improve.',
    ),
    _OnboardingSlide(
      icon: Icons.cloud_outlined,
      title: 'Keep Your Data Safe',
      body:
          'Link your Google account to back up your boards, journal, '
          'habits, and more to your personal Google Drive\u2014encrypted '
          'and private.',
      isBackupSlide: true,
    ),
  ];

  bool get _isLastPage => _currentPage >= _slides.length - 1;
  bool get _isBackupSlide => _slides[_currentPage].isBackupSlide;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_isLastPage) {
      await _finishOnboarding();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _linkGoogle() async {
    setState(() => _linkingGoogle = true);
    try {
      final ok = await GoogleDriveBackupService.linkGoogleAccount();
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Drive linked successfully!')),
        );
        await _finishOnboarding();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in was cancelled.')),
        );
      }
    } finally {
      if (mounted) setState(() => _linkingGoogle = false);
    }
  }

  Future<void> _finishOnboarding() async {
    await markOnboardingCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) =>
                    _OnboardingSlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: active ? 18 : 8,
                        decoration: BoxDecoration(
                          color: active
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (_isBackupSlide) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _linkingGoogle ? null : _linkGoogle,
                        icon: _linkingGoogle
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.link),
                        label: const Text('Link Google Account'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _linkingGoogle ? null : _finishOnboarding,
                        child: const Text('Skip for now'),
                      ),
                    ),
                  ] else
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _next,
                        child: Text(_isLastPage ? 'Get Started' : 'Next'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String body;
  final bool isBackupSlide;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
    this.isBackupSlide = false,
  });
}

class _OnboardingSlideView extends StatelessWidget {
  final _OnboardingSlide slide;

  const _OnboardingSlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withAlpha(153),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.primaryContainer),
              ),
              child: Icon(slide.icon,
                  size: 44, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
