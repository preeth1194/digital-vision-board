import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/habit_item.dart';
import '../../../models/insights_month_summary.dart';
import '../../../services/insight_share_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';

/// Which share layout to rasterize (4:5 card).
enum InsightShareTemplateKind {
  focus,
  rhythm,
  invested,
  flow,
}

/// Data for a single-habit, single-month share card.
final class InsightSharePayload {
  InsightSharePayload({
    required this.habit,
    required this.summary,
    required this.monthLabel,
    required this.completedScheduledDays,
    required this.totalScheduledDays,
    required this.seedsEarned,
    required this.estimatedMinutes,
    required this.longestRunInMonth,
    required this.currentStreakLogical,
  });

  final HabitItem habit;
  final InsightsMonthSummary summary;
  final String monthLabel;
  final int completedScheduledDays;
  final int totalScheduledDays;
  final int seedsEarned;
  final int? estimatedMinutes;
  final int longestRunInMonth;
  final int currentStreakLogical;

  factory InsightSharePayload.fromHabit({
    required HabitItem habit,
    required InsightsMonthSummary summary,
    required DateTime logicalToday,
  }) {
    final monthLabel = DateFormat.yMMMM().format(
      DateTime(summary.year, summary.month, 1),
    );
    return InsightSharePayload(
      habit: habit,
      summary: summary,
      monthLabel: monthLabel,
      completedScheduledDays:
          InsightsMonthSummary.completedScheduledDaysInMonth(habit, summary),
      totalScheduledDays: InsightsMonthSummary.scheduledDaysInMonth(
        habit,
        summary,
      ),
      seedsEarned: InsightsMonthSummary.seedsEarnedInMonth(habit, summary),
      estimatedMinutes:
          InsightsMonthSummary.estimatedMinutesInvested(habit, summary),
      longestRunInMonth:
          InsightsMonthSummary.longestCompletionRunInMonth(habit, summary),
      currentStreakLogical: habit.currentStreakAsOf(logicalToday),
    );
  }
}

/// Full-size 1080×1350 share card (see [InsightShareService.shareLogicalSize]).
class InsightShareTemplateCard extends StatelessWidget {
  const InsightShareTemplateCard({
    super.key,
    required this.kind,
    required this.payload,
  });

  final InsightShareTemplateKind kind;
  final InsightSharePayload payload;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case InsightShareTemplateKind.focus:
        return _FocusTemplate(payload: payload);
      case InsightShareTemplateKind.rhythm:
        return _RhythmTemplate(payload: payload);
      case InsightShareTemplateKind.invested:
        return _InvestedTemplate(payload: payload);
      case InsightShareTemplateKind.flow:
        return _FlowTemplate(payload: payload);
    }
  }
}

Widget _brandFooter(BuildContext context) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Image.asset(
        'assets/icon/app_icon.png',
        width: 40,
        height: 40,
      ),
      const SizedBox(width: AppSpacing.sm),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Digital Vision Board',
            style: AppTypography.bodySmall(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.forestDeep.withValues(alpha: 0.85),
            ),
          ),
          Text(
            'habitseeding',
            style: AppTypography.caption(context).copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.forestDeep.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    ],
  );
}

LinearGradient _softBgGradient() {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.mistBackground,
      AppColors.lavenderContainer.withValues(alpha: 0.85),
      AppColors.sageContainer.withValues(alpha: 0.5),
    ],
    stops: const [0.0, 0.55, 1.0],
  );
}

class _FocusTemplate extends StatelessWidget {
  const _FocusTemplate({required this.payload});

  final InsightSharePayload payload;

