import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../models/routine.dart';
import '../../utils/app_typography.dart';
import 'vision_board_preview_card.dart';
import 'routine_preview_card.dart';
import 'puzzle_widget.dart';
import 'section_carousel.dart';

class DashboardTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final String? activeBoardId;
  final List<Routine> routines;
  final String? activeRoutineId;
  final SharedPreferences? prefs;
  final VoidCallback onCreateBoard;
  final VoidCallback onCreateRoutine;
  final ValueChanged<VisionBoardInfo> onOpenEditor;
  final ValueChanged<VisionBoardInfo> onOpenViewer;
  final ValueChanged<VisionBoardInfo> onDeleteBoard;
  final ValueChanged<Routine> onOpenRoutine;
  final ValueChanged<Routine> onEditRoutine;
  final ValueChanged<Routine> onDeleteRoutine;

  const DashboardTab({
    super.key,
    required this.boards,
    required this.activeBoardId,
    required this.routines,
    required this.activeRoutineId,
    this.prefs,
    required this.onCreateBoard,
    required this.onCreateRoutine,
    required this.onOpenEditor,
    required this.onOpenViewer,
    required this.onDeleteBoard,
    required this.onOpenRoutine,
    required this.onEditRoutine,
    required this.onDeleteRoutine,
  });

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Build vision board cards
    final visionBoardCards = boards.map((b) {
      return VisionBoardPreviewCard(
        board: b,
        activeBoardId: activeBoardId,
        prefs: prefs,
        onTap: () => onOpenViewer(b),
        onEdit: () => onOpenEditor(b),
        onDelete: () => onDeleteBoard(b),
      );
    }).toList();

    // Build routine cards
    final routineCards = routines.map((r) {
      return RoutinePreviewCard(
        routine: r,
        activeRoutineId: activeRoutineId,
        prefs: prefs,
        onTap: () => onOpenRoutine(r),
        onEdit: () => onEditRoutine(r),
        onDelete: () => onDeleteRoutine(r),
      );
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vision Boards Section
          SectionCarousel(
            title: 'Vision Boards',
            items: visionBoardCards,
            height: null, // Let cards determine height
            emptyState: _buildEmptyState(
              'No Vision Boards',
              'Create your first vision board to get started',
              Icons.dashboard_outlined,
            ),
          ),
          const SizedBox(height: 24),

          // Routines Section
          SectionCarousel(
            title: 'Routines',
            items: routineCards,
            height: null, // Let cards determine height
            emptyState: _buildEmptyState(
              'No Routines',
              'Create your first routine to organize your daily tasks',
              Icons.list_alt,
            ),
          ),
          const SizedBox(height: 24),

          // Puzzle Section (only show if there are vision boards)
          if (boards.isNotEmpty) ...[
            SectionCarousel(
              title: 'Puzzle Challenge',
              items: [
                PuzzleWidget(
                  boards: boards,
                  prefs: prefs,
                ),
              ],
              height: null,
              emptyState: _buildEmptyState(
                'No Puzzle Available',
                'Add goal images to your vision boards to unlock puzzle challenges',
                Icons.extension,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

