import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/challenge.dart';
import '../../models/habit_item.dart';
import '../../services/challenge_storage_service.dart';
import '../../services/challenge_progress_service.dart';
import '../../services/habit_storage_service.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/rituals/habit_form_constants.dart';

/// Dashboard card showing the active challenge progress, today's task
/// checklist, and day counter with a circular progress indicator.
class ChallengeProgressCard extends StatefulWidget {
  final VoidCallback? onStartChallenge;

  const ChallengeProgressCard({super.key, this.onStartChallenge});

  @override
  State<ChallengeProgressCard> createState() => _ChallengeProgressCardState();
}

class _ChallengeProgressCardState extends State<ChallengeProgressCard>
    with WidgetsBindingObserver {
  Challenge? _challenge;
  List<HabitItem> _challengeHabits = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // Run daily aggregation check
    final challenges = await ChallengeStorageService.getActiveChallenges(prefs: prefs);
    if (challenges.isNotEmpty) {
      for (final c in challenges) {
        await ChallengeProgressService.evaluateDay(c, prefs: prefs);
      }
    }

    final challenge = await ChallengeStorageService.getActiveChallenge(prefs: prefs);
    List<HabitItem> habits = const [];
    if (challenge != null) {
      habits = await HabitStorageService.getHabitsByIds(
        challenge.habitIds,
        prefs: prefs,
      );
    }
    if (mounted) {
      setState(() {
        _challenge = challenge;
        _challengeHabits = habits;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final challenge = _challenge;
    if (challenge == null || !challenge.isActive) {
      return _buildEmptyState(context);
    }

    return _buildProgressCard(context, challenge);
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onStartChallenge,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.military_tech_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a Challenge',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Try 75 Hard or other mental toughness programs',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, Challenge challenge) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = LogicalDateService.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = challenge.currentDay;
    final total = challenge.totalDays;

    final completedToday = _challengeHabits
        .where((h) => h.isCompletedOnDate(today))
        .length;
    final totalHabits = _challengeHabits.length;
    final allDoneToday = completedToday >= totalHabits && totalHabits > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A2E1A), const Color(0xFF0F1A0F)]
                : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Icon(
                    Icons.military_tech_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      challenge.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (challenge.restartCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${challenge.restartCount}x restarted',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress ring + day counter
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CustomPaint(
                      painter: _ProgressRingPainter(
                        progress: challenge.progress,
                        ringColor: colorScheme.primary,
                        trackColor: colorScheme.onSurface.withValues(alpha: 0.12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'of $total',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Today's tasks
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allDoneToday ? 'All done today!' : 'Today\'s Tasks',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: allDoneToday
                                ? AppColors.badgeGreen
                                : colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._challengeHabits.map((h) {
                          final done = h.isCompletedOnDate(today);
                          final iconIdx = h.iconIndex ?? 0;
                          final iconData = (iconIdx < habitIcons.length)
                              ? habitIcons[iconIdx].$1
                              : Icons.check_circle;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Icon(
                                  done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: done
                                      ? AppColors.badgeGreen
                                      : colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                                const SizedBox(width: 6),
                                Icon(iconData, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    h.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: done
                                          ? colorScheme.onSurface.withValues(alpha: 0.5)
                                          : colorScheme.onSurface,
                                      decoration: done ? TextDecoration.lineThrough : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalHabits > 0 ? completedToday / totalHabits : 0,
                  minHeight: 4,
                  backgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(
                    allDoneToday ? AppColors.badgeGreen : colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$completedToday of $totalHabits tasks completed today',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  _ProgressRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 6.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.trackColor != trackColor;
}
