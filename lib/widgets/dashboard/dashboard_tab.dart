import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../models/routine.dart';
import 'affirmation_summary_card.dart';
import 'challenge_progress_card.dart';
import 'puzzle_summary_card.dart';
import 'insights_summary_card.dart';
import 'mood_tracker_card.dart';
import 'vision_board_summary_card.dart';

class DashboardTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final String? activeBoardId;
  final List<Routine> routines;
  final String? activeRoutineId;
  final SharedPreferences? prefs;
  final int dataVersion;
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
          // Challenge progress (or start prompt)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ChallengeProgressCard(dataVersion: dataVersion, onStartChallenge: onStartChallenge, onViewHabits: onViewHabits),
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
          // Row 2: Vision Board | Puzzle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: VisionBoardSummaryCard(
                      onCreateBoard: onCreateBoard,
                      onOpenEditor: onOpenEditor,
                      onOpenViewer: onOpenViewer,
                      onDeleteBoard: onDeleteBoard,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: PuzzleSummaryCard()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Affirmation (full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AffirmationSummaryCard(),
          ),
        ],
      ),
    );
  }
}
