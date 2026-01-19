import 'dart:async';

import 'package:flutter/material.dart';

import '../dashboard_screen.dart';

final class OnboardingCarouselScreen extends StatefulWidget {
  const OnboardingCarouselScreen({super.key, this.onFinished});

  /// Called when the user completes the last slide ("Get Started").
  ///
  /// If omitted, the screen navigates to `DashboardScreen` via pushReplacement.
  final FutureOr<void> Function(BuildContext context)? onFinished;

  @override
  State<OnboardingCarouselScreen> createState() => _OnboardingCarouselScreenState();
}

final class _OnboardingCarouselScreenState extends State<OnboardingCarouselScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  late final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.image_outlined,
      title: 'A Goal Operating System',
      body:
          'This isn’t a standard vision board. Create visual boards (Freeform, Grid, or Physical photo overlays) and turn them into a system you can execute every day.',
    ),
    _OnboardingSlide(
      icon: Icons.check_circle_outline,
      title: 'Attach Habits + Todo to goals',
      body:
          'Link actionable Habits and Todo items directly to your visuals, so each goal becomes trackable and measurable—not just inspirational.',
    ),
    _OnboardingSlide(
      icon: Icons.mood_outlined,
      title: 'Daily tracking + mood',
      body:
          'Track completions with feedback and see your daily mood over time. Stay consistent, reflect, and improve.',
    ),
  ];

  bool get _isLastPage => _currentPage >= _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_isLastPage) {
      if (!mounted) return;
      if (widget.onFinished != null) {
        await widget.onFinished!(context);
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _OnboardingSlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_slides.length, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: active ? 18 : 8,
                            decoration: BoxDecoration(
                              color: active ? scheme.primary : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_isLastPage ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: scheme.surface,
    );
  }
}

final class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String body;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
  });
}

final class _OnboardingSlideView extends StatelessWidget {
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
                color: scheme.primaryContainer.withAlpha(153), // ~0.6 * 255
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.primaryContainer),
              ),
              child: Icon(slide.icon, size: 44, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

