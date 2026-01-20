import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_template.dart';
import '../models/grid_tile_model.dart';
import '../models/goal_metadata.dart';
import '../models/vision_components.dart';
import '../services/boards_storage_service.dart';
import '../services/grid_tiles_storage_service.dart';
import '../services/image_service.dart';
import '../services/stock_images_service.dart';
import '../services/templates_service.dart';
import '../utils/file_image_provider.dart';
import '../widgets/grid/pexels_search_sheet.dart';
import '../widgets/editor/add_name_dialog.dart';
import '../widgets/dialogs/add_goal_dialog.dart';
import '../widgets/manipulable/resize_handle.dart';
import '../widgets/dialogs/text_input_dialog.dart';
import '../widgets/grid/image_source_sheet.dart';
import 'global_insights_screen.dart';
import 'habits_list_screen.dart';
import 'grid_goal_viewer_screen.dart';
import 'todos_list_screen.dart';

/// Template-based grid editor: users pick a layout first, then fill the blanks.
class GridEditorScreen extends StatefulWidget {
  final String boardId;
  final String title;
  final bool initialIsEditing;
  final GridTemplate template;
  /// When true, show a wizard-only AppBar action to proceed (closes editor with `true`).
  final bool wizardShowNext;
  final String wizardNextLabel;

