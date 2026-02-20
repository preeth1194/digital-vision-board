import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/dv_auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../dashboard_screen.dart';

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

enum _SlideType { welcome, imageFeature, cardControls, auth }

enum _MascotPose { wave, happy, point, thumbsUp }

class _OnboardingSlide {
  final _SlideType type;
  final IconData? icon;
  final String title;
  final String speechText;
  final _MascotPose pose;
  final String? imagePath;

  const _OnboardingSlide({
    required this.type,
    this.icon,
    required this.title,
    required this.speechText,
    required this.pose,
    this.imagePath,
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
  int _currentPage = 0;
  bool _loading = false;
  String? _error;

  static const _slides = [
    _OnboardingSlide(
      type: _SlideType.welcome,
      title: 'Habit Seeding',
      speechText:
          'Hi! I\u2019m Sprouty. I\u2019m here to help you turn your biggest '
          'dreams into daily rituals. Let\u2019s take a look around your new '
          'growth space!',
      pose: _MascotPose.wave,
    ),
    _OnboardingSlide(
      type: _SlideType.imageFeature,
      title: 'Insights & Rewards',
      speechText:
          'Track your streaks, check in on your mood, earn coins for every '
          'habit, and watch your progress grow\u2014all at a glance.',
      imagePath: 'assets/onboarding/insights_rewards.png',
      pose: _MascotPose.happy,
    ),
    _OnboardingSlide(
      type: _SlideType.imageFeature,
      title: 'And So Much More',
      speechText:
          'There\u2019s so much more to explore\u2014from timed routines and '
          'journaling to challenges and games that keep you inspired every day.',
      imagePath: 'assets/onboarding/so_much_more.png',
      pose: _MascotPose.happy,
    ),
    _OnboardingSlide(
      type: _SlideType.cardControls,
      icon: Icons.touch_app_outlined,
      title: 'Card Controls',
      speechText:
          'Simple moves, big results. Here\u2019s how to manage your daily '
          'habits at a glance:',
      pose: _MascotPose.point,
    ),
    _OnboardingSlide(
      type: _SlideType.auth,
      title: 'Ready to Begin?',
      speechText:
          'Your journey starts here. Everything is ready for you\u2014how '
          'would you like to begin?',
      pose: _MascotPose.thumbsUp,
    ),
  ];

  bool get _isAuthSlide => _slides[_currentPage].type == _SlideType.auth;

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

  Future<void> _finishOnboarding() async {
    await markOnboardingCompleted();
    if (!mounted) return;
    if (widget.replayMode) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
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
      await googleSignIn.initialize();
      final googleUser = await googleSignIn.authenticate();
      final auth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final email = userCred.user?.email;
      if (email != null && email.isNotEmpty) {
        await DvAuthService.setUserDisplayInfo(email: email);
      }
      final idToken = await userCred.user?.getIdToken();
      if ((idToken ?? '').trim().isEmpty) {
        throw Exception('Could not get Firebase idToken.');
      }
      await DvAuthService.exchangeFirebaseIdTokenForDvToken(idToken!);
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
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: TextButton(
                      onPressed: _finishOnboarding,
                      child: const Text('Skip'),
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
                      case _SlideType.imageFeature:
                        return _ImageFeatureSlideView(
                            key: ValueKey('slide_$i'), slide: slide);
                      case _SlideType.cardControls:
                        return _CardControlsSlideView(
                            key: ValueKey('slide_$i'), slide: slide);
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
                    if (!_isAuthSlide)
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _next,
                          child: const Text('Next'),
                        ),
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

  static const _shellDark = Color(0xFF6D4C2A);
  static const _shellMid = Color(0xFF8B5E3C);
  static const _innerGold = Color(0xFFD4A054);
  static const _stemGreen = Color(0xFF4CAF50);
  static const _leafBright = Color(0xFF66BB6A);
  static const _leafVein = Color(0xFF2E7D32);
  static const _pupil = Color(0xFF333333);
  static const _smileBrown = Color(0xFF6D4C2A);

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
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_shellMid, _shellDark],
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
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_innerGold, Color(0xFFC49340)],
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
        ..color = _stemGreen
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
        Offset(eyeLX + 0.5 * f, eyeY), pupilR, Paint()..color = _pupil);
    canvas.drawCircle(
        Offset(eyeRX + 0.5 * f, eyeY), pupilR, Paint()..color = _pupil);

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
        ..color = _smileBrown
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
      Paint()..color = _leafBright,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(
            width * 0.5, -width * 0.1, length * 0.85, -width * 0.08),
      Paint()
        ..color = _leafVein
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * f
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _drawArms(Canvas canvas, double cx, double cy, double f) {
    final p = Paint()
      ..color = _shellMid
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
            Paint()..color = _innerGold);

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
            Offset(cx + 38 * f, cy), 2 * f, Paint()..color = _innerGold);

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
            Paint()..color = _innerGold);
        canvas.drawPath(
          Path()
            ..moveTo(cx + 28 * f, cy - 12 * f)
            ..lineTo(cx + 27 * f, cy - 18 * f),
          Paint()
            ..color = _innerGold
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
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
          padding: const EdgeInsets.only(left: 28),
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
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.heading1(context),
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
// Slide 2 — Image feature (title + mascot speech + screenshot)
// ---------------------------------------------------------------------------

class _ImageFeatureSlideView extends StatelessWidget {
  final _OnboardingSlide slide;

  const _ImageFeatureSlideView({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        children: [
          const Spacer(flex: 1),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.heading2(context),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AnimatedMascot(
                size: 56,
                pose: slide.pose,
                delay: const Duration(milliseconds: 100),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 14),
          Expanded(
            flex: 5,
            child: _AnimatedImage(
              delay: const Duration(milliseconds: 500),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  slide.imagePath!,
                  fit: BoxFit.contain,
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
// Card Controls slide
// ---------------------------------------------------------------------------

class _CardControlsSlideView extends StatelessWidget {
  final _OnboardingSlide slide;

  const _CardControlsSlideView({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        children: [
          const Spacer(flex: 1),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.heading2(context),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AnimatedMascot(
                size: 56,
                pose: slide.pose,
                delay: const Duration(milliseconds: 100),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 14),
          Expanded(
            flex: 5,
            child: _AnimatedImage(
              delay: const Duration(milliseconds: 500),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/onboarding/card_controls.png',
                  fit: BoxFit.contain,
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
                style: AppTypography.bodySmall(context).copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : onGoogle,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.g_mobiledata),
              label: const Text('Continue with Google'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : onGuest,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Continue as Guest'),
                  Text(
                    'Expires after 10 days',
                    style: AppTypography.caption(context).copyWith(
                      color: scheme.onSecondaryContainer.withAlpha(180),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (replayMode) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip'),
            ),
          ],
          const Spacer(flex: 4),
        ],
      ),
    );
  }
}
