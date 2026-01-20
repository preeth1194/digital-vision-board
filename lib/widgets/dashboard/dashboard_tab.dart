import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import 'vision_board_preview_card.dart';
import 'puzzle_widget.dart';

class DashboardTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final String? activeBoardId;
  final SharedPreferences? prefs;
  final VoidCallback onCreateBoard;
  final ValueChanged<VisionBoardInfo> onOpenEditor;
  final ValueChanged<VisionBoardInfo> onOpenViewer;
  final ValueChanged<VisionBoardInfo> onDeleteBoard;

  const DashboardTab({
    super.key,
    required this.boards,
    required this.activeBoardId,
    this.prefs,
    required this.onCreateBoard,
    required this.onOpenEditor,
    required this.onOpenViewer,
    required this.onDeleteBoard,
  });

  @override
  Widget build(BuildContext context) {
    if (boards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No vision boards yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreateBoard,
              icon: const Icon(Icons.add),
              label: const Text('New board'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: onCreateBoard,
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                PuzzleWidget(
                  boards: boards,
                  prefs: prefs,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

