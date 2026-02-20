import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/challenge.dart';
import '../../models/habit_item.dart';
import '../../services/ad_service.dart';
import '../../services/challenge_storage_service.dart';
import '../../services/challenge_progress_service.dart';
import '../../services/habit_storage_service.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_typography.dart';
import '../../widgets/rituals/habit_form_constants.dart';
import '../ads/challenge_reward_ad_card.dart';

/// Dashboard card showing the active challenge progress, today's task
/// checklist, and day counter with a circular progress indicator.
class ChallengeProgressCard extends StatefulWidget {
  final int dataVersion;
  final VoidCallback? onStartChallenge;
  final VoidCallback? onViewHabits;

  const ChallengeProgressCard({super.key, this.dataVersion = 0, this.onStartChallenge, this.onViewHabits});

  @override
  State<ChallengeProgressCard> createState() => _ChallengeProgressCardState();
}

class _ChallengeProgressCardState extends State<ChallengeProgressCard>
    with WidgetsBindingObserver {
  Challenge? _challenge;
  List<HabitItem> _challengeHabits = const [];
  bool _loaded = false;

  bool _showChallengeAd = false;
  String? _challengeAdSession;
  int _challengeAdWatchedCount = 0;

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
  void didUpdateWidget(covariant ChallengeProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataVersion != widget.dataVersion) {
      _load();
    }
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
    String? adSession;
    int adWatched = 0;
    bool showAd = false;
    if (challenge == null || !challenge.isActive) {
      adSession = await AdService.getChallengeSession(prefs: prefs);
      if (adSession != null) {
        adWatched = await AdService.getChallengeWatchedCount(adSession, prefs: prefs);
        final complete = adWatched >= AdService.requiredAdsForChallenge;
        showAd = !complete;
      }
    }

    if (mounted) {
      setState(() {
        _challenge = challenge;
        _challengeHabits = habits;
        _challengeAdSession = adSession;
        _challengeAdWatchedCount = adWatched;
        _showChallengeAd = showAd;
        _loaded = true;
      });
    }
  }

  Future<void> _onChallengeAdWatched() async {
    if (_challengeAdSession == null) return;
    final newCount = await AdService.incrementChallengeWatchedCount(
      _challengeAdSession!,
    );
    if (mounted) {
      setState(() => _challengeAdWatchedCount = newCount);
    }
  }

  Future<void> _onAllChallengeAdsWatched() async {
    if (_challengeAdSession != null) {
      await AdService.clearChallengeSession(_challengeAdSession!);
    }
    if (mounted) {
      setState(() {
        _showChallengeAd = false;
        _challengeAdSession = null;
        _challengeAdWatchedCount = 0;
      });
    }
    widget.onStartChallenge?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final challenge = _challenge;
    if (challenge == null || !challenge.isActive) {
      if (_showChallengeAd && _challengeAdSession != null) {
        return _buildAdGatedState(context);
      }
      return _buildEmptyState(context);
    }

    return _buildProgressCard(context, challenge);
  }

  // ── Ad-gated state ─────────────────────────────────────────────────

  Widget _buildAdGatedState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.onPrimaryContainer;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.military_tech_rounded,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '75 Hard',
                    style: AppTypography.heading3(context).copyWith(
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ChallengeRewardAdCard(
              sessionKey: _challengeAdSession!,
              watchedCount: _challengeAdWatchedCount,
              onAdWatched: _onChallengeAdWatched,
              onAllAdsWatched: _onAllChallengeAdsWatched,
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onStartChallenge,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.military_tech_rounded,
                color: cs.onPrimaryContainer,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '75 Hard',
                      style: AppTypography.heading3(context).copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Start a mental toughness challenge',
                      style: AppTypography.caption(context).copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onPrimaryContainer.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress card ────────────────────────────────────────────────────

  Widget _buildProgressCard(BuildContext context, Challenge challenge) {
    final cs = Theme.of(context).colorScheme;
    final now = LogicalDateService.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = challenge.currentDay;
    final total = challenge.totalDays;

    final completedToday = _challengeHabits
        .where((h) => h.isCompletedOnDate(today))
        .length;
    final totalHabits = _challengeHabits.length;
    final allDoneToday = completedToday >= totalHabits && totalHabits > 0;
    final accent = cs.onPrimaryContainer;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onViewHabits,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row — matches Insights / Mood / Manifest cards
              Row(
                children: [
                  Icon(
                    Icons.military_tech_rounded,
                    color: accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      challenge.name,
                      style: AppTypography.heading3(context).copyWith(
                        color: accent,
                      ),
                    ),
                  ),
                  if (challenge.restartCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${challenge.restartCount}x restarted',
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: accent.withValues(alpha: 0.6),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Two-column layout: day counter | today's tasks
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Column 1 — large day counter with progress ring
                Expanded(
                  child: SizedBox(
                    height: 100,
                    child: CustomPaint(
                      painter: _ProgressRingPainter(
                        progress: challenge.progress,
                        ringColor: accent,
                        trackColor: accent.withValues(alpha: 0.15),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$day',
                              style: AppTypography.heading1(context).copyWith(
                                fontSize: 36,
                                color: accent,
                              ),
                            ),
                            Text(
                              'of $total',
                              style: AppTypography.caption(context).copyWith(
                                color: accent.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Column 2 — today's tasks
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        allDoneToday ? 'All done today!' : 'Today\'s Tasks',
                        style: AppTypography.bodySmall(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: allDoneToday
                              ? cs.primary
                              : accent.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
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
                                done
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                size: 16,
                                color: done
                                    ? cs.primary
                                    : accent.withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 6),
                              Icon(iconData,
                                  size: 14,
                                  color: accent.withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  h.name,
                                  style: AppTypography.caption(context).copyWith(
                                    color: done
                                        ? accent.withValues(alpha: 0.45)
                                        : accent,
                                    decoration:
                                        done ? TextDecoration.lineThrough : null,
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
                minHeight: 5,
                backgroundColor: accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  allDoneToday ? cs.primary : accent,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$completedToday of $totalHabits tasks completed today',
              style: AppTypography.caption(context).copyWith(
                color: accent.withValues(alpha: 0.5),
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
