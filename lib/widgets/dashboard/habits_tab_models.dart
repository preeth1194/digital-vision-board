import 'package:flutter/material.dart';

import '../../models/habit_item.dart';

class HabitEntry {
  final String boardId;
  final String boardTitle;
  final HabitItem habit;

  HabitEntry({
    required this.boardId,
    required this.boardTitle,
    required this.habit,
  });
}

class PendingCoinAnimation {
  final Offset source;
  final Offset target;
  final int coins;

  PendingCoinAnimation({
    required this.source,
    required this.target,
    required this.coins,
  });
}

class FlexibleHabitDragData {
  final HabitItem habit;

  const FlexibleHabitDragData(this.habit);
}

class TimelineScheduleSelection {
  final int startMinutes;
  final int durationMinutes;

  const TimelineScheduleSelection({
    required this.startMinutes,
    required this.durationMinutes,
  });
}

class TimelineCardLayout {
  final HabitEntry entry;
  final double top;
  final double height;

  const TimelineCardLayout({
    required this.entry,
    required this.top,
    required this.height,
  });
}

class PinnedBoxHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  PinnedBoxHeaderDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.child,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant PinnedBoxHeaderDelegate oldDelegate) {
    return minExtentValue != oldDelegate.minExtentValue ||
        maxExtentValue != oldDelegate.maxExtentValue ||
        child != oldDelegate.child;
  }
}
