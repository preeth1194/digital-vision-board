import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import '../models/habit_item.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import '../models/image_component.dart';
import '../services/grid_tiles_storage_service.dart';
import '../services/vision_board_components_storage_service.dart';
import '../services/logical_date_service.dart';
import '../services/sync_service.dart';
import 'habit_timer_screen.dart';
import '../widgets/dialogs/completion_feedback_sheet.dart';
import '../widgets/vision_board/component_image.dart';

class VisionBoardHomeFront extends StatelessWidget {
  final VisionBoardInfo board;
  const VisionBoardHomeFront({super.key, required this.board});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: board.layoutType == VisionBoardInfo.layoutGrid
            ? _GridBoardPreview(boardId: board.id)
            : _LayerBoardCoverPreview(boardId: board.id),
      ),
    );
  }
}

class VisionBoardHomeBack extends StatefulWidget {
  final VisionBoardInfo board;
  const VisionBoardHomeBack({super.key, required this.board});

  @override
  State<VisionBoardHomeBack> createState() => _VisionBoardHomeBackState();
}

class _VisionBoardHomeBackState extends State<VisionBoardHomeBack> {
  bool _loading = true;
  SharedPreferences? _prefs;

  // For grid boards, we keep tiles so we can persist edits back.
  List<GridTileModel> _tiles = const [];

  // For non-grid boards.
  List<VisionComponent> _components = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _prefs = prefs;

    if (widget.board.layoutType == VisionBoardInfo.layoutGrid) {
      final tiles = await GridTilesStorageService.loadTiles(widget.board.id, prefs: prefs);
      if (!mounted) return;
      setState(() {
        _tiles = tiles;
        _components = const [];
        _loading = false;
      });
      return;
    }

