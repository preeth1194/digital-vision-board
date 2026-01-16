import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';
import '../../services/vision_board_components_storage_service.dart';
import '../../screens/habits_list_screen.dart';
import '../../screens/tasks_list_screen.dart';
import 'all_boards_habits_tab.dart';
import 'all_boards_tasks_tab.dart';
import 'dashboard_tab.dart';
import '../../screens/global_insights_screen.dart';

class DashboardBody extends StatelessWidget {
  final int tabIndex;
  final List<VisionBoardInfo> boards;
  final String? activeBoardId;
  final SharedPreferences? prefs;

  final VoidCallback onCreateBoard;
  final ValueChanged<VisionBoardInfo> onOpenEditor;
  final ValueChanged<VisionBoardInfo> onOpenViewer;
  final ValueChanged<VisionBoardInfo> onDeleteBoard;

  const DashboardBody({
    super.key,
    required this.tabIndex,
    required this.boards,
    required this.activeBoardId,
    required this.prefs,
    required this.onCreateBoard,
    required this.onOpenEditor,
    required this.onOpenViewer,
    required this.onDeleteBoard,
  });

  Future<Map<String, List<VisionComponent>>> _loadAllBoardsComponents() async {
    final results = <String, List<VisionComponent>>{};
    for (final b in boards) {
      results[b.id] = await VisionBoardComponentsStorageService.loadComponents(b.id, prefs: prefs);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final boardId = activeBoardId;
    return switch (tabIndex) {
      0 => DashboardTab(
          boards: boards,
          activeBoardId: activeBoardId,
          onCreateBoard: onCreateBoard,
          onOpenEditor: onOpenEditor,
          onOpenViewer: onOpenViewer,
          onDeleteBoard: onDeleteBoard,
        ),
      1 when boardId != null => FutureBuilder<List<VisionComponent>>(
          future: VisionBoardComponentsStorageService.loadComponents(boardId, prefs: prefs),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return HabitsListScreen(
              components: snap.data ?? const <VisionComponent>[],
              onComponentsUpdated: (updated) =>
                  VisionBoardComponentsStorageService.saveComponents(boardId, updated, prefs: prefs),
            );
          },
        ),
      1 => FutureBuilder<Map<String, List<VisionComponent>>>(
          future: _loadAllBoardsComponents(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return AllBoardsHabitsTab(
              boards: boards,
              componentsByBoardId: Map<String, List<VisionComponent>>.from(snap.data!),
              onSaveBoardComponents: (id, updated) =>
                  VisionBoardComponentsStorageService.saveComponents(id, updated, prefs: prefs),
            );
          },
        ),
      2 when boardId != null => FutureBuilder<List<VisionComponent>>(
          future: VisionBoardComponentsStorageService.loadComponents(boardId, prefs: prefs),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return TasksListScreen(
              components: snap.data ?? const <VisionComponent>[],
              onComponentsUpdated: (updated) =>
                  VisionBoardComponentsStorageService.saveComponents(boardId, updated, prefs: prefs),
              showAppBar: false,
            );
          },
        ),
      2 => FutureBuilder<Map<String, List<VisionComponent>>>(
          future: _loadAllBoardsComponents(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return AllBoardsTasksTab(
              boards: boards,
              componentsByBoardId: Map<String, List<VisionComponent>>.from(snap.data!),
              onSaveBoardComponents: (id, updated) =>
                  VisionBoardComponentsStorageService.saveComponents(id, updated, prefs: prefs),
            );
          },
        ),
      _ when boardId != null => FutureBuilder<List<VisionComponent>>(
          future: VisionBoardComponentsStorageService.loadComponents(boardId, prefs: prefs),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return GlobalInsightsScreen(components: snap.data ?? const <VisionComponent>[]);
          },
        ),
      _ => FutureBuilder<Map<String, List<VisionComponent>>>(
          future: _loadAllBoardsComponents(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final all = <VisionComponent>[];
            for (final list in snap.data!.values) {
              all.addAll(list);
            }
            return GlobalInsightsScreen(components: all);
          },
        ),
    };
  }
}

