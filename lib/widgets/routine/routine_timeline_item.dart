import 'package:flutter/material.dart';
import '../../models/routine.dart';
import '../../utils/app_colors.dart';

/// A timeline item widget for displaying a routine in the timeline view.
class RoutineTimelineItem extends StatelessWidget {
  final Routine routine;
  final DateTime selectedDate;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const RoutineTimelineItem({
    super.key,
    required this.routine,
    required this.selectedDate,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  String _formatTimeFromMinutes(int? minutes) {
    if (minutes == null) return '--:--';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final isPM = hours >= 12;
    final hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    return '${hour12.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')} ${isPM ? 'PM' : 'AM'}';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '$hours hr';
    }
    return '$hours hr $mins min';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final tileColor = Color(routine.tileColorValue);
    final icon = IconData(routine.iconCodePoint, fontFamily: 'MaterialIcons');
    final duration = routine.getTotalDurationMinutes();
    final startTime = routine.getStartTimeMinutes();
    final endTime = startTime != null ? startTime + duration : null;
    final completion = routine.getCompletionPercentageForDate(selectedDate);
    final isCompleted = completion >= 1.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time column
          SizedBox(
            width: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  _formatTimeFromMinutes(startTime),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.light : AppColors.medium,
                  ),
                ),
              ],
            ),
          ),
          // Timeline connector
          _TimelineConnector(
            color: tileColor,
            isFirst: isFirst,
            isLast: isLast,
            isCompleted: isCompleted,
          ),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 16, top: 8, bottom: 8),
              child: _RoutineCard(
                routine: routine,
                icon: icon,
                tileColor: tileColor,
                startTime: _formatTimeFromMinutes(startTime),
                endTime: _formatTimeFromMinutes(endTime),
                duration: _formatDuration(duration),
                isCompleted: isCompleted,
                completion: completion,
                onTap: onTap,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  final Color color;
  final bool isFirst;
  final bool isLast;
  final bool isCompleted;

  const _TimelineConnector({
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Column(
        children: [
          // Top connector line
          if (!isFirst)
            Container(
              width: 2,
              height: 16,
              color: color.withOpacity(0.5),
            )
          else
            const SizedBox(height: 16),
          // Node
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? color : Colors.transparent,
              border: Border.all(
                color: color,
                width: 3,
              ),
            ),
            child: isCompleted
                ? Icon(
                    Icons.check,
                    size: 10,
                    color: _getContrastColor(color),
                  )
                : null,
          ),
          // Bottom connector line
          Expanded(
            child: Container(
              width: 2,
              color: isLast ? Colors.transparent : color.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? AppColors.darkest : AppColors.lightest;
  }
}

class _RoutineCard extends StatelessWidget {
  final Routine routine;
  final IconData icon;
  final Color tileColor;
  final String startTime;
  final String endTime;
  final String duration;
  final bool isCompleted;
  final double completion;
  final VoidCallback onTap;
  final bool isDark;

  const _RoutineCard({
    required this.routine,
    required this.icon,
    required this.tileColor,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.isCompleted,
    required this.completion,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = _getContrastColor(tileColor);
    final subtitleColor = textColor.withOpacity(0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tileColor.withOpacity(isDark ? 0.9 : 1.0),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: tileColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      routine.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: subtitleColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$startTime - $endTime',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            duration,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Completion indicator
              _CompletionIndicator(
                completion: completion,
                isCompleted: isCompleted,
                color: textColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? AppColors.darkest : AppColors.lightest;
  }
}

class _CompletionIndicator extends StatelessWidget {
  final double completion;
  final bool isCompleted;
  final Color color;

  const _CompletionIndicator({
    required this.completion,
    required this.isCompleted,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 3,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(color.withOpacity(0.2)),
          ),
          // Progress
          CircularProgressIndicator(
            value: completion,
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          // Check or percentage
          if (isCompleted)
            Icon(
              Icons.check,
              size: 16,
              color: color,
            )
          else if (completion > 0)
            Text(
              '${(completion * 100).round()}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}