    final comps = await VisionBoardComponentsStorageService.loadComponents(widget.board.id, prefs: prefs);
    if (!mounted) return;
    setState(() {
      _tiles = const [];
      _components = comps;
      _loading = false;
    });
  }

  List<VisionComponent> _componentsFromGridTiles(List<GridTileModel> tiles) {
    final comps = <VisionComponent>[];
    for (final t in tiles) {
      if (t.type == 'empty') continue;
      comps.add(
        ImageComponent(
          id: t.id,
          position: Offset.zero,
          size: const Size(1, 1),
          rotation: 0,
          scale: 1,
          zIndex: t.index,
          imagePath: (t.type == 'image') ? (t.content ?? '') : '',
          goal: t.goal,
          habits: t.habits,
          tasks: t.tasks,
        ),
      );
    }
    return comps;
  }

  Future<void> _persistUpdatedComponents(List<VisionComponent> updated) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;

    if (widget.board.layoutType == VisionBoardInfo.layoutGrid) {
      // Write habits back onto tiles by id.
      final byId = <String, VisionComponent>{for (final c in updated) c.id: c};
      final nextTiles = _tiles.map((t) {
        final c = byId[t.id];
        if (c == null) return t;
        final img = c is ImageComponent ? c : null;
        return t.copyWith(
          goal: img?.goal ?? t.goal,
          habits: c.habits,
          tasks: c.tasks,
        );
      }).toList();
      final normalized = await GridTilesStorageService.saveTiles(widget.board.id, nextTiles, prefs: prefs);
      if (!mounted) return;
      setState(() => _tiles = normalized);
      return;
    }

    await VisionBoardComponentsStorageService.saveComponents(widget.board.id, updated, prefs: prefs);
    if (!mounted) return;
    setState(() => _components = updated);
  }

  Future<void> _toggleHabit(String componentId, HabitItem habit) async {
    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return;
    final iso = LogicalDateService.toIsoDate(now);
    final wasDone = habit.isCompletedForCurrentPeriod(now);

    final baseComponents =
        widget.board.layoutType == VisionBoardInfo.layoutGrid ? _componentsFromGridTiles(_tiles) : _components;

    // 1) Toggle completion locally (this may remove today's feedback if unchecking).
    var nextComponents = baseComponents.map((c) {
      if (c.id != componentId) return c;
      final nextHabits = c.habits.map((h) => h.id == habit.id ? h.toggleForDate(now) : h).toList();
      return c.copyWithCommon(habits: nextHabits);
    }).toList();

    await _persistUpdatedComponents(nextComponents);

    // 2) Sync event (best-effort).
    Future<void>(() async {
      await SyncService.enqueueHabitCompletion(
        boardId: widget.board.id,
        componentId: componentId,
        habitId: habit.id,
        logicalDate: iso,
        deleted: wasDone,
      );
    });

    // 3) If newly completed, prompt for rating and save feedback.
    if (!wasDone) {
      final res = await showCompletionFeedbackSheet(
        context,
        title: 'How did it go?',
        subtitle: habit.name,
      );
      if (res == null) return;

      // Re-read latest state in case it changed while sheet was open.
      final latestComponents = widget.board.layoutType == VisionBoardInfo.layoutGrid
          ? _componentsFromGridTiles(_tiles)
          : _components;

      nextComponents = latestComponents.map((c) {
        if (c.id != componentId) return c;
        final nextHabits = c.habits.map((h) {
          if (h.id != habit.id) return h;
          final nextFeedback = Map<String, HabitCompletionFeedback>.from(h.feedbackByDate);
          nextFeedback[iso] = HabitCompletionFeedback(rating: res.rating, note: res.note);
          return h.copyWith(feedbackByDate: nextFeedback);
        }).toList();
        return c.copyWithCommon(habits: nextHabits);
      }).toList();

      await _persistUpdatedComponents(nextComponents);

      Future<void>(() async {
        await SyncService.enqueueHabitCompletion(
          boardId: widget.board.id,
          componentId: componentId,
          habitId: habit.id,
          logicalDate: iso,
          rating: res.rating,
          note: res.note,
          deleted: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _PendingHabitsToday(
              board: widget.board,
              components: widget.board.layoutType == VisionBoardInfo.layoutGrid
                  ? _componentsFromGridTiles(_tiles)
                  : _components,
              onToggleHabit: _toggleHabit,
            ),
    );
  }
}

Future<VisionBoardInfo?> showBoardPickerSheet(
  BuildContext context, {
  required List<VisionBoardInfo> boards,
  required String? activeBoardId,
}) {
  return showModalBottomSheet<VisionBoardInfo>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text('Set default board', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final b in boards)
            ListTile(
              leading: Icon(Icons.dashboard_outlined),
              title: Text(b.title),
              subtitle: (b.id == activeBoardId) ? const Text('Default') : null,
              trailing: (b.id == activeBoardId) ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(ctx).pop(b),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class _GridBoardPreview extends StatefulWidget {
  final String boardId;
  const _GridBoardPreview({required this.boardId});

  @override
  State<_GridBoardPreview> createState() => _GridBoardPreviewState();
}

class _GridBoardPreviewState extends State<_GridBoardPreview> {
  bool _loading = true;
  List<GridTileModel> _tiles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tiles = await GridTilesStorageService.loadTiles(widget.boardId);
    if (!mounted) return;
    setState(() {
      _tiles = tiles;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tiles.isEmpty) return const Center(child: Text('No tiles yet.'));

    // Lightweight 4-column preview. Tile sizing uses the stored tile spans.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = (constraints.maxWidth / 4).clamp(10.0, 2000.0);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _tiles.take(12))
              SizedBox(
                width: (t.crossAxisCellCount * cellW) - 8,
                height: (t.mainAxisCellCount * cellW) - 8,
                child: _PreviewTile(tile: t),
              ),
          ],
        );
      },
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final GridTileModel tile;
  const _PreviewTile({required this.tile});

  @override
  Widget build(BuildContext context) {
    final goalTitle = (tile.goal?.title ?? '').trim();
    final category = (tile.goal?.category ?? '').trim();
    final path = (tile.type == 'image') ? (tile.content ?? '').trim() : '';
    final hasImage = path.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        color: Colors.black12.withOpacity(0.05),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category.isNotEmpty)
            Text(
              category,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasImage
                  ? componentImageForPath(path)
                  : Container(
                      color: Colors.black12.withOpacity(0.08),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, color: Colors.black45),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            goalTitle.isEmpty ? tile.id : goalTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LayerBoardCoverPreview extends StatefulWidget {
  final String boardId;
  const _LayerBoardCoverPreview({required this.boardId});

  @override
  State<_LayerBoardCoverPreview> createState() => _LayerBoardCoverPreviewState();
}

class _LayerBoardCoverPreviewState extends State<_LayerBoardCoverPreview> {
  bool _loading = true;
  List<VisionComponent> _components = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final comps = await VisionBoardComponentsStorageService.loadComponents(widget.boardId);
    if (!mounted) return;
    setState(() {
      _components = comps;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final cover = _components.whereType<ImageComponent>().cast<ImageComponent?>().firstWhere(
          (c) => (c?.imagePath ?? '').trim().isNotEmpty,
          orElse: () => null,
        );
    final path = (cover?.imagePath ?? '').trim();
    if (path.isEmpty) return const Center(child: Text('No images yet.'));

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: componentImageForPath(path),
    );
  }
}

class _PendingHabitsToday extends StatelessWidget {
  final VisionBoardInfo board;
  final List<VisionComponent> components;
  final Future<void> Function(String componentId, HabitItem habit) onToggleHabit;

  const _PendingHabitsToday({
    required this.board,
    required this.components,
    required this.onToggleHabit,
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _toIsoDate(DateTime d) => LogicalDateService.toIsoDate(d);

  static Color _colorForRating(int? rating) {
    if (rating == null) return Colors.grey[300]!;
    if (rating >= 4) return Colors.green.shade700;
    if (rating >= 3) return Colors.green.shade400;
    return Colors.green.shade200;
  }

  List<Map<String, Object?>> _last7DaysCells(HabitItem habit) {
    final now = LogicalDateService.now();
    final out = <Map<String, Object?>>[];
    for (int i = 6; i >= 0; i--) {
      final d = _dateOnly(now.subtract(Duration(days: i)));
      final iso = _toIsoDate(d);
      final rating = habit.feedbackByDate[iso]?.rating;
      out.add({'iso': iso, 'rating': rating});
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final now = LogicalDateService.now();
    final todayIso = _toIsoDate(now);

    final items = <({String componentId, HabitItem habit})>[];
    final pendingItems = <({String componentId, HabitItem habit})>[];
    for (final c in components) {
      for (final h in c.habits) {
        if (!h.isScheduledOnDate(now)) continue;
        final it = (componentId: c.id, habit: h);
        items.add(it);
        if (!h.isCompletedForCurrentPeriod(now)) {
          pendingItems.add(it);
        }
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'No habits scheduled today',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                todayIso,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    final headerLabel = pendingItems.isEmpty ? 'All habits are completed' : 'Pending habits today';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                headerLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(todayIso, style: const TextStyle(color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 12),
        // 2-pane layout: left = checklist column, right = 7-day moodboard column.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        'Habits',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Last week momentum',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 6),
                // Keep both columns perfectly aligned by using a fixed row height.
                // The whole card scrolls as part of the outer ListView (no nested scroll).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          for (final it in items) ...[
                            // Compute completion at render time so completed habits remain visible.
                            // (This also keeps the checkbox state consistent after toggles.)
                            SizedBox(
                              height: 56,
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: it.habit.isCompletedForCurrentPeriod(now),
                                    onChanged: (_) => onToggleHabit(it.componentId, it.habit),
                                  ),
                                  Expanded(
                                    child: Text(
                                      it.habit.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (it.habit.timeBound?.enabled == true)
                                    IconButton(
                                      tooltip: 'Timer',
                                      icon: const Icon(Icons.timer_outlined),
                                      onPressed: () async {
                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => HabitTimerScreen(
                                              habit: it.habit,
                                              onMarkCompleted: () async {
                                                // Delegate completion to the owning screen so it can persist + sync.
                                                await onToggleHabit(it.componentId, it.habit);
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          for (final it in items) ...[
                            SizedBox(
                              height: 56,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: _last7DaysCells(it.habit).map((e) {
                                    final rating = e['rating'] as int?;
                                    final color = _colorForRating(rating);
                                    return Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