  @override
  Widget build(BuildContext context) {
    final rate = payload.totalScheduledDays > 0
        ? (100 * payload.completedScheduledDays / payload.totalScheduledDays)
            .round()
        : 0;
    final category = (payload.habit.category ?? 'Growth').trim();
    return Container(
      width: InsightShareService.shareLogicalSize.width,
      height: InsightShareService.shareLogicalSize.height,
      decoration: BoxDecoration(gradient: _softBgGradient()),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              category.toUpperCase(),
              style: AppTypography.caption(context).copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.sproutGreen.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              payload.habit.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading1(context).copyWith(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                height: 1.05,
                color: AppColors.forestDeep,
              ),
            ),
            const Spacer(),
            Text(
              '$rate%',
              style: AppTypography.heading1(context).copyWith(
                fontSize: 120,
                fontWeight: FontWeight.w800,
                color: AppColors.sproutGreen,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${payload.completedScheduledDays} / ${payload.totalScheduledDays} scheduled days',
              style: AppTypography.heading3(context).copyWith(
                fontSize: 22,
                color: AppColors.forestDeep.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${payload.seedsEarned} seeds earned · ${payload.monthLabel}',
              style: AppTypography.heading3(context).copyWith(
                fontSize: 18,
                color: AppColors.honeyText,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You are showing up with quiet consistency.',
              style: AppTypography.body(context).copyWith(
                fontSize: 20,
                height: 1.35,
                color: AppColors.forestDeep.withValues(alpha: 0.65),
              ),
            ),
            const Spacer(),
            _brandFooter(context),
          ],
        ),
      ),
    );
  }
}

class _RhythmTemplate extends StatelessWidget {
  const _RhythmTemplate({required this.payload});

  final InsightSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: InsightShareService.shareLogicalSize.width,
      height: InsightShareService.shareLogicalSize.height,
      decoration: BoxDecoration(gradient: _softBgGradient()),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your rhythm',
              style: AppTypography.heading1(context).copyWith(
                fontSize: 44,
                color: AppColors.forestDeep,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              payload.habit.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading3(context).copyWith(
                fontSize: 22,
                color: AppColors.sproutGreen,
              ),
            ),
            Text(
              payload.monthLabel,
              style: AppTypography.body(context).copyWith(
                color: AppColors.forestDeep.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: _RhythmGrid(
                typographyContext: context,
                habit: payload.habit,
                days: payload.summary.days,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${payload.completedScheduledDays} of ${payload.totalScheduledDays} scheduled days completed.',
              textAlign: TextAlign.center,
              style: AppTypography.body(context).copyWith(
                fontSize: 18,
                color: AppColors.forestDeep.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            _brandFooter(context),
          ],
        ),
      ),
    );
  }
}

class _RhythmGrid extends StatelessWidget {
  const _RhythmGrid({
    required this.typographyContext,
    required this.habit,
    required this.days,
  });

  final BuildContext typographyContext;
  final HabitItem habit;
  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    const cols = 7;
    final rows = (days.length / cols).ceil();
    return Column(
      children: List.generate(rows, (r) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: List.generate(cols, (c) {
                final i = r * cols + c;
                if (i >= days.length) {
                  return const Expanded(child: SizedBox.shrink());
                }
                final d = days[i];
                final scheduled = habit.isScheduledOnDate(d);
                final done = habit.isCompletedOnDate(d);
                Color bg;
                if (!scheduled) {
                  bg = Colors.white.withValues(alpha: 0.25);
                } else if (done) {
                  bg = AppColors.sproutGreen.withValues(alpha: 0.85);
                } else {
                  bg = AppColors.seedGold.withValues(alpha: 0.35);
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.forestDeep.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${d.day}',
                          style: AppTypography.caption(typographyContext).copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheduled && done
                                ? Colors.white
                                : AppColors.forestDeep.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      }),
    );
  }
}

class _InvestedTemplate extends StatelessWidget {
  const _InvestedTemplate({required this.payload});

  final InsightSharePayload payload;

