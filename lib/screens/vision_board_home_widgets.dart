import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import '../models/habit_item.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import '../models/image_component.dart';
import '../models/goal_overlay_component.dart';
import '../models/goal_metadata.dart';
import '../services/grid_tiles_storage_service.dart';
import '../services/vision_board_components_storage_service.dart';
import '../services/logical_date_service.dart';
import '../services/sync_service.dart';
import '../services/micro_habit_storage_service.dart';
import '../services/overall_streak_storage_service.dart';
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
    final showCategoryLine = category.isNotEmpty && goalTitle.isNotEmpty;
    final displayTitle = goalTitle.isNotEmpty ? goalTitle : (category.isNotEmpty ? category : 'Goal');
    final path = (tile.type == 'image') ? (tile.content ?? '').trim() : '';
    final hasImage = path.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
        ),
        color: Theme.of(context).colorScheme.outline.withOpacity(0.05),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCategoryLine)
            Text(
              category,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayTitle,
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

class _PendingHabitsToday extends StatefulWidget {
  final VisionBoardInfo board;
  final List<VisionComponent> components;
  final Future<void> Function(String componentId, HabitItem habit) onToggleHabit;

  const _PendingHabitsToday({
    required this.board,
    required this.components,
    required this.onToggleHabit,
  });

  @override
  State<_PendingHabitsToday> createState() => _PendingHabitsTodayState();
}

class _PendingHabitsTodayState extends State<_PendingHabitsToday> {
  SharedPreferences? _prefs;
  String? _selectedMicroHabit;
  bool _microHabitCompleted = false;
  int _overallStreak = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_PendingHabitsToday oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when components change (e.g., after habit toggle)
    if (oldWidget.components != widget.components) {
      _updateStreak();
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _prefs = prefs;
    
    final now = LogicalDateService.now();
    final todayIso = LogicalDateService.toIsoDate(now);
    
    // Load selected micro habit
    final selected = await MicroHabitStorageService.loadSelectedMicroHabit(todayIso, prefs: prefs);
    final completed = await MicroHabitStorageService.isMicroHabitCompleted(todayIso, prefs: prefs);
    
    // Load overall streak
    final streakData = await OverallStreakStorageService.loadStreak(prefs: prefs);
    
    if (!mounted) return;
    setState(() {
      _selectedMicroHabit = selected;
      _microHabitCompleted = completed;
      _overallStreak = streakData.count;
    });
    
    // Update streak based on current completions
    await _updateStreak();
  }

  Future<void> _updateStreak() async {
    final now = LogicalDateService.now();
    final todayIso = LogicalDateService.toIsoDate(now);
    
    // Check if at least one habit is completed today
    bool hasCompletion = false;
    
    // Check regular habits
    for (final c in widget.components) {
      for (final h in c.habits) {
        if (h.isScheduledOnDate(now) && h.isCompletedForCurrentPeriod(now)) {
          hasCompletion = true;
          break;
        }
      }
      if (hasCompletion) break;
    }
    
    // Check micro habit
    if (!hasCompletion && _microHabitCompleted) {
      hasCompletion = true;
    }
    
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final newStreak = await OverallStreakStorageService.updateStreak(hasCompletion, prefs: prefs);
    
    if (!mounted) return;
    setState(() {
      _overallStreak = newStreak;
    });
  }

  Future<void> _selectMicroHabit() async {
    // Collect all available micro habits from components
    final microHabits = <({String text, String? goalTitle})>[];
    for (final c in widget.components) {
      GoalMetadata? goal;
      if (c is ImageComponent) {
        goal = c.goal;
      } else if (c is GoalOverlayComponent) {
        goal = c.goal;
      }
      final microHabit = goal?.actionPlan?.microHabit?.trim();
      if (microHabit != null && microHabit.isNotEmpty) {
        final goalTitle = (goal?.title ?? '').trim();
        microHabits.add((text: microHabit, goalTitle: goalTitle.isEmpty ? null : goalTitle));
      }
    }
    
    if (microHabits.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No micro habits defined. Add them in goal details.'),
        ),
      );
      return;
    }
    
    // Show bottom sheet to select micro habit
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select micro habit',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: microHabits.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return ListTile(
                      leading: const Icon(Icons.clear),
                      title: const Text('Clear selection'),
                      onTap: () => Navigator.of(ctx).pop(''),
                    );
                  }
                  final mh = microHabits[i - 1];
                  return ListTile(
                    title: Text(mh.text),
                    subtitle: mh.goalTitle != null ? Text('From: ${mh.goalTitle}') : null,
                    onTap: () => Navigator.of(ctx).pop(mh.text),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    
    if (selected == null) return;
    
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final now = LogicalDateService.now();
    final todayIso = LogicalDateService.toIsoDate(now);
    
    if (selected.isEmpty) {
      await MicroHabitStorageService.clearSelectedMicroHabit(todayIso, prefs: prefs);
      await MicroHabitStorageService.unmarkMicroHabitCompleted(todayIso, prefs: prefs);
    } else {
      await MicroHabitStorageService.saveSelectedMicroHabit(todayIso, selected, prefs: prefs);
    }
    
    if (!mounted) return;
    setState(() {
      _selectedMicroHabit = selected.isEmpty ? null : selected;
      if (selected.isEmpty) {
        _microHabitCompleted = false;
      }
    });
    
    await _updateStreak();
  }

  Future<void> _toggleMicroHabitCompletion() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final now = LogicalDateService.now();
    final todayIso = LogicalDateService.toIsoDate(now);
    
    if (_microHabitCompleted) {
      await MicroHabitStorageService.unmarkMicroHabitCompleted(todayIso, prefs: prefs);
    } else {
      await MicroHabitStorageService.markMicroHabitCompleted(todayIso, prefs: prefs);
      // Auto-save rating as 5 (already handled by the feedback sheet behavior)
    }
    
    if (!mounted) return;
    setState(() {
      _microHabitCompleted = !_microHabitCompleted;
    });
    
    await _updateStreak();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _toIsoDate(DateTime d) => LogicalDateService.toIsoDate(d);

  @override
  Widget build(BuildContext context) {
    final now = LogicalDateService.now();
    final todayIso = _toIsoDate(now);

    final items = <({String componentId, HabitItem habit})>[];
    final pendingItems = <({String componentId, HabitItem habit})>[];
    for (final c in widget.components) {
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
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No habits scheduled today',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                todayIso,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            const SizedBox(width: 12),
            // Overall streak indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _overallStreak > 0
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 18,
                    color: _overallStreak > 0
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_overallStreak',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _overallStreak > 0
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Habits list
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  'Habits',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 6),
                Column(
                  children: [
                    for (final it in items) ...[
                      Container(
                        height: 56,
                        color: (it.habit.locationBound?.enabled == true)
                            ? Theme.of(context).colorScheme.tertiaryContainer
                            : null,
                        child: Row(
                          children: [
                            Checkbox(
                              value: it.habit.isCompletedForCurrentPeriod(now),
                              onChanged: (_) async {
                                await widget.onToggleHabit(it.componentId, it.habit);
                                await _updateStreak();
                              },
                            ),
                            Expanded(
                              child: Text(
                                it.habit.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (it.habit.timeBound?.enabled == true || it.habit.locationBound?.enabled == true)
                              IconButton(
                                tooltip: 'Timer',
                                icon: const Icon(Icons.timer_outlined),
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => HabitTimerScreen(
                                        habit: it.habit,
                                        onMarkCompleted: () async {
                                          await widget.onToggleHabit(it.componentId, it.habit);
                                          await _updateStreak();
                                        },
                                      ),
                                    ),
                                  );
                                  await _updateStreak();
                                },
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Micro habit section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Micro habit',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 6),
                if (_selectedMicroHabit == null)
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _selectMicroHabit,
                      icon: const Icon(Icons.add),
                      label: const Text('Select micro habit'),
                    ),
                  )
                else
                  Container(
                    height: 56,
                    child: Row(
                      children: [
                        Checkbox(
                          value: _microHabitCompleted,
                          onChanged: (_) => _toggleMicroHabitCompletion(),
                        ),
                        Expanded(
                          child: Text(
                            _selectedMicroHabit!,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Change micro habit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: _selectMicroHabit,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

