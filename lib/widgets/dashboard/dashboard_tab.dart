import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../models/routine.dart';
import '../../utils/app_spacing.dart';
import 'habit_progress_completion_card.dart';
import 'puzzle_summary_card.dart';
import 'insights_summary_card.dart';
import 'mood_tracker_card.dart';
import 'reward_ads_coin_card.dart';
import 'water_intake_card.dart';

class DashboardTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final String? activeBoardId;
  final List<Routine> routines;
  final String? activeRoutineId;
  final SharedPreferences? prefs;
  final int dataVersion;
  final ValueNotifier<int>? coinNotifier;
  final VoidCallback onCreateBoard;
  final ValueChanged<VisionBoardInfo> onOpenEditor;
  final ValueChanged<VisionBoardInfo> onOpenViewer;
  final ValueChanged<VisionBoardInfo> onDeleteBoard;
  final VoidCallback? onStartChallenge;
  final VoidCallback? onViewHabits;

  const DashboardTab({
    super.key,
    required this.boards,
    required this.activeBoardId,
    required this.routines,
    required this.activeRoutineId,
    this.prefs,
    this.dataVersion = 0,
    this.coinNotifier,
    required this.onCreateBoard,
    required this.onOpenEditor,
    required this.onOpenViewer,
    required this.onDeleteBoard,
    this.onStartChallenge,
    this.onViewHabits,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          // 1. Habit progress (unchanged)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: HabitProgressCompletionCard(
              onTap: onViewHabits,
              onStartChallenge: onStartChallenge,
              dataVersion: dataVersion,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 2. Mood banner (full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: const MoodTrackerCard(),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 3. Insights + Water — fixed height row
          // Fixed height avoids IntrinsicHeight + double-layout on every wave animation frame
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(child: InsightsSummaryCard()),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: WaterIntakeCard()),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 4. Rewards slim row (full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: RewardAdsCoinCard(coinNotifier: coinNotifier),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 5. Puzzle (full width)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: PuzzleSummaryCard(),
          ),
        ],
      ),
    );
  }
}
