import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_template.dart';
import '../models/grid_tile_model.dart';
import '../models/goal_metadata.dart';
import '../services/boards_storage_service.dart';
import '../services/grid_tiles_storage_service.dart';
import '../services/habit_storage_service.dart';
import '../services/image_service.dart';
import '../services/stock_images_service.dart';
import '../services/templates_service.dart';
import '../utils/app_colors.dart';
import '../utils/file_image_provider.dart';
import '../widgets/grid/pexels_search_sheet.dart';
import '../widgets/dialogs/add_goal_dialog.dart';
import '../widgets/manipulable/resize_handle.dart';
import '../widgets/grid/image_source_sheet.dart';

/// Template-based grid editor: users pick a layout first, then fill the blanks.
class GridEditorScreen extends StatefulWidget {
  final String boardId;
  final String title;
  final bool initialIsEditing;
  final GridTemplate template;
  /// When true, show a wizard-only AppBar action to proceed (closes editor with `true`).
  final bool wizardShowNext;
  final String wizardNextLabel;
  /// When true, shows an inline board-name field above the grid.
  final bool isNewBoard;

  const GridEditorScreen({
    super.key,
    required this.boardId,
    required this.title,
    required this.initialIsEditing,
    required this.template,
    this.wizardShowNext = false,
    this.wizardNextLabel = 'Next',
    this.isNewBoard = false,
  });

  @override
  State<GridEditorScreen> createState() => _GridEditorScreenState();
}

class _GridEditorScreenState extends State<GridEditorScreen> {
  // Shared pick/compress defaults (kept aligned with freeform editor)
  static const double _pickedImageMaxSide = 2048;
  static const int _pickedImageQuality = 92;
  static const int _crossAxisCount = 4;
  static const int _maxMainAxisCount = 6;

  late bool _isEditing;
  bool _loading = true;
  int? _selectedIndex;
  double _resizeAccumDx = 0;
  double _resizeAccumDy = 0;
  HandlePosition? _selectedResizeHandle;
  int? _draggingIndex;

  SharedPreferences? _prefs;
  List<GridTileModel> _tiles = [];
  int _styleSeed = 0;
  bool _viewportSizingApplied = false;
  double _gridSpacing = 10.0;
  double _tileBorderRadius = 14.0;
  Color? _tileBackgroundColor;
  int? _inlineEditingIndex;
  TextEditingController? _inlineTextC;

