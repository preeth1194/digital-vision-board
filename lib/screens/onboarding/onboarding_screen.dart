import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/dv_auth_service.dart';
import '../../services/google_sign_in_config.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import '../legal_consent_screen.dart';
import 'widgets/onboarding_profile_step.dart';

const _onboardingCompletedKey = 'onboarding_completed_v1';

Future<bool> isOnboardingCompleted({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  return p.getBool(_onboardingCompletedKey) ?? false;
}

Future<void> markOnboardingCompleted({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  await p.setBool(_onboardingCompletedKey, true);
}

// ---------------------------------------------------------------------------
// Slide model
// ---------------------------------------------------------------------------

enum _SlideType { welcome, tourFeature, profile, auth }

enum _MascotPose { wave, happy, point, thumbsUp }

class _OnboardingSlide {
  final _SlideType type;
  final IconData? icon;
  final String title;
  final String speechText;
  final _MascotPose pose;

  const _OnboardingSlide({
    required this.type,
    this.icon,
    required this.title,
    required this.speechText,
    required this.pose,
  });
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class OnboardingScreen extends StatefulWidget {
  final bool replayMode;

  const OnboardingScreen({super.key, this.replayMode = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  final GlobalKey<OnboardingProfileStepState> _profileStepKey =
      GlobalKey<OnboardingProfileStepState>();
  int _currentPage = 0;
  bool _loading = false;
  String? _error;

  /// Welcome, four tab-accurate tour slides, profile, auth.
  static const _slides = [
    _OnboardingSlide(
      type: _SlideType.welcome,
      title: 'Digital Vision Board',
      speechText:
          'Hi — I\'m Sprouty. This is your Morning Garden: a calm place to plant '
          'habits, tend your vision board, and watch small steps add up. '
          'Let me show you around.',
      pose: _MascotPose.wave,
    ),
    _OnboardingSlide(
      type: _SlideType.tourFeature,
      icon: Icons.home_rounded,
      title: 'Home',
      speechText:
          'Your dashboard is where the day starts: habits, water, puzzle progress, '
          'affirmations, and gentle glances at what matters — without the noise.',
      pose: _MascotPose.happy,
    ),
    _OnboardingSlide(
      type: _SlideType.tourFeature,
      icon: Icons.eco_outlined,
      title: 'Habits',
      speechText:
          'Seeds are your habits here. Check them in, build streaks, and keep '
          'routines that fit real life — structure that supports you, not pressure.',
      pose: _MascotPose.happy,
    ),
    _OnboardingSlide(
      type: _SlideType.tourFeature,
      icon: Icons.auto_awesome_mosaic_outlined,
      title: 'Presets',
      speechText:
          'Browse planner presets and templates — workouts, meals, skincare, and '
          'more — so you spend less time setting up and more time growing.',
      pose: _MascotPose.point,
    ),
    _OnboardingSlide(
      type: _SlideType.tourFeature,
      icon: Icons.menu_book_outlined,
      title: 'Journal',
      speechText:
          'Write in your journal and track mood when it feels right. Reflection '
          'lives alongside your habits in one garden.',
      pose: _MascotPose.happy,
    ),
    _OnboardingSlide(
      type: _SlideType.profile,
      title: 'Your profile',
      speechText: '',
      pose: _MascotPose.happy,
    ),
    _OnboardingSlide(
      type: _SlideType.auth,
      title: 'Ready to begin?',
      speechText:
          'Your garden is almost ready. Sign in to sync across devices, or '
          'continue as a guest — you can always connect later.',
      pose: _MascotPose.thumbsUp,
    ),
  ];

  bool get _isAuthSlide => _slides[_currentPage].type == _SlideType.auth;
  bool get _isProfileSlide => _slides[_currentPage].type == _SlideType.profile;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_currentPage >= _slides.length - 1) return;
    await _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _previous() async {
    if (_currentPage <= 0) return;
    await _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onProfileContinue() async {
    final s = _profileStepKey.currentState;
    if (s != null) await s.submitAndAdvance();
  }

  Future<void> _finishOnboarding() async {
    await markOnboardingCompleted();
    if (!mounted) return;
    if (widget.replayMode) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LegalConsentScreen()),
      );
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleSignIn = GoogleSignIn.instance;
      await initializeGoogleSignIn();
      final googleUser = await googleSignIn.authenticate();
      final auth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final email = userCred.user?.email;
      if (email != null && email.isNotEmpty) {
        await DvAuthService.setUserDisplayInfo(email: email);
      }
      final googleName = userCred.user?.displayName?.trim();
      if (googleName != null && googleName.isNotEmpty) {
        final existing = await DvAuthService.getDisplayName();
        if (existing == null || existing.isEmpty) {
          await DvAuthService.setProfileInfo(displayName: googleName);
        }
      }
      final idToken = await userCred.user?.getIdToken();
      if ((idToken ?? '').trim().isEmpty) {
        throw Exception('Could not get Firebase idToken.');
      }
      await DvAuthService.exchangeFirebaseIdTokenForDvToken(idToken!);
      await DvAuthService.syncLocalProfileToServer();
      await SubscriptionService.initialize();
      if (!mounted) return;
      await _finishOnboarding();
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      setState(() => _error = 'Google sign-in failed. Please try again.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await DvAuthService.continueAsGuest();
      await DvAuthService.syncLocalProfileToServer();
      await SubscriptionService.initialize();
      if (!mounted) return;
      await _finishOnboarding();
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = 'Could not continue as guest. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      decoration: AppColors.skyDecoration(isDark: isDark),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              if (widget.replayMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpacing.sm,
                      top: AppSpacing.xs,
                    ),
                    child: Semantics(
                      label: 'Skip onboarding replay',
                      button: true,
                      child: TextButton(
                        onPressed: _finishOnboarding,
                        child: Text(
                          'Skip',
                          style: AppTypography.button(context),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() {
                    _currentPage = i;
                    _error = null;
                  }),
                  itemBuilder: (context, i) {
                    final slide = _slides[i];
                    switch (slide.type) {
                      case _SlideType.welcome:
                        return _WelcomeSlideView(
                            key: ValueKey('slide_$i'), slide: slide);
                      case _SlideType.tourFeature:
                        return _TourFeatureSlideView(
                            key: ValueKey('slide_$i'), slide: slide);
                      case _SlideType.profile:
                        return OnboardingProfileStep(
                          key: _profileStepKey,
                          replayMode: widget.replayMode,
                          onSaved: _next,
                          onSkipWithoutSaving: _next,
                        );
                      case _SlideType.auth:
                        return _AuthSlideView(
                          key: ValueKey('slide_$i'),
                          slide: slide,
                          loading: _loading,
                          error: _error,
                          onGoogle: _continueWithGoogle,
                          onGuest: _continueAsGuest,
                          replayMode: widget.replayMode,
                          onSkip: _finishOnboarding,
                        );
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _currentPage;
                        return Semantics(
                          label: 'Page ${i + 1} of ${_slides.length}',
                          selected: active,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            height: AppSpacing.sm,
                            width: active ? 18 : AppSpacing.sm,
                            decoration: BoxDecoration(
                              color: active
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (!_isAuthSlide)
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _currentPage > 0
                                  ? Semantics(
                                      label: 'Back',
                                      button: true,
                                      child: TextButton(
                                        onPressed: _previous,
                                        child: Text(
                                          'Back',
                                          style:
                                              AppTypography.button(context)
                                                  .copyWith(
                                            color: scheme.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          Semantics(
                            label: _isProfileSlide
                                ? 'Save profile and continue'
                                : 'Next slide',
                            button: true,
                            child: FilledButton(
                              onPressed: _isProfileSlide
                                  ? _onProfileContinue
                                  : _next,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusInput,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Next',
                                style: AppTypography.button(context).copyWith(
                                  color: scheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mascot painter — sprouting seed character based on the app logo
// ---------------------------------------------------------------------------

class _SproutMascotPainter extends CustomPainter {
  final _MascotPose pose;

  _SproutMascotPainter({required this.pose});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final f = size.width / 100;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + 34 * f),
        width: 44 * f,
        height: 10 * f,
      ),
      Paint()..color = Colors.black.withAlpha(30),
    );

    // Seed body — outer shell
    canvas.save();
    canvas.translate(cx, cy + 10 * f);
    canvas.rotate(-0.3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 52 * f, height: 44 * f),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.honeyText, AppColors.forestDeep],
        ).createShader(Rect.fromCenter(
            center: Offset.zero, width: 52 * f, height: 44 * f)),
    );
    canvas.restore();

    // Seed inner — golden face area
    canvas.save();
    canvas.translate(cx + 2 * f, cy + 8 * f);
    canvas.rotate(-0.2);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 40 * f, height: 34 * f),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.seedGold, AppColors.honeyText],
        ).createShader(Rect.fromCenter(
            center: Offset.zero, width: 40 * f, height: 34 * f)),
    );
    canvas.restore();

    // Stem
    final stemPath = Path()
      ..moveTo(cx + 2 * f, cy - 6 * f)
      ..cubicTo(cx + 4 * f, cy - 18 * f, cx - 4 * f, cy - 26 * f,
          cx - 2 * f, cy - 34 * f);
    canvas.drawPath(
      stemPath,
      Paint()
        ..color = AppColors.sproutGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * f
        ..strokeCap = StrokeCap.round,
    );

    _drawLeaf(canvas, cx - 2 * f, cy - 34 * f, -0.7, 18 * f, 10 * f, f);
    _drawLeaf(canvas, cx - 2 * f, cy - 34 * f, 0.5, 18 * f, 10 * f, f);

    // Eyes
    final eyeY = cy + 6 * f;
    final eyeLX = cx - 4 * f;
    final eyeRX = cx + 8 * f;
    final eyeR = 4.5 * f;
    final pupilR = 2.5 * f;

    canvas.drawCircle(Offset(eyeLX, eyeY), eyeR, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(eyeRX, eyeY), eyeR, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(eyeLX + 0.5 * f, eyeY), pupilR, Paint()..color = AppColors.forestDeep);
    canvas.drawCircle(
        Offset(eyeRX + 0.5 * f, eyeY), pupilR, Paint()..color = AppColors.forestDeep);

    final hl = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(eyeLX - 0.8 * f, eyeY - 1.2 * f), 1.2 * f, hl);
    canvas.drawCircle(Offset(eyeRX - 0.8 * f, eyeY - 1.2 * f), 1.2 * f, hl);

    // Smile
    canvas.drawPath(
      Path()
        ..moveTo(cx - 2 * f, cy + 14 * f)
        ..quadraticBezierTo(
            cx + 2 * f, cy + 19 * f, cx + 6 * f, cy + 14 * f),
      Paint()
        ..color = AppColors.forestDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * f
        ..strokeCap = StrokeCap.round,
    );

    _drawArms(canvas, cx, cy, f);
  }

  void _drawLeaf(Canvas canvas, double x, double y, double angle,
      double length, double width, double f) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(width * 0.6, -width * 0.5, length, -width * 0.15)
        ..quadraticBezierTo(width * 0.6, width * 0.3, 0, 0),
      Paint()..color = AppColors.sproutGreen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(
            width * 0.5, -width * 0.1, length * 0.85, -width * 0.08),
      Paint()
        ..color = AppColors.springWater
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * f
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawArms(Canvas canvas, double cx, double cy, double f) {
    final p = Paint()
      ..color = AppColors.forestDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * f
      ..strokeCap = StrokeCap.round;

    // Left arm — always relaxed at side
    canvas.drawPath(
      Path()
        ..moveTo(cx - 22 * f, cy + 10 * f)
        ..quadraticBezierTo(
            cx - 30 * f, cy + 18 * f, cx - 28 * f, cy + 24 * f),
      p,
    );

    switch (pose) {
      case _MascotPose.wave:
        canvas.drawPath(
          Path()
            ..moveTo(cx + 22 * f, cy + 6 * f)
            ..quadraticBezierTo(
                cx + 32 * f, cy - 4 * f, cx + 30 * f, cy - 14 * f),
          p,
        );
        canvas.drawCircle(
            Offset(cx + 30 * f, cy - 14 * f), 2.5 * f,
            Paint()..color = AppColors.seedGold);

      case _MascotPose.happy:
        canvas.drawPath(
          Path()
            ..moveTo(cx + 22 * f, cy + 10 * f)
            ..quadraticBezierTo(
                cx + 30 * f, cy + 18 * f, cx + 28 * f, cy + 24 * f),
          p,
        );

      case _MascotPose.point:
        canvas.drawPath(
          Path()
            ..moveTo(cx + 22 * f, cy + 8 * f)
            ..quadraticBezierTo(
                cx + 34 * f, cy + 4 * f, cx + 38 * f, cy),
          p,
        );
        canvas.drawCircle(
            Offset(cx + 38 * f, cy), 2 * f, Paint()..color = AppColors.seedGold);

      case _MascotPose.thumbsUp:
        canvas.drawPath(
          Path()
            ..moveTo(cx + 22 * f, cy + 6 * f)
            ..quadraticBezierTo(
                cx + 30 * f, cy - 2 * f, cx + 28 * f, cy - 12 * f),
          p,
        );
        canvas.drawCircle(
            Offset(cx + 28 * f, cy - 12 * f), 3 * f,
            Paint()..color = AppColors.seedGold);
        canvas.drawPath(
          Path()
            ..moveTo(cx + 28 * f, cy - 12 * f)
            ..lineTo(cx + 27 * f, cy - 18 * f),
          Paint()
            ..color = AppColors.seedGold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * f
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  @override
  bool shouldRepaint(_SproutMascotPainter old) => old.pose != pose;
}

class _SproutMascot extends StatelessWidget {
  final double size;
  final _MascotPose pose;

  const _SproutMascot({required this.size, required this.pose});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SproutMascotPainter(pose: pose),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated speech bubble — fades in, slides up, and subtly scales on entrance
// ---------------------------------------------------------------------------

class _AnimatedSpeechBubble extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration delay;

  const _AnimatedSpeechBubble({
    required this.text,
    this.style,
    this.delay = Duration.zero,
  });

  @override
  State<_AnimatedSpeechBubble> createState() => _AnimatedSpeechBubbleState();
}

class _AnimatedSpeechBubbleState extends State<_AnimatedSpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: _SpeechBubbleContent(text: widget.text, style: widget.style),
        ),
      ),
    );
  }
}

class _SpeechBubbleContent extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _SpeechBubbleContent({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusDialog),
            border: Border.all(color: scheme.outlineVariant, width: 1),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withAlpha(15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text,
            style: style ??
                AppTypography.body(context).copyWith(
                  color: scheme.onSurface,
                  height: 1.4,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg + 4),
          child: CustomPaint(
            size: const Size(16, 10),
            painter: _BubbleTailPainter(
              fillColor: scheme.surface,
              borderColor: scheme.outlineVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  _BubbleTailPainter({required this.fillColor, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      const Offset(-1, 0),
      Offset(size.width + 1, 0),
      Paint()
        ..color = fillColor
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor;
}

// ---------------------------------------------------------------------------
// Animated mascot — gentle bounce entrance
// ---------------------------------------------------------------------------

class _AnimatedMascot extends StatefulWidget {
  final double size;
  final _MascotPose pose;
  final Duration delay;

  const _AnimatedMascot({
    required this.size,
    required this.pose,
    this.delay = const Duration(milliseconds: 200),
  });

  @override
  State<_AnimatedMascot> createState() => _AnimatedMascotState();
}

class _AnimatedMascotState extends State<_AnimatedMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: _SproutMascot(size: widget.size, pose: widget.pose),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated image — fades in, slides up, and gently scales on entrance
// ---------------------------------------------------------------------------

class _AnimatedImage extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedImage({
    required this.child,
    this.delay = const Duration(milliseconds: 500),
  });

  @override
  State<_AnimatedImage> createState() => _AnimatedImageState();
}

class _AnimatedImageState extends State<_AnimatedImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide 1 — Welcome
// ---------------------------------------------------------------------------

class _WelcomeSlideView extends StatelessWidget {
  final _OnboardingSlide slide;

  const _WelcomeSlideView({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          const Spacer(flex: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              slide.title,
              textAlign: TextAlign.center,
              style: AppTypography.heading1(context),
            ),
          ),
          const SizedBox(height: 24),
          _AnimatedSpeechBubble(
            text: slide.speechText,
            delay: const Duration(milliseconds: 300),
          ),
          const SizedBox(height: 4),
          _AnimatedMascot(
            size: 120,
            pose: slide.pose,
            delay: const Duration(milliseconds: 100),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tour slide — tab-aligned feature intro (optional asset or icon card)
// ---------------------------------------------------------------------------

class _TourFeatureSlideView extends StatelessWidget {
  final _OnboardingSlide slide;

  const _TourFeatureSlideView({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final icon = slide.icon ?? Icons.eco_outlined;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          const Spacer(flex: 1),
          Semantics(
            header: true,
            child: Text(
              slide.title,
              textAlign: TextAlign.center,
              style: AppTypography.heading2(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AnimatedMascot(
                size: 56,
                pose: slide.pose,
                delay: const Duration(milliseconds: 100),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _AnimatedSpeechBubble(
                  text: slide.speechText,
                  delay: const Duration(milliseconds: 300),
                  style: AppTypography.bodySmall(context).copyWith(
                    color: scheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            flex: 5,
            child: _AnimatedImage(
              delay: const Duration(milliseconds: 500),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: AppColors.cloudDecoration(isDark: isDark),
                child: Icon(
                  icon,
                  size: 80,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth slide
// ---------------------------------------------------------------------------

class _AuthSlideView extends StatelessWidget {
  final _OnboardingSlide slide;
  final bool loading;
  final String? error;
  final VoidCallback onGoogle;
  final VoidCallback onGuest;
  final bool replayMode;
  final VoidCallback onSkip;

  const _AuthSlideView({
    super.key,
    required this.slide,
    required this.loading,
    required this.error,
    required this.onGoogle,
    required this.onGuest,
    required this.replayMode,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          const Spacer(flex: 3),
          _AnimatedMascot(
            size: 100,
            pose: slide.pose,
            delay: const Duration(milliseconds: 100),
          ),
          const SizedBox(height: 8),
          _AnimatedSpeechBubble(
            text: slide.speechText,
            delay: const Duration(milliseconds: 300),
          ),
          const SizedBox(height: 24),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.heading2(context),
          ),
          const SizedBox(height: 20),
          if ((error ?? '').trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                error!,
                style: AppTypography.error(context).copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: Semantics(
              label: 'Continue with Google',
              button: true,
              child: FilledButton.icon(
                onPressed: loading ? null : onGoogle,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  ),
                ),
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.g_mobiledata),
                label: Text(
                  'Continue with Google',
                  style: AppTypography.button(context).copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: Semantics(
              label: 'Continue as guest, expires after ten days',
              button: true,
              child: FilledButton(
                onPressed: loading ? null : onGuest,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
                  ),
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continue as Guest',
                      style: AppTypography.button(context).copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      'Expires after 10 days',
                      style: AppTypography.caption(context).copyWith(
                        color:
                            scheme.onSecondaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (replayMode) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: 'Skip sign-in',
              button: true,
              child: TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip',
                  style: AppTypography.button(context),
                ),
              ),
            ),
          ],
          const Spacer(flex: 4),
        ],
      ),
    );
  }
}
