import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../models/routine.dart';
import '../../utils/app_typography.dart';
import 'vision_board_preview_card.dart';
import 'routine_preview_card.dart';
import 'puzzle_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Create buttons widget
    Widget createButtonsGrid() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: GridView.count(
          crossAxisCount: 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          childAspectRatio: 3.5,
          children: [
            // Vision Board button
            FilledButton.icon(
              onPressed: onCreateBoard,
              icon: const Icon(Icons.dashboard_outlined, size: 18),
              label: const Text(
                'Create Vision Board',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            // Routine button
            FilledButton.icon(
              onPressed: onCreateRoutine,
              icon: const Icon(Icons.list_alt, size: 18),
              label: const Text(
                'Create Routine',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (boards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Get started',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            createButtonsGrid(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          createButtonsGrid(),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                // Vision Boards
                if (boards.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Vision Boards',
                      style: AppTypography.heading3(context),
                    ),
                  ),
                  ...boards.map((b) {
                    return VisionBoardPreviewCard(
                      board: b,
                      activeBoardId: activeBoardId,
                      prefs: prefs,
                      onTap: () => onOpenViewer(b),
                      onEdit: () => onOpenEditor(b),
                      onDelete: () => onDeleteBoard(b),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
                // Routines
                if (routines.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Routines',
                      style: AppTypography.heading3(context),
                    ),
                  ),
                  ...routines.map((r) {
                    return RoutinePreviewCard(
                      routine: r,
                      activeRoutineId: activeRoutineId,
                      prefs: prefs,
                      onTap: () => onOpenRoutine(r),
                      onEdit: () => onEditRoutine(r),
                      onDelete: () => onDeleteRoutine(r),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
                PuzzleWidget(
                  boards: boards,
                  prefs: prefs,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

