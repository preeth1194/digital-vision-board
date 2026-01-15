import 'package:flutter/material.dart';

import '../../models/vision_board_info.dart';

class DashboardTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final String? activeBoardId;
  final VoidCallback onCreateBoard;
  final ValueChanged<VisionBoardInfo> onOpenEditor;
  final ValueChanged<VisionBoardInfo> onOpenViewer;
  final ValueChanged<VisionBoardInfo> onDeleteBoard;

  const DashboardTab({
    super.key,
    required this.boards,
    required this.activeBoardId,
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
              const Expanded(
                child: Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: onCreateBoard,
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: boards.length,
              itemBuilder: (context, i) {
                final b = boards[i];
                final isActive = b.id == activeBoardId;
                final tileColor = Color(b.tileColorValue);
                final iconColor =
                    tileColor.computeLuminance() < 0.45 ? Colors.white : Colors.black87;
                final iconData = boardIconFromCodePoint(b.iconCodePoint);

                return Card(
                  color: tileColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(b.title),
                    subtitle: isActive ? const Text('Selected') : null,
                    leading: Icon(iconData, color: iconColor),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit),
                          onPressed: () => onOpenEditor(b),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => onDeleteBoard(b),
                        ),
                      ],
                    ),
                    onTap: () => onOpenViewer(b),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

