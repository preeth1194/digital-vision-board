import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit_item.dart';
import '../../utils/app_colors.dart';
import 'habit_form_constants.dart';

/// A clean, modern habit card matching the ritual-timeline design.
///
/// Shows a category icon in a pastel circle, habit name, streak info,
/// and an optional duration badge. The completion checkpoint is rendered
/// externally by the list wrapper (timeline).
class AnimatedHabitCard extends StatefulWidget {
  final HabitItem habit;
  final String boardTitle;
  final bool isCompleted;
  final bool isScheduledToday;
  final int coinsOnComplete;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDurationTap;
  final VoidCallback? onIconTap;
  final int index;

  /// When non-null, shows ad watch progress (e.g. "3/5") in the duration badge
  /// area instead of the timer duration.
  final int? adWatchedCount;
  final int? adTotalRequired;

  const AnimatedHabitCard({
    super.key,
    required this.habit,
    required this.boardTitle,
    required this.isCompleted,
    required this.isScheduledToday,
    required this.coinsOnComplete,
    required this.onTap,
    this.onLongPress,
    this.onDurationTap,
    this.onIconTap,
    this.index = 0,
    this.adWatchedCount,
    this.adTotalRequired,
  });

  @override
  State<AnimatedHabitCard> createState() => _AnimatedHabitCardState();
}

class _AnimatedHabitCardState extends State<AnimatedHabitCard>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;
  Animation<double>? _opacityAnimation;

  AnimationController? _strikeController;
  Animation<double>? _strikeAnimation;
  Animation<double>? _fadeAnimation;

  bool _isPressed = false;

  AnimationController get _entranceCtrl {
    if (_controller == null) _initControllers();
    return _controller!;
  }

  AnimationController get _strikeCtrl {
    if (_strikeController == null) _initControllers();
    return _strikeController!;
  }

  Animation<double> get _scaleAnim {
    if (_scaleAnimation == null) _initControllers();
    return _scaleAnimation!;
  }

  Animation<double> get _opacityAnim {
    if (_opacityAnimation == null) _initControllers();
    return _opacityAnimation!;
  }

  Animation<double> get _strikeAnim {
    if (_strikeAnimation == null) _initControllers();
    return _strikeAnimation!;
  }

  Animation<double> get _fadeAnim {
    if (_fadeAnimation == null) _initControllers();
    return _fadeAnimation!;
  }

  void _initControllers() {
    _controller ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation ??= Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
    );

    _opacityAnimation ??= Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeOut),
    );

    _strikeController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: widget.isCompleted ? 1.0 : 0.0,
    );

    _strikeAnimation ??= CurvedAnimation(
      parent: _strikeController!,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation ??= Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _strikeController!, curve: Curves.easeOut),
    );
  }

  @override
  void initState() {
    super.initState();
    _initControllers();

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedHabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted != oldWidget.isCompleted) {
      if (widget.isCompleted) {
        _strikeCtrl.forward();
      } else {
        _strikeCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _strikeController?.dispose();
    super.dispose();
  }

  static Color _categoryCircleColor(String? category, Brightness brightness) =>
      AppColors.categoryBgColor(category, brightness == Brightness.dark);

  // Resolve icon: prefer explicit iconIndex, else first icon for category.
  static IconData _resolveIcon(String? category, int? iconIndex) {
    if (iconIndex != null && iconIndex >= 0 && iconIndex < habitIcons.length) {
      return habitIcons[iconIndex].$1;
    }
    if (category == null) return Icons.bolt_outlined;
    final indices = categoryToIconIndices[category];
    if (indices == null || indices.isEmpty) return Icons.bolt_outlined;
    return habitIcons[indices.first].$1;
  }

  static Color _categoryIconColor(String? category, Brightness brightness) =>
      AppColors.categoryIconColor(category, brightness == Brightness.dark);

  String? _formatDuration() {
    final tb = widget.habit.timeBound;
    if (tb == null || !tb.enabled) return null;
    final d = tb.duration;
    if (d <= 0) return null;
    if (tb.unit == 'hours') return '$d hrs';
    return '$d min';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streak = widget.habit.currentStreak;
    final durationLabel = _formatDuration();
    final category = widget.habit.category;
    final iconCircleColor = _categoryCircleColor(category, Theme.of(context).brightness);
    final iconColor = _categoryIconColor(category, Theme.of(context).brightness);
    final icon = _resolveIcon(category, widget.habit.iconIndex);

    final textColor = colorScheme.onSurface;
    final subtitleColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.6)
        : colorScheme.onSurfaceVariant;
    final strikeColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.6)
        : colorScheme.onSurface.withValues(alpha: 0.5);

    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Opacity(
            opacity: _opacityAnim.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..setEntry(0, 0, _isPressed ? 0.98 : 1.0)
            ..setEntry(1, 1, _isPressed ? 0.98 : 1.0),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: _isPressed ? 0.04 : 0.08),
                blurRadius: _isPressed ? 4 : 12,
                offset: Offset(0, _isPressed ? 1 : 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Category icon circle — tappable to flip the card
              GestureDetector(
                onTap: widget.onIconTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconCircleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              // Name + streak
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated strikethrough name
                    AnimatedBuilder(
                      animation: _strikeCtrl,
                      builder: (context, _) {
                        return Stack(
                          children: [
                            // Text with animated opacity
                            Opacity(
                              opacity: _fadeAnim.value,
                              child: Text(
                                widget.habit.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Animated strikethrough line overlay
                            if (_strikeAnim.value > 0)
                              Positioned.fill(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: constraints.maxWidth * _strikeAnim.value,
                                        height: 2,
                                        decoration: BoxDecoration(
                                          color: strikeColor,
                                          borderRadius: BorderRadius.circular(1),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streak > 0 ? 'Streak $streak days' : "Ready for day 1?",
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Ad progress badge (when user has pending ads to watch)
              if (widget.adWatchedCount != null && widget.adTotalRequired != null) ...[
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: isDark
                      ? colorScheme.onSurface.withValues(alpha: 0.12)
                      : colorScheme.shadow.withValues(alpha: 0.08),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.adWatchedCount}/${widget.adTotalRequired}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ]
              // Duration badge (if applicable) — tappable to open timer
              else if (durationLabel != null) ...[
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: isDark
                      ? colorScheme.onSurface.withValues(alpha: 0.12)
                      : colorScheme.shadow.withValues(alpha: 0.08),
                ),
                GestureDetector(
                  onTap: widget.onDurationTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: subtitleColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        durationLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
