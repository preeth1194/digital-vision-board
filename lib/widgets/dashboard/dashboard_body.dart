import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../models/routine.dart';
import '../../models/grid_tile_model.dart';
import '../../models/vision_components.dart';
import '../../services/grid_tiles_storage_service.dart';
import '../../services/vision_board_components_storage_service.dart';
import '../../screens/journal_notes_screen.dart';
import '../../screens/habits_list_screen.dart';
import '../../screens/todos_list_screen.dart';
import '../../screens/daily_overview_screen.dart';
import '../../screens/affirmation_screen.dart';
import 'all_boards_habits_tab.dart';
import 'all_boards_todos_tab.dart';
import 'dashboard_tab.dart';
import '../../screens/global_insights_screen.dart';

class DashboardBody extends StatelessWidget {
  final int tabIndex;
  final List<VisionBoardInfo> boards;
  final String? activeBoardId;
  final List<Routine> routines;
  final String? activeRoutineId;
  final SharedPreferences? prefs;
  final ValueNotifier<int> boardDataVersion;

  final VoidCallback onCreateBoard;
  final VoidCallback onCreateRoutine;
  final ValueChanged<VisionBoardInfo> onOpenEditor;
  final ValueChanged<VisionBoardInfo> onOpenViewer;
  final ValueChanged<VisionBoardInfo> onDeleteBoard;
  final ValueChanged<Routine> onOpenRoutine;
  final ValueChanged<Routine> onEditRoutine;
  final ValueChanged<Routine> onDeleteRoutine;

  const DashboardBody({
    super.key,
    required this.tabIndex,
    required this.boards,
    required this.activeBoardId,
    required this.routines,
    required this.activeRoutineId,
    required this.prefs,
    required this.boardDataVersion,
    required this.onCreateBoard,
    required this.onCreateRoutine,
    required this.onOpenEditor,
    required this.onOpenViewer,
    required this.onDeleteBoard,
    required this.onOpenRoutine,
    required this.onEditRoutine,
    required this.onDeleteRoutine,
  });

  VisionBoardInfo? _boardById(String id) {
    return boards.cast<VisionBoardInfo?>().firstWhere((b) => b?.id == id, orElse: () => null);
  }

  List<VisionComponent> _componentsFromGridTiles(List<GridTileModel> tiles) {
    final comps = <VisionComponent>[];
    for (final t in tiles) {
      if (t.type == 'empty') continue;
      comps.add(
        ImageComponent(
          id: t.id, // stable id for persistence
          position: Offset.zero,
          size: const Size(1, 1),
          rotation: 0,
          scale: 1,
          zIndex: t.index,
          imagePath: (t.type == 'image') ? (t.content ?? '') : '',
          goal: t.goal,
          habits: t.habits,
        ),
      );
    }
    return comps;
  }

  Future<List<VisionComponent>> _loadBoardComponents(VisionBoardInfo board) async {
    if (board.layoutType == VisionBoardInfo.layoutGrid) {
      final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: prefs);
      return _componentsFromGridTiles(tiles);
    }
    return VisionBoardComponentsStorageService.loadComponents(board.id, prefs: prefs);
  }

  Future<void> _saveBoardComponents(VisionBoardInfo board, List<VisionComponent> updated) async {
    if (board.layoutType == VisionBoardInfo.layoutGrid) {
      final existingTiles = await GridTilesStorageService.loadTiles(board.id, prefs: prefs);
      final byId = <String, VisionComponent>{for (final c in updated) c.id: c};
      final nextTiles = existingTiles.map((t) {
        final c = byId[t.id];
        if (c == null) return t;
        final img = c is ImageComponent ? c : null;
        return t.copyWith(
          goal: img?.goal ?? t.goal,
          habits: c.habits,
        );
      }).toList();
      await GridTilesStorageService.saveTiles(board.id, nextTiles, prefs: prefs);
      boardDataVersion.value = boardDataVersion.value + 1;
      return;
    }
    await VisionBoardComponentsStorageService.saveComponents(board.id, updated, prefs: prefs);
    boardDataVersion.value = boardDataVersion.value + 1;
  }

  Future<Map<String, List<VisionComponent>>> _loadAllBoardsComponents() async {
    final results = <String, List<VisionComponent>>{};
    for (final b in boards) {
      results[b.id] = await _loadBoardComponents(b);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final boardId = activeBoardId;
    final activeBoard = (boardId == null) ? null : _boardById(boardId);
    // Force reload of board components across tabs whenever board data changes.
    return ValueListenableBuilder<int>(
      valueListenable: boardDataVersion,
      builder: (context, _, __) {
        return switch (tabIndex) {
      1 => DashboardTab(
          boards: boards,
          activeBoardId: activeBoardId,
          routines: routines,
          activeRoutineId: activeRoutineId,
          prefs: prefs,
          onCreateBoard: onCreateBoard,
          onCreateRoutine: onCreateRoutine,
          onOpenEditor: onOpenEditor,
          onOpenViewer: onOpenViewer,
          onDeleteBoard: onDeleteBoard,
          onOpenRoutine: onOpenRoutine,
          onEditRoutine: onEditRoutine,
          onDeleteRoutine: onDeleteRoutine,
        ),
      2 => const JournalNotesScreen(embedded: true),
      3 => AffirmationScreen(prefs: prefs),
      5 when boardId != null && activeBoard != null => FutureBuilder<List<VisionComponent>>(
          future: _loadBoardComponents(activeBoard),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return TodosListScreen(
              components: snap.data ?? const <VisionComponent>[],
              onComponentsUpdated: (updated) => _saveBoardComponents(activeBoard, updated),
              onOpenComponent: (_) async {},
              showAppBar: false,
            );
          },
        ),
      5 => FutureBuilder<Map<String, List<VisionComponent>>>(
          future: _loadAllBoardsComponents(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return AllBoardsTodosTab(
              boards: boards,
              componentsByBoardId: Map<String, List<VisionComponent>>.from(snap.data!),
              onSaveBoardComponents: (id, updated) async {
                final b = _boardById(id);
                if (b == null) return;
                await _saveBoardComponents(b, updated);
              },
            );
          },
        ),
      4 when boardId != null && activeBoard != null => FutureBuilder<List<VisionComponent>>(
          future: _loadBoardComponents(activeBoard),
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
      },
    );
  }
}