  const GridEditorScreen({
    super.key,
    required this.boardId,
    required this.title,
    required this.initialIsEditing,
    required this.template,
    this.wizardShowNext = false,
    this.wizardNextLabel = 'Next',
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
  int _viewTabIndex = 0; // 0: Grid, 1: Habits, 2: Todo, 3: Insights (view mode only)
  int? _selectedIndex;
  double _resizeAccumDx = 0;
  double _resizeAccumDy = 0;
  HandlePosition? _selectedResizeHandle;
  int? _draggingIndex;

  SharedPreferences? _prefs;
  List<GridTileModel> _tiles = [];
  int _styleSeed = 0;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialIsEditing;
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _styleSeed = _prefs?.getInt(BoardsStorageService.boardGridStyleSeedKey(widget.boardId)) ?? 0;
    if (_styleSeed == 0) {
      _styleSeed = DateTime.now().millisecondsSinceEpoch;
      await _prefs?.setInt(BoardsStorageService.boardGridStyleSeedKey(widget.boardId), _styleSeed);
    }
    final loaded = await GridTilesStorageService.loadTiles(widget.boardId, prefs: _prefs);
    final hydrated = _ensureTemplateTiles(loaded);
    await GridTilesStorageService.saveTiles(widget.boardId, hydrated, prefs: _prefs);
    if (!mounted) return;
    setState(() {
      _tiles = hydrated;
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

    // Apply new tile sizes; keep goal/user content in place.
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

    // Optional: refresh placeholder images from Pexels using a best-effort query.
    final placeholders = nextTiles.where((t) => t.isPlaceholder).toList();
    if (placeholders.isNotEmpty) {
      final counts = <String, int>{};
      for (final t in nextTiles) {
        final cat = (t.goal?.category ?? '').trim();
        if (cat.isEmpty) continue;
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
      String query = widget.title.trim();
      if (counts.isNotEmpty) {
        final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        query = entries.first.key;
      }

      final urls = await StockImagesService.searchPexelsUrls(
        query: query,
        perPage: min(12, placeholders.length),
      );
      if (urls.isNotEmpty) {
        int u = 0;
        final updated = nextTiles.map((t) {
          if (!t.isPlaceholder) return t;
          if (u >= urls.length) return t;
          final url = urls[u++];
          return t.copyWith(type: 'image', content: url);
        }).toList();
        nextTiles
          ..clear()
          ..addAll(updated);
      }
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

    // Always ensure at least the template's tile count so the grid fills the screen.
    // (Wizard-generated boards may start with fewer tiles than the chosen template.)
    final minCount = widget.template.tiles.length;
    for (int i = next.length; i < minCount; i++) {
      final blueprint = widget.template.tiles[i];
      next.add(
        GridTileModel(
          id: 'tile_$i',
          type: 'empty',
          content: null,
          crossAxisCellCount: blueprint.crossAxisCount,
          mainAxisCellCount: blueprint.mainAxisCount,
          index: i,
        ),
      );
    }

    return GridTilesStorageService.sortTiles(next);
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
    final next = [
      ..._tiles,
      GridTileModel(
        id: id,
        type: 'empty',
        content: null,
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
    await _ensureGoalTitle(index, suggestedTitle: 'Goal');
  }

  Future<void> _showAddContentSheet(int index) async {
    if (!_isEditing) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Add Image'),
              onTap: () => Navigator.of(context).pop('image'),
            ),
            ListTile(
              leading: const Icon(Icons.public_outlined),
              title: const Text('Search from web (Pexels)'),
              onTap: () => Navigator.of(context).pop('pexels'),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Add Text'),
              onTap: () => Navigator.of(context).pop('text'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == null) return;
    if (choice == 'image') {
      await _pickAndSetImage(index);
      return;
    }
    if (choice == 'pexels') {
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
      await _ensureGoalTitle(index, suggestedTitle: cat.isNotEmpty ? cat : 'Goal');
      return;
    }
    if (choice == 'text') {
      await _editText(index);
    }
  }

  Future<void> _editText(int index) async {
    final existing = _tileAt(index);
    final String? text = await showTextInputDialog(
      context,
      title: 'Edit text',
      initialText: existing.type == 'text' ? (existing.content ?? '') : '',
    );
    if (!mounted) return;
    if (text == null) return;

    final nextText = text.trim();
    await _setTile(index, existing.copyWith(type: nextText.isEmpty ? 'empty' : 'text', content: nextText.isEmpty ? null : nextText));
    if (nextText.isNotEmpty) {
      await _ensureGoalTitle(index, suggestedTitle: nextText.length > 24 ? nextText.substring(0, 24) : nextText);
    }
  }

  Future<void> _clearTile(int index) async {
    await _setTile(
      index,
      _tileAt(index).copyWith(
        type: 'empty',
        content: null,
        goal: null,
        habits: const [],
        tasks: const [],
      ),
    );
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

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      // When switching back to view mode, default to grid view and clear selection.
      if (!_isEditing) {
        _viewTabIndex = 0;
        _selectedIndex = null;
        _selectedResizeHandle = null;
      }
    });
  }

  List<VisionComponent> _componentsFromTiles() {
    final comps = <VisionComponent>[];
    for (final t in _tiles) {
      if (t.type == 'empty') continue;
      comps.add(
        ImageComponent(
          id: t.id, // stable key for persistence
          position: Offset.zero,
          size: const Size(1, 1),
          rotation: 0,
          scale: 1,
          zIndex: t.index,
          imagePath: (t.type == 'image') ? (t.content ?? '') : '',
          // Important: don't synthesize a fake goal title like "tile_0".
          // If there's no goal metadata, keep it null so labels can fall back cleanly.
          goal: t.goal,
          habits: t.habits,
          tasks: t.tasks,
        ),
      );
    }
    return comps;
  }

  Future<void> _applyComponentUpdates(List<VisionComponent> updated) async {
    final byId = <String, VisionComponent>{for (final c in updated) c.id: c};
    final next = _tiles.map((t) {
      final c = byId[t.id];
      if (c == null) return t;
      final img = c is ImageComponent ? c : null;
      return t.copyWith(
        goal: img?.goal ?? t.goal,
        habits: c.habits,
        tasks: c.tasks,
      );
    }).toList();
    await _saveTiles(next);
  }

  Widget _tileChild(GridTileModel tile) {
    final borderRadius = BorderRadius.circular(14);
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
      final src = raw.isEmpty ? '' : TemplatesService.absolutizeMaybe(raw);
      final provider = fileImageProviderFromPath(src);
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
      base = Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55),
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.outline.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        alignment: Alignment.topLeft,
        child: Text(
          (tile.content ?? '').trim(),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: tile.isPlaceholder 
              ? _placeholderTextStyle(context, tile) 
              : TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
        ),
      );
    } else {
      // Empty state
      final colorScheme = Theme.of(context).colorScheme;
      base = Container(
        decoration: BoxDecoration(
          color: colorScheme.outline.withOpacity(0.08),
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected 
                ? colorScheme.primary 
                : colorScheme.outline.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 6),
            Text(
              'Tap twice to add',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    // Slight spacing improves readability and makes the grid feel intentional.
    const spacing = 10.0;
    final selected = _selectedTile();
    final viewTitle = _viewTabIndex == 0
        ? widget.title
        : _viewTabIndex == 1
            ? 'Habits'
            : _viewTabIndex == 2
                ? 'Todo'
                : 'Insights';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit: ${widget.title}' : viewTitle),
        leading: const BackButton(),
        actions: [
          if (widget.wizardShowNext)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(widget.wizardNextLabel),
            ),
          if (_isEditing && _viewTabIndex == 0)
            IconButton(
              tooltip: 'Shuffle layout',
              icon: const Icon(Icons.shuffle),
              onPressed: _shuffleGrid,
            ),
          if (_viewTabIndex == 0 || _isEditing)
            IconButton(
              tooltip: _isEditing ? 'Complete' : 'Edit',
              icon: Icon(_isEditing ? Icons.check_circle : Icons.edit),
              onPressed: _toggleEditMode,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (!_isEditing && _viewTabIndex == 1)
              ? HabitsListScreen(
                  components: _componentsFromTiles(),
                  onComponentsUpdated: _applyComponentUpdates,
                  showAppBar: false,
                )
              : (!_isEditing && _viewTabIndex == 2)
                  ? TodosListScreen(
                      components: _componentsFromTiles(),
                      onComponentsUpdated: _applyComponentUpdates,
                      onOpenComponent: (_) async {},
                      showAppBar: false,
                      allowManageTodos: true,
                    )
                  : (!_isEditing && _viewTabIndex == 3)
                      ? GlobalInsightsScreen(components: _componentsFromTiles())
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
                        child: StaggeredGrid.count(
                          crossAxisCount: _crossAxisCount,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          children: [
                          for (int i = 0; i < _tiles.length; i++)
                            StaggeredGridTile.count(
                              crossAxisCellCount: _tileAt(i).crossAxisCellCount,
                              mainAxisCellCount: _tileAt(i).mainAxisCellCount,
                              child: DragTarget<int>(
                                onWillAcceptWithDetails: (details) =>
                                    _isEditing &&
                                    details.data != i &&
                                    (_selectedIndex == null || _draggingIndex != null),
                                onAcceptWithDetails: (details) =>
                                    _swapTileSlots(details.data, i),
                                builder: (context, candidateData, rejectedData) {
                                  final tile = _tileAt(i);
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
                                            child: IconButton(
                                              visualDensity: VisualDensity.compact,
                                              iconSize: 18,
                                              tooltip: 'Delete',
                                              color: Theme.of(context).colorScheme.surface,
                                              onPressed: () => _deleteOrClearTile(i),
                                              icon: const Icon(Icons.delete_outline),
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
                                        ? () async {
                                            // View mode: open the goal viewer for this tile.
                                            final current = _tileAt(i);
                                            if (current.type == 'empty') return;
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => GridGoalViewerScreen(
                                                  boardId: widget.boardId,
                                                  tileId: current.id,
                                                ),
                                              ),
                                            );
                                            if (mounted) await _init();
                                          }
                                        : (selectionLocked)
                                            ? null
                                            : () async {
                                            final wasSelected = _selectedIndex == i;
                                            setState(() {
                                              _selectedIndex = i;
                                              if (!wasSelected) _selectedResizeHandle = null;
                                            });

                                            // Second tap on a selected tile edits/adds content.
                                            if (!wasSelected) return;
                                            if (tile.type == 'empty') {
                                              await _showAddContentSheet(i);
                                              return;
                                            }
                                            if (tile.type == 'text') {
                                              await _editText(i);
                                              return;
                                            }
                                            if (tile.type == 'image') {
                                              await _pickAndSetImage(i);
                                            }
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
          ? SafeArea(
              top: false,
              child: BottomAppBar(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Add tile slot',
                      icon: const Icon(Icons.add_box_outlined),
                      onPressed: _addTileSlot,
                    ),
                    const Spacer(),
                    if (selected != null)
                      Flexible(
                        child: Text(
                          'Drag handles to resize • Long-press tile to move',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : BottomNavigationBar(
              currentIndex: _viewTabIndex,
              onTap: (i) => setState(() => _viewTabIndex = i),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), label: 'Grid'),
                BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Habits'),
                BottomNavigationBarItem(icon: Icon(Icons.playlist_add_check), label: 'Todo'),
                BottomNavigationBarItem(icon: Icon(Icons.insights_outlined), label: 'Insights'),
              ],
            ),
    );
  }
}