  late final TextEditingController _boardNameC;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialIsEditing;
    _boardNameC = TextEditingController(text: widget.title);
    _init();
  }

  @override
  void dispose() {
    _commitInlineEditSync();
    _saveBoardName();
    _boardNameC.dispose();
    super.dispose();
  }

  Future<void> _saveBoardName() async {
    final name = _boardNameC.text.trim();
    if (name == widget.title) return;
    final p = _prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: p);
    if (boards.isEmpty) return;
    final next = boards
        .map((b) => b.id == widget.boardId ? b.copyWith(title: name.isEmpty ? 'Untitled' : name) : b)
        .toList();
    await BoardsStorageService.saveBoards(next, prefs: p);
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _styleSeed = _prefs?.getInt(BoardsStorageService.boardGridStyleSeedKey(widget.boardId)) ?? 0;
    if (_styleSeed == 0) {
      _styleSeed = DateTime.now().millisecondsSinceEpoch;
      await _prefs?.setInt(BoardsStorageService.boardGridStyleSeedKey(widget.boardId), _styleSeed);
    }
    _gridSpacing = _prefs?.getDouble(BoardsStorageService.boardGridCompactSpacingKey(widget.boardId)) ?? 10.0;
    _tileBorderRadius = _prefs?.getDouble(BoardsStorageService.boardGridBorderRadiusKey(widget.boardId)) ?? 14.0;
    final savedBgColor = _prefs?.getInt(BoardsStorageService.boardGridTileBgColorKey(widget.boardId));
    _tileBackgroundColor = savedBgColor != null ? Color(savedBgColor) : null;
    _viewportSizingApplied = _prefs?.getBool(BoardsStorageService.boardGridViewportSizedKey(widget.boardId)) ?? false;
    final loaded = await GridTilesStorageService.loadTiles(widget.boardId, prefs: _prefs);
    final hydrated = _ensureTemplateTiles(loaded);
    final sorted = GridTilesStorageService.sortTiles(hydrated);
    await GridTilesStorageService.saveTiles(widget.boardId, sorted, prefs: _prefs);
    if (!mounted) return;
    setState(() {
      _tiles = sorted;
      _loading = false;
    });
  }

  int _hash32(String s) {
    // Simple deterministic hash (not cryptographic).
    int h = 0x811c9dc5;
    for (int i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  TextStyle _placeholderTextStyle(BuildContext context, GridTileModel tile) {
    final v = _hash32('${tile.id}::$_styleSeed');
    final weights = <FontWeight>[
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w500,
    ];
    final weight = weights[v % weights.length];
    final italic = (v % 5) == 0;
    final size = 14.0 + ((v % 5) * 2.0);
    final letter = ((v % 3) - 1) * 0.4; // -0.4, 0, 0.4
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: letter,
      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.9),
    );
  }

  Future<void> _shuffleGrid() async {
    if (!_isEditing) return;
    if (_tiles.isEmpty) return;

    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    final nextTpl = GridTemplates.all[rng.nextInt(GridTemplates.all.length)];

    // New seed => new placeholder typography.
    final nextSeed = DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt(BoardsStorageService.boardGridStyleSeedKey(widget.boardId), nextSeed);
    _styleSeed = nextSeed;

    // Apply new tile sizes from template; keep goal/user content and tile count.
    final nextTiles = <GridTileModel>[];
    for (int i = 0; i < _tiles.length; i++) {
      final bp = (i < nextTpl.tiles.length)
          ? nextTpl.tiles[i]
          : const GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1);
      nextTiles.add(
        _tiles[i].copyWith(
          crossAxisCellCount: bp.crossAxisCount,
          mainAxisCellCount: bp.mainAxisCount,
        ),
      );
    }

    await BoardsStorageService.updateBoardTemplateId(widget.boardId, nextTpl.id, prefs: _prefs);
    await _saveTiles(nextTiles);
    if (!mounted) return;
    setState(() {
      _selectedResizeHandle = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shuffled layout: ${nextTpl.name}')),
    );
  }

  List<GridTileModel> _ensureTemplateTiles(List<GridTileModel> existing) {
    // Normalize indices. If this board has never been initialized (no saved tiles),
    // seed it from the chosen template. Otherwise, keep the user's current slot count
    // (do NOT enforce a template minimum).
    final sorted = GridTilesStorageService.sortTiles(existing);
    final normalized = <GridTileModel>[];
    for (int i = 0; i < sorted.length; i++) {
      final t = sorted[i];
      normalized.add(t.index == i ? t : t.copyWith(index: i));
    }

    final next = List<GridTileModel>.from(normalized);

    // Do not add extra tiles beyond existing (e.g. one per goal from wizard).

    // Convert any remaining empty tiles to placeholder text tiles
    final finalTiles = next.map((tile) {
      if (tile.type == 'empty') {
        final phrases = ['Dream', 'Focus', 'Progress', 'Today', 'You got this', 'Grow', 'Achieve', 'Believe'];
        final phrase = phrases[tile.index % phrases.length];
        return tile.copyWith(
          type: 'text',
          content: phrase,
          isPlaceholder: true,
        );
      }
      return tile;
    }).toList();

    return GridTilesStorageService.sortTiles(finalTiles);
  }

  Future<void> _saveTiles(List<GridTileModel> tiles) async {
    final normalized = await GridTilesStorageService.saveTiles(
      widget.boardId,
      tiles,
      prefs: _prefs,
    );
    if (!mounted) return;
    setState(() => _tiles = normalized);
  }

  GridTileModel _tileAt(int index) => _tiles.firstWhere((t) => t.index == index);

  GridTileModel? _selectedTile() {
    final i = _selectedIndex;
    if (i == null) return null;
    if (i < 0 || i >= _tiles.length) return null;
    return _tileAt(i);
  }

  Future<void> _setTile(int index, GridTileModel updated) async {
    final next = _tiles.map((t) => t.index == index ? updated : t).toList();
    await _saveTiles(next);
  }

  Future<void> _addTileSlot() async {
    if (!_isEditing) return;
    final id = 'tile_${DateTime.now().millisecondsSinceEpoch}';
    final index = _tiles.length;
    // Create placeholder text tile instead of empty
    final phrases = ['Dream', 'Focus', 'Progress', 'Today', 'You got this', 'Grow', 'Achieve', 'Believe'];
    final phrase = phrases[index % phrases.length];
    final next = [
      ..._tiles,
      GridTileModel(
        id: id,
        type: 'text',
        content: phrase,
        isPlaceholder: true,
        crossAxisCellCount: 1,
        mainAxisCellCount: 1,
        index: index,
      ),
    ];
    await _saveTiles(next);
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  Future<void> _resizeSelected({int deltaW = 0, int deltaH = 0}) async {
    if (!_isEditing) return;
    final tile = _selectedTile();
    if (tile == null) return;
    final nextW = (tile.crossAxisCellCount + deltaW).clamp(1, _crossAxisCount);
    final nextH = (tile.mainAxisCellCount + deltaH).clamp(1, _maxMainAxisCount);
    await _setTile(
      tile.index,
      tile.copyWith(
        crossAxisCellCount: nextW,
        mainAxisCellCount: nextH,
      ),
    );
  }

  void _onResizeDragStart() {
    _resizeAccumDx = 0;
    _resizeAccumDy = 0;
  }

  void _selectResizeHandle(HandlePosition h) {
    if (_selectedResizeHandle == h) return;
    setState(() => _selectedResizeHandle = h);
  }

  void _onResizeHandleStart(HandlePosition h) {
    _selectResizeHandle(h);
    _onResizeDragStart();
  }

  bool _isCornerHandle(HandlePosition? h) {
    return h == HandlePosition.topLeft ||
        h == HandlePosition.topRight ||
        h == HandlePosition.bottomLeft ||
        h == HandlePosition.bottomRight;
  }

  Future<void> _onResizeDragUpdate(
    DragUpdateDetails details, {
    required double cellExtent,
    bool allowW = true,
    bool allowH = true,
    double dxMultiplier = 1,
    double dyMultiplier = 1,
  }) async {
    if (!_isEditing) return;
    if (_selectedIndex == null) return;

    if (allowW) _resizeAccumDx += details.delta.dx * dxMultiplier;
    if (allowH) _resizeAccumDy += details.delta.dy * dyMultiplier;

    // Snap sooner than a full cell so resizing feels responsive.
    // (Handles are small; requiring ~60% of a cell can feel "stuck".)
    final snapExtent = cellExtent * 0.35;

    int deltaW = 0;
    int deltaH = 0;

    if (allowW) {
      while (_resizeAccumDx >= snapExtent) {
        deltaW += 1;
        _resizeAccumDx -= snapExtent;
      }
      while (_resizeAccumDx <= -snapExtent) {
        deltaW -= 1;
        _resizeAccumDx += snapExtent;
      }
    }
    if (allowH) {
      while (_resizeAccumDy >= snapExtent) {
        deltaH += 1;
        _resizeAccumDy -= snapExtent;
      }
      while (_resizeAccumDy <= -snapExtent) {
        deltaH -= 1;
        _resizeAccumDy += snapExtent;
      }
    }

    if (deltaW != 0 || deltaH != 0) {
      await _resizeSelected(deltaW: deltaW, deltaH: deltaH);
    }
  }

  Future<void> _swapTileSlots(int fromIndex, int toIndex) async {
    if (!_isEditing) return;
    if (fromIndex == toIndex) return;
    if (fromIndex < 0 || toIndex < 0) return;
    if (fromIndex >= _tiles.length || toIndex >= _tiles.length) return;

    final fromTile = _tileAt(fromIndex);
    final toTile = _tileAt(toIndex);

    final next = _tiles.map((t) {
      if (t.id == fromTile.id) return t.copyWith(index: toIndex);
      if (t.id == toTile.id) return t.copyWith(index: fromIndex);
      return t;
    }).toList();

    await _saveTiles(next);
    if (!mounted) return;
    setState(() => _selectedIndex = toIndex);
  }

  Size _tilePixelSize(GridTileModel tile, {required double cellExtent, required double spacing}) {
    final w = (tile.crossAxisCellCount * cellExtent) +
        ((tile.crossAxisCellCount - 1).clamp(0, 1000) * spacing);
    final h = (tile.mainAxisCellCount * cellExtent) +
        ((tile.mainAxisCellCount - 1).clamp(0, 1000) * spacing);
    return Size(w, h);
  }

  Future<void> _deleteOrClearTile(int index) async {
    if (!_isEditing) return;
    final t = _tileAt(index);
    final hasContent = t.type != 'empty' && (t.content ?? '').trim().isNotEmpty;
    final hasGoalData = (t.goal?.title ?? '').trim().isNotEmpty || t.hasTrackerData;

    if (hasGoalData) {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove goal?'),
          content: const Text(
            'This will remove the goal from this tile and delete all its habits, tasks, and streak history.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    // If there is content, delete the contents (keep the tile slot).
    if (hasContent) {
      await _clearTile(index);
      return;
    }

    // If no content is found, delete the tile slot.

    final kept = _tiles.where((tile) => tile.index != index).toList();
    final reindexed = <GridTileModel>[];
    for (int i = 0; i < kept.length; i++) {
      reindexed.add(kept[i].index == i ? kept[i] : kept[i].copyWith(index: i));
    }
    await _saveTiles(reindexed);
    if (!mounted) return;
    setState(() {
      _selectedIndex = null;
      _selectedResizeHandle = null;
    });
  }

  Future<void> _pickAndSetImage(int index) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image picking/cropping is not supported on web yet.')),
      );
      return;
    }

    final ImageSource? source = await showImageSourceSheet(context);
    if (!mounted) return;
    if (source == null) return;

    final String? croppedPath = await ImageService.pickAndCropImage(
      context,
      source: source,
      maxWidth: _pickedImageMaxSide,
      maxHeight: _pickedImageMaxSide,
      imageQuality: _pickedImageQuality,
    );
    if (!mounted) return;
    if (croppedPath == null || croppedPath.isEmpty) return;

    await _setTile(index, _tileAt(index).copyWith(type: 'image', content: croppedPath));
  }

  /// Opens Pexels search for the tile and sets the chosen image. No goal-title dialog.
  Future<void> _openPexelsForTile(int index) async {
    if (!_isEditing) return;
    final tile = _tileAt(index);
    final cat = (tile.goal?.category ?? '').trim();
    final cv = (tile.goal?.cbt?.coreValue ?? '').trim();
    final q = [cat, cv, 'minimal', 'simple', 'clean', 'aesthetic'].where((s) => s.trim().isNotEmpty).join(' ');
    final selectedUrl = await showPexelsSearchSheet(context, initialQuery: q.isEmpty ? null : q);
    if (!mounted) return;
    final u = (selectedUrl ?? '').trim();
    if (u.isEmpty) return;
    final saved = await ImageService.downloadResizeAndPersistJpegFromUrl(
      context,
      url: u,
      maxSidePx: _pickedImageMaxSide.toInt(),
      jpegQuality: _pickedImageQuality,
    );
    if (!mounted) return;
    final content = (saved ?? '').trim();
    if (content.isEmpty) return;
    await _setTile(index, _tileAt(index).copyWith(type: 'image', content: content));
  }

  void _editText(int index) {
    if (_inlineEditingIndex != null) _commitInlineEditSync();
    final existing = _tileAt(index);
    final initialText = existing.type == 'text' ? (existing.content ?? '') : '';
    _inlineTextC = TextEditingController(text: initialText);
    setState(() {
      _inlineEditingIndex = index;
      _selectedIndex = index;
    });
  }

  void _commitInlineEditSync() {
    final idx = _inlineEditingIndex;
    final ctrl = _inlineTextC;
    if (idx == null || ctrl == null) return;
    final nextText = ctrl.text.trim();
    final existing = _tileAt(idx);
    _setTile(
      idx,
      existing.copyWith(
        type: nextText.isEmpty ? 'empty' : 'text',
        content: nextText.isEmpty ? null : nextText,
        isPlaceholder: false,
      ),
    );
    ctrl.dispose();
    _inlineTextC = null;
    _inlineEditingIndex = null;
  }

  Future<void> _commitInlineEdit() async {
    final idx = _inlineEditingIndex;
    final ctrl = _inlineTextC;
    if (idx == null || ctrl == null) return;
    final nextText = ctrl.text.trim();
    _inlineEditingIndex = null;
    _inlineTextC = null;
    final existing = _tileAt(idx);
    await _setTile(
      idx,
      existing.copyWith(
        type: nextText.isEmpty ? 'empty' : 'text',
        content: nextText.isEmpty ? null : nextText,
        isPlaceholder: false,
      ),
    );
    ctrl.dispose();
    if (mounted) setState(() {});
  }

  static const List<double> _fontSizeSteps = [12, 14, 16, 18, 20, 24, 28, 32];

  double _currentInlineFontSize() {
    final idx = _inlineEditingIndex;
    if (idx == null) return 16;
    return _tileAt(idx).textFontSize ?? 16;
  }

  String _currentInlineAlign() {
    final idx = _inlineEditingIndex;
    if (idx == null) return 'center';
    return _tileAt(idx).textAlign ?? 'center';
  }

  bool _currentInlineBold() {
    final idx = _inlineEditingIndex;
    if (idx == null) return true;
    return _tileAt(idx).textBold ?? true;
  }

  Future<void> _setInlineFontSize(double size) async {
    final idx = _inlineEditingIndex;
    if (idx == null) return;
    final tile = _tileAt(idx);
    await _setTile(idx, tile.copyWith(textFontSize: size, isPlaceholder: false));
    if (mounted) setState(() {});
  }

  Future<void> _cycleInlineAlign() async {
    final idx = _inlineEditingIndex;
    if (idx == null) return;
    const cycle = ['left', 'center', 'right'];
    final cur = _currentInlineAlign();
    final next = cycle[(cycle.indexOf(cur) + 1) % cycle.length];
    final tile = _tileAt(idx);
    await _setTile(idx, tile.copyWith(textAlign: next, isPlaceholder: false));
    if (mounted) setState(() {});
  }

  Future<void> _toggleInlineBold() async {
    final idx = _inlineEditingIndex;
    if (idx == null) return;
    final tile = _tileAt(idx);
    final newBold = !_currentInlineBold();
    await _setTile(idx, tile.copyWith(textBold: newBold, isPlaceholder: false));
    if (mounted) setState(() {});
  }

  Future<void> _clearTile(int index) async {
    final tile = _tileAt(index);
    await _setTile(
      index,
      tile.copyWith(
        type: 'empty',
        content: null,
        goal: null,
        habits: const [],
        habitIds: const [],
        tasks: const [],
      ),
    );
    // Remove this component's habits from HabitStorageService.
    final existing = await HabitStorageService.getHabitsForComponent(tile.id, prefs: _prefs);
    for (final h in existing) {
      await HabitStorageService.deleteHabit(h.id, prefs: _prefs);
    }
  }

  Future<void> _ensureGoalTitle(int index, {String? suggestedTitle}) async {
    final t = _tileAt(index);
    final hasTitle = (t.goal?.title ?? '').trim().isNotEmpty;
    if (hasTitle) return;

    final categorySuggestions = _tiles
        .map((e) => e.goal?.category)
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final res = await showAddGoalDialog(
      context,
      initialName: suggestedTitle,
      categorySuggestions: categorySuggestions,
      showWhyImportant: true,
      showDeadline: true,
    );
    if (!mounted) return;
    if (res == null || res.name.trim().isEmpty) return;

    final meta = GoalMetadata(
      title: res.name.trim(),
      category: res.category,
      deadline: res.deadline,
      // Note: whyImportant is not stored in GoalMetadata, but we collect it for consistency
      // It could be stored in cbt.visualization if needed in the future
    );
    await _setTile(index, _tileAt(index).copyWith(goal: meta));
  }

  void _promptSelectTile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap a tile first to select it'), duration: Duration(seconds: 2)),
    );
  }

  static const List<Color?> _bgColorOptions = [
    null, // theme default
    Colors.white,
    AppColors.pastelGreen,
    AppColors.pastelBlue,
    AppColors.pastelPurple,
    AppColors.pastelOrange,
    AppColors.pastelPink,
    AppColors.pastelIndigo,
  ];

  Future<void> _openTileStyleSheet() async {
    var spacingVal = _gridSpacing;
    var radiusVal = _tileBorderRadius;
    var bgColor = _tileBackgroundColor;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tile Style', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 20),

                Text('Grid Spacing', style: Theme.of(ctx).textTheme.labelLarge),
                Row(
                  children: [
                    const Text('0'),
                    Expanded(
                      child: Slider(
                        value: spacingVal,
                        min: 0,
                        max: 24,
                        divisions: 12,
                        label: '${spacingVal.round()}px',
                        onChanged: (v) => setLocal(() => spacingVal = v),
                      ),
                    ),
                    const Text('24'),
                  ],
                ),
                const SizedBox(height: 12),

                Text('Border Radius', style: Theme.of(ctx).textTheme.labelLarge),
                Row(
                  children: [
                    const Text('0'),
                    Expanded(
                      child: Slider(
                        value: radiusVal,
                        min: 0,
                        max: 24,
                        divisions: 12,
                        label: '${radiusVal.round()}px',
                        onChanged: (v) => setLocal(() => radiusVal = v),
                      ),
                    ),
                    const Text('24'),
                  ],
                ),
                const SizedBox(height: 12),

                Text('Tile Background', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (int i = 0; i < _bgColorOptions.length; i++)
                      GestureDetector(
                        onTap: () => setLocal(() => bgColor = _bgColorOptions[i]),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _bgColorOptions[i] ?? Theme.of(ctx).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (bgColor == _bgColorOptions[i] ||
                                      (bgColor == null && _bgColorOptions[i] == null))
                                  ? Theme.of(ctx).colorScheme.primary
                                  : Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.3),
                              width: (bgColor == _bgColorOptions[i] ||
                                      (bgColor == null && _bgColorOptions[i] == null))
                                  ? 2.5
                                  : 1,
                            ),
                          ),
                          child: (bgColor == _bgColorOptions[i] ||
                                  (bgColor == null && _bgColorOptions[i] == null))
                              ? Icon(Icons.check, size: 18, color: Theme.of(ctx).colorScheme.primary)
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _gridSpacing = spacingVal;
      _tileBorderRadius = radiusVal;
      _tileBackgroundColor = bgColor;
    });
    await _prefs?.setDouble(BoardsStorageService.boardGridCompactSpacingKey(widget.boardId), spacingVal);
    await _prefs?.setDouble(BoardsStorageService.boardGridBorderRadiusKey(widget.boardId), radiusVal);
    if (bgColor != null) {
      await _prefs?.setInt(BoardsStorageService.boardGridTileBgColorKey(widget.boardId), bgColor!.toARGB32());
    } else {
      await _prefs?.remove(BoardsStorageService.boardGridTileBgColorKey(widget.boardId));
    }
  }

  void _toggleEditMode() {
    _commitInlineEdit();
    final wasEditing = _isEditing;
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _selectedIndex = null;
        _selectedResizeHandle = null;
      }
    });
    if (wasEditing) _saveBoardName();
  }

  Widget _tileChild(GridTileModel tile) {
    final borderRadius = BorderRadius.circular(_tileBorderRadius);
    final isSelected = _isEditing && _selectedIndex == tile.index;
    final goalTitle = (tile.goal?.title ?? '').trim();
    final goalCategory = (tile.goal?.category ?? '').trim();
    final fallbackTitle = tile.type == 'text'
        ? (tile.content ?? '').trim()
        : (tile.type == 'image' ? (goalCategory.isNotEmpty ? goalCategory : 'Goal') : '');
    final title = goalTitle.isNotEmpty ? goalTitle : fallbackTitle;
    final showTitle = title.isNotEmpty && tile.type != 'empty';

    Widget base;
    if (tile.type == 'image') {
      final raw = (tile.content ?? '').trim();
      // Use raw path directly - fileImageProviderFromPath handles both URLs and local paths correctly
      // No need to use absolutizeMaybe here as it can incorrectly convert local paths to server URLs
      final provider = fileImageProviderFromPath(raw);
      base = Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.outline.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : Container(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      );
    } else if (tile.type == 'text') {
      final isInlineEditing = _inlineEditingIndex == tile.index && _inlineTextC != null;
      final tileFont = tile.textFontSize ?? 16.0;
      final tileBold = tile.textBold ?? true;
      final tileAlignStr = tile.textAlign ?? 'center';
      final tileTextAlign = tileAlignStr == 'left'
          ? TextAlign.left
          : tileAlignStr == 'right'
              ? TextAlign.right
              : TextAlign.center;
      final tileAlignment = tileAlignStr == 'left'
          ? Alignment.centerLeft
          : tileAlignStr == 'right'
              ? Alignment.centerRight
              : Alignment.center;
      final textStyle = TextStyle(
        fontSize: tileFont,
        fontWeight: tileBold ? FontWeight.w600 : FontWeight.normal,
        color: Theme.of(context).colorScheme.onSurface,
      );
      base = Container(
        decoration: BoxDecoration(
          color: _tileBackgroundColor ?? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.outline.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        alignment: isInlineEditing ? Alignment.topLeft : tileAlignment,
        child: isInlineEditing
            ? TextField(
                controller: _inlineTextC,
                autofocus: true,
                maxLines: null,
                textAlign: tileTextAlign,
                style: textStyle,
                decoration: const InputDecoration(
                  hintText: 'Enter text',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onSubmitted: (_) => _commitInlineEdit(),
              )
            : Text(
                (tile.content ?? '').trim(),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                textAlign: tileTextAlign,
                style: tile.isPlaceholder 
                    ? _placeholderTextStyle(context, tile) 
                    : textStyle,
              ),
      );
    } else {
      final isInlineEditing = _inlineEditingIndex == tile.index && _inlineTextC != null;
      final colorScheme = Theme.of(context).colorScheme;
      base = Container(
        decoration: BoxDecoration(
          color: _tileBackgroundColor ?? colorScheme.outline.withValues(alpha: 0.08),
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected 
                ? colorScheme.primary 
                : colorScheme.outline.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: isInlineEditing ? Alignment.topLeft : Alignment.center,
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.all(isInlineEditing ? 8 : 4),
        child: isInlineEditing
            ? TextField(
                controller: _inlineTextC,
                autofocus: true,
                maxLines: null,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter text',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onSubmitted: (_) => _commitInlineEdit(),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: colorScheme.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text(
                      'Tap twice\nto add',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
      );
    }

    if (!showTitle) return base;

    return Stack(
      children: [
        Positioned.fill(child: base),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.surface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _applyViewportSizing(BuildContext context) {
    if (_tiles.isEmpty || !mounted) return;
    final size = MediaQuery.of(context).size;
    final blueprints = GridTemplates.optimalSizesForTileCount(
      _tiles.length,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );
    var changed = false;
    final next = <GridTileModel>[];
    for (var i = 0; i < _tiles.length; i++) {
      final t = _tiles[i];
      final bp = i < blueprints.length ? blueprints[i] : const GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1);
      if (t.crossAxisCellCount != bp.crossAxisCount || t.mainAxisCellCount != bp.mainAxisCount) {
        changed = true;
        next.add(t.copyWith(crossAxisCellCount: bp.crossAxisCount, mainAxisCellCount: bp.mainAxisCount));
      } else {
        next.add(t);
      }
    }
    if (changed) _saveTiles(next);
    _viewportSizingApplied = true;
    _prefs?.setBool(BoardsStorageService.boardGridViewportSizedKey(widget.boardId), true);
  }

  Widget _buildTextToolbar() {
    final fontSize = _currentInlineFontSize();
    final align = _currentInlineAlign();
    final bold = _currentInlineBold();
    final canGrow = fontSize < _fontSizeSteps.last;
    final canShrink = fontSize > _fontSizeSteps.first;
    final alignIcon = align == 'left'
        ? Icons.format_align_left
        : align == 'right'
            ? Icons.format_align_right
            : Icons.format_align_center;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          tooltip: 'Decrease size',
          icon: const Icon(Icons.text_decrease),
          onPressed: canShrink
              ? () {
                  final idx = _fontSizeSteps.lastIndexWhere((s) => s < fontSize);
                  _setInlineFontSize(_fontSizeSteps[idx < 0 ? 0 : idx]);
                }
              : null,
        ),
        Text('${fontSize.round()}', style: Theme.of(context).textTheme.labelMedium),
        IconButton(
          tooltip: 'Increase size',
          icon: const Icon(Icons.text_increase),
          onPressed: canGrow
              ? () {
                  final idx = _fontSizeSteps.indexWhere((s) => s > fontSize);
                  _setInlineFontSize(_fontSizeSteps[idx < 0 ? _fontSizeSteps.length - 1 : idx]);
                }
              : null,
        ),
        IconButton(
          tooltip: 'Alignment',
          icon: Icon(alignIcon),
          onPressed: _cycleInlineAlign,
        ),
        IconButton(
          tooltip: 'Bold',
          icon: Icon(Icons.format_bold, color: bold ? Theme.of(context).colorScheme.primary : null),
          onPressed: _toggleInlineBold,
        ),
        IconButton(
          tooltip: 'Done',
          icon: const Icon(Icons.check_circle_outline),
          onPressed: () => _commitInlineEdit(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _tiles.isNotEmpty && !_viewportSizingApplied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_viewportSizingApplied) _applyViewportSizing(context);
      });
    }
    final spacing = _gridSpacing;
    return Scaffold(
      appBar: AppBar(
        title: (widget.isNewBoard && _isEditing)
            ? TextField(
                controller: _boardNameC,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Name your board',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              )
            : Text(_isEditing ? 'Edit: ${_boardNameC.text.trim()}' : _boardNameC.text.trim()),
        leading: BackButton(
          onPressed: () async {
            await _saveBoardName();
            if (!mounted) return;
            Navigator.of(context).pop(widget.isNewBoard ? true : null);
          },
        ),
        actions: [
          if (widget.wizardShowNext)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(widget.wizardNextLabel),
            ),
          if (_isEditing)
            IconButton(
              tooltip: 'Shuffle layout',
              icon: const Icon(Icons.shuffle),
              onPressed: _shuffleGrid,
            ),
            IconButton(
              tooltip: _isEditing ? 'Complete' : 'Edit',
              icon: Icon(_isEditing ? Icons.check_circle : Icons.edit),
              onPressed: _toggleEditMode,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
                      builder: (context, constraints) {
                // Grid is rendered inside a 16px padding on both sides.
                final gridMaxWidth = (constraints.maxWidth - 32).clamp(0.0, double.infinity);
                final cellExtent =
                    (gridMaxWidth - (spacing * (_crossAxisCount - 1))) / _crossAxisCount;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_isEditing) {
                      _commitInlineEdit();
                      setState(() {
                        _selectedIndex = null;
                        _selectedResizeHandle = null;
                      });
                    }
                  },
                  child: SingleChildScrollView(
                    physics: (_isEditing && _isCornerHandle(_selectedResizeHandle))
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        StaggeredGrid.count(
                          crossAxisCount: _crossAxisCount,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          children: [
                          // Use sorted tiles directly to ensure consistent order and sizing
                          for (int idx = 0; idx < _tiles.length; idx++)
                            Builder(
                              builder: (context) {
                                final tile = _tiles[idx];
                                final i = tile.index;
                                return StaggeredGridTile.count(
                                  crossAxisCellCount: tile.crossAxisCellCount,
                                  mainAxisCellCount: tile.mainAxisCellCount,
                                  child: DragTarget<int>(
                                    onWillAcceptWithDetails: (details) =>
                                        _isEditing &&
                                        details.data != i &&
                                        (_selectedIndex == null || _draggingIndex != null),
                                    onAcceptWithDetails: (details) =>
                                        _swapTileSlots(details.data, i),
                                    builder: (context, candidateData, rejectedData) {
                                      final isSelected = _isEditing && _selectedIndex == i;
                                  final selectionLocked =
                                      _isEditing && _selectedIndex != null && !isSelected;
                                  final isDropTarget = candidateData.isNotEmpty;
                                  final tileSize =
                                      _tilePixelSize(tile, cellExtent: cellExtent, spacing: spacing);

                                  final tileStack = Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(child: _tileChild(tile)),
                                      if (isDropTarget)
                                        Positioned.fill(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Theme.of(context).colorScheme.primary,
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (isSelected)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Material(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                            shape: const CircleBorder(),
                                            elevation: 4,
                                            child: InkWell(
                                              customBorder: const CircleBorder(),
                                              onTap: () => _deleteOrClearTile(i),
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: Theme.of(context).colorScheme.surface,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (isSelected)
                                        ...[
                                          // Grid editor: only show resize handles on left-middle, right-middle,
                                          // and bottom-right.
                                          ResizeHandle(
                                            position: HandlePosition.centerLeft,
                                            isSelected: _selectedResizeHandle ==
                                                HandlePosition.centerLeft,
                                            onSelected: () =>
                                                _selectResizeHandle(HandlePosition.centerLeft),
                                            onStart: () =>
                                                _onResizeHandleStart(HandlePosition.centerLeft),
                                            onEnd: () {},
                                            touchSize: 40,
                                            cornerDiameter: 14,
                                            edgeLength: 24,
                                            edgeThickness: 6,
                                            visualOutset: 3,
                                            onUpdate: (d) {
                                              if (_selectedResizeHandle !=
                                                  HandlePosition.centerLeft) {
                                                return;
                                              }
                                              // Mirror right-handle behavior: dragging left increases width,
                                              // dragging right decreases width.
                                              _onResizeDragUpdate(
                                                d,
                                                cellExtent: cellExtent,
                                                allowH: false,
                                                dxMultiplier: -1,
                                              );
                                            },
                                          ),
                                          ResizeHandle(
                                            position: HandlePosition.centerRight,
                                            isSelected: _selectedResizeHandle ==
                                                HandlePosition.centerRight,
                                            onSelected: () =>
                                                _selectResizeHandle(HandlePosition.centerRight),
                                            onStart: () =>
                                                _onResizeHandleStart(HandlePosition.centerRight),
                                            onEnd: () {},
                                            // Smaller visuals for grid tiles; keep centered on the border.
                                            touchSize: 40,
                                            cornerDiameter: 14,
                                            edgeLength: 24,
                                            edgeThickness: 6,
                                            visualOutset: 3,
                                            onUpdate: (d) {
                                              if (_selectedResizeHandle !=
                                                  HandlePosition.centerRight) {
                                                return;
                                              }
                                              _onResizeDragUpdate(
                                                d,
                                                cellExtent: cellExtent,
                                                allowH: false,
                                              );
                                            },
                                          ),
                                          ResizeHandle(
                                            position: HandlePosition.bottomRight,
                                            isSelected: _selectedResizeHandle ==
                                                HandlePosition.bottomRight,
                                            onSelected: () =>
                                                _selectResizeHandle(HandlePosition.bottomRight),
                                            onStart: () =>
                                                _onResizeHandleStart(HandlePosition.bottomRight),
                                            onEnd: () {},
                                            touchSize: 40,
                                            cornerDiameter: 14,
                                            edgeLength: 24,
                                            edgeThickness: 6,
                                            visualOutset: 4,
                                            onUpdate: (d) {
                                              if (_selectedResizeHandle !=
                                                  HandlePosition.bottomRight) {
                                                return;
                                              }
                                              _onResizeDragUpdate(d, cellExtent: cellExtent);
                                            },
                                          ),
                                        ],
                                    ],
                                  );

                                  final content = InkWell(
                                    onTap: (!_isEditing)
                                        ? null
                                        : (selectionLocked)
                                            ? null
                                            : () {
                                            if (_inlineEditingIndex != null && _inlineEditingIndex != i) {
                                              _commitInlineEdit();
                                            }
                                            final wasSelected = _selectedIndex == i;
                                            setState(() {
                                              _selectedIndex = i;
                                              if (!wasSelected) _selectedResizeHandle = null;
                                            });
                                          },
                                    child: tileStack,
                                  );

                                  // While a tile is selected, lock interactions on other tiles so
                                  // resize handles at the border/corners don't lose gestures to
                                  // neighboring tiles.
                                  if (selectionLocked) {
                                    return IgnorePointer(
                                      child: content,
                                    );
                                  }

                                  if (!_isEditing) return content;

                                  return LongPressDraggable<int>(
                                    data: i,
                                    dragAnchorStrategy: pointerDragAnchorStrategy,
                                    onDragStarted: () {
                                      setState(() => _draggingIndex = i);
                                    },
                                    onDragEnd: (_) {
                                      if (!mounted) return;
                                      setState(() => _draggingIndex = null);
                                    },
                                    onDragCompleted: () {
                                      if (!mounted) return;
                                      setState(() => _draggingIndex = null);
                                    },
                                    onDraggableCanceled: (_, __) {
                                      if (!mounted) return;
                                      setState(() => _draggingIndex = null);
                                    },
                                    feedback: Material(
                                      elevation: 8,
                                      color: Colors.transparent,
                                      child: Opacity(
                                        opacity: 0.9,
                                        child: SizedBox(
                                          width: tileSize.width,
                                          height: tileSize.height,
                                          child: tileStack,
                                        ),
                                      ),
                                    ),
                                    childWhenDragging: Opacity(opacity: 0.25, child: content),
                                    child: content,
                                  );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                      },
                    ),
      bottomNavigationBar: _isEditing
          ? BottomAppBar(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _inlineEditingIndex != null
                  ? _buildTextToolbar()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          tooltip: 'Add tile',
                          icon: const Icon(Icons.add_box_outlined),
                          onPressed: _addTileSlot,
                        ),
                        IconButton(
                          tooltip: 'Add text',
                          icon: const Icon(Icons.text_fields),
                          onPressed: _selectedIndex != null
                              ? () => _editText(_selectedIndex!)
                              : _promptSelectTile,
                        ),
                        IconButton(
                          tooltip: 'Custom image',
                          icon: const Icon(Icons.image_outlined),
                          onPressed: _selectedIndex != null
                              ? () => _pickAndSetImage(_selectedIndex!)
                              : _promptSelectTile,
                        ),
                        IconButton(
                          tooltip: 'Pexels image',
                          icon: const Icon(Icons.photo_library_outlined),
                          onPressed: _selectedIndex != null
                              ? () => _openPexelsForTile(_selectedIndex!)
                              : _promptSelectTile,
                        ),
                        IconButton(
                          tooltip: 'Tile style',
                          icon: const Icon(Icons.tune),
                          onPressed: _openTileStyleSheet,
                        ),
                      ],
                    ),
            )
          : null,
    );
  }
}