  @override
  Widget build(BuildContext context) {
    final minutes = payload.estimatedMinutes;
    final headline = minutes != null
        ? '$minutes'
        : '${payload.completedScheduledDays}';
    final unit = minutes != null ? 'minutes this month' : 'days nurtured';
    final w = InsightShareService.shareLogicalSize.width;
    return Container(
      width: w,
      height: InsightShareService.shareLogicalSize.height,
      decoration: BoxDecoration(gradient: _softBgGradient()),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Time you invested',
              style: AppTypography.heading1(context).copyWith(
                fontSize: 40,
                color: AppColors.forestDeep,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              payload.habit.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading3(context).copyWith(
                fontSize: 22,
                color: AppColors.lavenderDew,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              width: w - 96,
              child: CustomPaint(
                painter: _MountainPainter(),
                size: Size(w - 96, 260),
              ),
            ),
            const Spacer(),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: AppTypography.heading1(context).copyWith(
                fontSize: 96,
                color: AppColors.sproutGreen,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              unit,
              textAlign: TextAlign.center,
              style: AppTypography.heading3(context).copyWith(
                fontSize: 22,
                color: AppColors.forestDeep.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              minutes != null
                  ? 'You are making space for what matters.'
                  : 'Every day in the garden counts.',
              textAlign: TextAlign.center,
              style: AppTypography.body(context).copyWith(
                fontSize: 20,
                height: 1.35,
                color: AppColors.forestDeep.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            _brandFooter(context),
          ],
        ),
      ),
    );
  }
}

class _MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = AppColors.lavenderDew.withValues(alpha: 0.35);
    final path = Path()
      ..moveTo(0, size.height * 0.85)
      ..lineTo(size.width * 0.25, size.height * 0.45)
      ..lineTo(size.width * 0.5, size.height * 0.65)
      ..lineTo(size.width * 0.72, size.height * 0.38)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
    paint.color = AppColors.sproutGreen.withValues(alpha: 0.28);
    final path2 = Path()
      ..moveTo(0, size.height * 0.95)
      ..lineTo(size.width * 0.35, size.height * 0.55)
      ..lineTo(size.width * 0.62, size.height * 0.72)
      ..lineTo(size.width, size.height * 0.52)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlowTemplate extends StatelessWidget {
  const _FlowTemplate({required this.payload});

  final InsightSharePayload payload;

  @override
  Widget build(BuildContext context) {
    final flowDays = payload.longestRunInMonth > 0
        ? payload.longestRunInMonth
        : payload.currentStreakLogical;
    return Container(
      width: InsightShareService.shareLogicalSize.width,
      height: InsightShareService.shareLogicalSize.height,
      decoration: BoxDecoration(gradient: _softBgGradient()),
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.seedGold.withValues(alpha: 0.25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.seedGold.withValues(alpha: 0.35),
                      blurRadius: 48,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.eco_rounded,
                  size: 120,
                  color: AppColors.sproutGreen,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              '$flowDays day flow',
              textAlign: TextAlign.center,
              style: AppTypography.heading1(context).copyWith(
                fontSize: 56,
                color: AppColors.forestDeep,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              payload.habit.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading3(context).copyWith(
                fontSize: 24,
                color: AppColors.sproutGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You are building a steady habit.',
              textAlign: TextAlign.center,
              style: AppTypography.body(context).copyWith(
                fontSize: 22,
                height: 1.35,
                color: AppColors.forestDeep.withValues(alpha: 0.65),
              ),
            ),
            Text(
              payload.monthLabel,
              textAlign: TextAlign.center,
              style: AppTypography.body(context).copyWith(
                color: AppColors.forestDeep.withValues(alpha: 0.5),
              ),
            ),
            const Spacer(),
            _brandFooter(context),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: pick a template, returns selected kind.
Future<InsightShareTemplateKind?> showInsightShareTemplatePicker(
  BuildContext context,
) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<InsightShareTemplateKind>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusCard),
      ),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share as image',
                style: AppTypography.heading3(ctx),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Choose a layout for Instagram or your favorite app.',
                style: AppTypography.secondary(ctx),
              ),
              const SizedBox(height: AppSpacing.lg),
              _templateOption(
                ctx,
                InsightShareTemplateKind.focus,
                'Focus',
                'Big progress & seeds',
                Icons.center_focus_strong_outlined,
              ),
              const SizedBox(height: AppSpacing.sm),
              _templateOption(
                ctx,
                InsightShareTemplateKind.rhythm,
                'Rhythm',
                'Month grid',
                Icons.grid_view_rounded,
              ),
              const SizedBox(height: AppSpacing.sm),
              _templateOption(
                ctx,
                InsightShareTemplateKind.invested,
                'Invested',
                'Time or days nurtured',
                Icons.timelapse_rounded,
              ),
              const SizedBox(height: AppSpacing.sm),
              _templateOption(
                ctx,
                InsightShareTemplateKind.flow,
                'Flow',
                'Streak highlight',
                Icons.waves_rounded,
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _templateOption(
  BuildContext context,
  InsightShareTemplateKind kind,
  String title,
  String subtitle,
  IconData icon,
) {
  final cs = Theme.of(context).colorScheme;
  return Semantics(
    label: '$title. $subtitle',
    button: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(kind),
        borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, color: cs.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.heading3(context)),
                      Text(subtitle, style: AppTypography.caption(context)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
