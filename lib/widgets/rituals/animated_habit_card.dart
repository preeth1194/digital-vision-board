import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit_item.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_colors.dart';

/// A modern, compact habit card with gradient background and elegant typography.
class AnimatedHabitCard extends StatefulWidget {
  final HabitItem habit;
  final String boardTitle;
  final bool isCompleted;
  final bool isScheduledToday;
  final int coinsOnComplete;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final int index; // For staggered animations

  const AnimatedHabitCard({
    super.key,
    required this.habit,
    required this.boardTitle,
    required this.isCompleted,
    required this.isScheduledToday,
    required this.coinsOnComplete,
    required this.onTap,
    this.onLongPress,
    this.index = 0,
  });

  @override
  State<AnimatedHabitCard> createState() => _AnimatedHabitCardState();
}

class _AnimatedHabitCardState extends State<AnimatedHabitCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isPressed = false;

  // Theme-based gradient color sets using AppColors
  static const List<List<Color>> _lightGradients = [
    [AppColors.dark, AppColors.medium],
    [Color(0xFF052659), Color(0xFF7DA0CA)],
    [AppColors.medium, AppColors.light],
    [Color(0xFF0A3D62), Color(0xFF5483B3)],
  ];

  static const List<List<Color>> _darkGradients = [
    [AppColors.dark, AppColors.medium],
    [Color(0xFF0A1E3A), Color(0xFF5483B3)],
    [AppColors.medium, AppColors.light],
    [Color(0xFF052659), Color(0xFF7DA0CA)],
  ];

  List<Color> _getCardGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradients = isDark ? _darkGradients : _lightGradients;
    final hash = widget.habit.id.hashCode;
    return gradients[hash.abs() % gradients.length];
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // Staggered entrance animation
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streak = widget.habit.currentStreak;
    final now = LogicalDateService.now();
    final completionsThisWeek = _getCompletionsThisWeek(widget.habit, now);
    final cardGradient = _getCardGradient(context);

    // Text colors
    final textColor = colorScheme.onPrimary;
    final subtitleColor = colorScheme.onPrimary.withValues(alpha: 0.7);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value.clamp(0.0, 1.0),
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.isCompleted
                  ? [
                      cardGradient[0].withValues(alpha: 0.5),
                      cardGradient[1].withValues(alpha: 0.5),
                    ]
                  : cardGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: cardGradient[0].withValues(alpha: _isPressed ? 0.15 : 0.25),
                blurRadius: _isPressed ? 6 : 12,
                offset: Offset(0, _isPressed ? 2 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Completion overlay
                if (widget.isCompleted)
                  Positioned.fill(
                    child: Container(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                // Main content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Left content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Habit name
                            Text(
                              widget.habit.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                                decoration: widget.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: textColor.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Bottom info row
                            Row(
                              children: [
                                // Board title
                                Flexible(
                                  child: Text(
                                    widget.boardTitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: subtitleColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Streak badge
                                if (streak > 0) ...[
                                  Text(
                                    ' • ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: subtitleColor,
                                    ),
                                  ),
                                  Text(
                                    '🔥$streak',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                                // Progress
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subtitleColor,
                                  ),
                                ),
                                _buildCompactProgress(completionsThisWeek, textColor, subtitleColor),
                              ],
                            ),
                            // Not scheduled indicator
                            if (!widget.isScheduledToday) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Not scheduled today',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Coins badge
                      _buildCoinsIndicator(),
                      const SizedBox(width: 10),
                      // Completion checkmark
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isCompleted
                              ? textColor
                              : textColor.withValues(alpha: 0.15),
                          border: Border.all(
                            color: textColor.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: widget.isCompleted
                              ? Icon(
                                  Icons.check_rounded,
                                  key: const ValueKey('check'),
                                  color: cardGradient[0],
                                  size: 18,
                                )
                              : const SizedBox(key: ValueKey('empty')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactProgress(int completions, Color textColor, Color subtitleColor) {
    final isWeekly = widget.habit.isWeekly;
    final targetDays = isWeekly
        ? (widget.habit.weeklyDays.isEmpty ? 1 : widget.habit.weeklyDays.length)
        : 7;
    final progress = (completions / targetDays).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mini progress bar
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: textColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$completions/$targetDays',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCoinsIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text(
                '¢',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '+${widget.coinsOnComplete}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFD700),
            ),
          ),
        ],
      ),
    );
  }

  int _getCompletionsThisWeek(HabitItem habit, DateTime now) {
    final weekStart = _getWeekStart(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    
    return habit.completedDates.where((date) {
      final normalized = DateTime(date.year, date.month, date.day);
      return normalized.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          normalized.isBefore(weekEnd);
    }).length;
  }

  DateTime _getWeekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final delta = d.weekday - DateTime.monday;
    return d.subtract(Duration(days: delta));
  }
}
