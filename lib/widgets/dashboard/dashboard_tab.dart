import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../models/routine.dart';
import 'affirmation_summary_card.dart';
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Habit progress completion
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HabitProgressCompletionCard(
              onTap: onViewHabits,
              onStartChallenge: onStartChallenge,
              dataVersion: dataVersion,
            ),
          ),
          const SizedBox(height: 12),
          // Row 1: Insights | Mood
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: InsightsSummaryCard()),
                  const SizedBox(width: 12),
                  Expanded(child: MoodTrackerCard()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Row 2: Water + Reward ads
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: WaterIntakeCard()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RewardAdsCoinCard(coinNotifier: coinNotifier),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Row 3: Puzzle (height follows puzzle / image content)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: PuzzleSummaryCard(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AffirmationSummaryCard(),
          ),
        ],
      ),
    );
  }
}
