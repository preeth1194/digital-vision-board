import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../utils/app_colors.dart';

/// Shows a fullscreen Lottie coin animation overlay.
/// This function displays the overlay as a fullscreen route that covers
/// the entire screen including app bar and bottom navigation.
Future<void> showLottieCoinOverlay(
  BuildContext context, {
  required int coinsEarned,
  required int totalCoins,
  required VoidCallback onComplete,
}) async {
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LottieCoinOverlayScreen(
          onComplete: () {
            Navigator.of(context).pop();
            onComplete();
          },
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    ),
  );
}

/// Internal screen widget for the fullscreen overlay
class _LottieCoinOverlayScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const _LottieCoinOverlayScreen({
    required this.onComplete,
  });

  @override
  State<_LottieCoinOverlayScreen> createState() => _LottieCoinOverlayScreenState();
}

class _LottieCoinOverlayScreenState extends State<_LottieCoinOverlayScreen>
    with TickerProviderStateMixin {
  late AnimationController _lottieController;
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    
    _lottieController = AnimationController(vsync: this);
    _lottieController.addStatusListener(_onLottieStatusChanged);
    
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _backgroundAnimation = CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeOut,
    );
    _backgroundController.forward();
  }

  @override
  void dispose() {
    _lottieController.removeStatusListener(_onLottieStatusChanged);
    _lottieController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _onLottieStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Wait a bit before dismissing
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _backgroundController.reverse().then((_) {
            widget.onComplete();
          });
        }
      });
    }
  }

  void _onLottieLoaded(LottieComposition composition) {
    _lottieController.duration = composition.duration;
    if (!_isPlaying) {
      _isPlaying = true;
      HapticFeedback.mediumImpact();
      _lottieController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Background colors based on theme
    final backgroundColor = isDark 
        ? AppColors.darkest 
        : Colors.white;
    final textColor = isDark 
        ? Colors.white 
        : AppColors.darkest;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            width: screenSize.width,
            height: screenSize.height,
            decoration: BoxDecoration(
              color: backgroundColor.withValues(
                alpha: _backgroundAnimation.value.clamp(0.0, 1.0),
              ),
            ),
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _lottieController,
                builder: (context, child) {
                  final progress = _lottieController.value;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Celebration text
                      AnimatedOpacity(
                        opacity: progress > 0.1 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          '🎉 Great Job! 🎉',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Lottie animation - large size
                      SizedBox(
                        width: screenSize.width * 0.75,
                        height: screenSize.width * 0.75,
                        child: Transform.scale(
                          scale: 1.0 + (progress * 0.1),
                          child: Lottie.asset(
                            'assets/animations/coin.json',
                            controller: _lottieController,
                            onLoaded: _onLottieLoaded,
                            fit: BoxFit.contain,
                            repeat: false,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Legacy widget for backwards compatibility - use showLottieCoinOverlay instead
/// This is kept for Stack-based usage but the fullscreen route is preferred
class LottieCoinOverlay extends StatefulWidget {
  final VoidCallback onAnimationComplete;
  final int coinsEarned;
  final int totalCoins;

  const LottieCoinOverlay({
    super.key,
    required this.onAnimationComplete,
    required this.coinsEarned,
    required this.totalCoins,
  });

  @override
  State<LottieCoinOverlay> createState() => _LottieCoinOverlayState();
}

class _LottieCoinOverlayState extends State<LottieCoinOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _lottieController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _lottieController.addStatusListener(_onLottieStatusChanged);
  }

  @override
  void dispose() {
    _lottieController.removeStatusListener(_onLottieStatusChanged);
    _lottieController.dispose();
    super.dispose();
  }

  void _onLottieStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          widget.onAnimationComplete();
        }
      });
    }
  }

  void _onLottieLoaded(LottieComposition composition) {
    _lottieController.duration = composition.duration;
    if (!_isPlaying) {
      _isPlaying = true;
      HapticFeedback.mediumImpact();
      _lottieController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkest : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.darkest;
    
    return Positioned.fill(
      child: Material(
        color: backgroundColor,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _lottieController,
            builder: (context, child) {
              final progress = _lottieController.value;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Celebration text
                  AnimatedOpacity(
                    opacity: progress > 0.1 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '🎉 Great Job! 🎉',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Lottie animation
                  SizedBox(
                    width: screenSize.width * 0.75,
                    height: screenSize.width * 0.75,
                    child: Transform.scale(
                      scale: 1.0 + (progress * 0.1),
                      child: Lottie.asset(
                        'assets/animations/coin.json',
                        controller: _lottieController,
                        onLoaded: _onLottieLoaded,
                        fit: BoxFit.contain,
                        repeat: false,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
