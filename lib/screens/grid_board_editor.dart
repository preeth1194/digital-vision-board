import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_template.dart';
import '../models/grid_tile_model.dart';
import '../services/grid_tiles_storage_service.dart';
import '../services/image_service.dart';
import '../utils/file_image_provider.dart';
import '../widgets/dialogs/text_input_dialog.dart';
import '../widgets/grid/image_source_sheet.dart';

/// Template-based grid editor: users pick a layout first, then fill the blanks.
class GridEditorScreen extends StatefulWidget {
  final String boardId;
  final String title;
  final bool initialIsEditing;
  final GridTemplate template;

  const GridEditorScreen({
    super.key,
    required this.boardId,
    required this.title,
    required this.initialIsEditing,
    required this.template,
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

  SharedPreferences? _prefs;
  List<GridTileModel> _tiles = [];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialIsEditing;
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final loaded = await GridTilesStorageService.loadTiles(widget.boardId, prefs: _prefs);
    final hydrated = _ensureTemplateTiles(loaded);
    await GridTilesStorageService.saveTiles(widget.boardId, hydrated, prefs: _prefs);
    if (!mounted) return;
    setState(() {
      _tiles = hydrated;
      _loading = false;
    });
  }

  List<GridTileModel> _ensureTemplateTiles(List<GridTileModel> existing) {
    // Normalize indices, then ensure we have at least template-length tiles.
    final sorted = GridTilesStorageService.sortTiles(existing);
    final normalized = <GridTileModel>[];
    for (int i = 0; i < sorted.length; i++) {
      final t = sorted[i];
      normalized.add(t.index == i ? t : t.copyWith(index: i));
    }

    final next = List<GridTileModel>.from(normalized);
    for (int i = next.length; i < widget.template.tiles.length; i++) {
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

  Future<void> _onResizeDragUpdate(
    DragUpdateDetails details, {
    required double cellExtent,
    bool allowW = true,
    bool allowH = true,
  }) async {
    if (!_isEditing) return;
    if (_selectedIndex == null) return;

    if (allowW) _resizeAccumDx += details.delta.dx;
    if (allowH) _resizeAccumDy += details.delta.dy;

    // Snap a bit sooner than a full cell so small tiles are still usable.
    final snapExtent = cellExtent * 0.6;

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

    // If there is content, delete the contents (keep the tile slot).
    if (hasContent) {
      await _clearTile(index);
      return;
    }

    // If no content is found, delete the tile slot (if allowed).
    if (_tiles.length <= widget.template.tiles.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot remove tiles below the template minimum.')),
      );
      return;
    }

    final kept = _tiles.where((tile) => tile.index != index).toList();
    final reindexed = <GridTileModel>[];
    for (int i = 0; i < kept.length; i++) {
      reindexed.add(kept[i].index == i ? kept[i] : kept[i].copyWith(index: i));
    }
    await _saveTiles(reindexed);
    if (!mounted) return;
    setState(() => _selectedIndex = null);
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

    await _setTile(
      index,
      GridTileModel(
        id: _tileAt(index).id,
        type: 'image',
        content: croppedPath,
        crossAxisCellCount: _tileAt(index).crossAxisCellCount,
        mainAxisCellCount: _tileAt(index).mainAxisCellCount,
        index: index,
      ),
    );
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
    await _setTile(
      index,
      GridTileModel(
        id: _tileAt(index).id,
        type: nextText.isEmpty ? 'empty' : 'text',
        content: nextText.isEmpty ? null : nextText,
        crossAxisCellCount: _tileAt(index).crossAxisCellCount,
        mainAxisCellCount: _tileAt(index).mainAxisCellCount,
        index: index,
      ),
    );
  }

  Future<void> _clearTile(int index) async {
    await _setTile(
      index,
      GridTileModel(
        id: _tileAt(index).id,
        type: 'empty',
        content: null,
        crossAxisCellCount: _tileAt(index).crossAxisCellCount,
        mainAxisCellCount: _tileAt(index).mainAxisCellCount,
        index: index,
      ),
    );
  }

  void _toggleEditMode() {
    setState(() => _isEditing = !_isEditing);
  }

  Widget _tileChild(GridTileModel tile) {
    final borderRadius = BorderRadius.zero;
    final isSelected = _isEditing && _selectedIndex == tile.index;

    if (tile.type == 'image') {
      final provider = fileImageProviderFromPath(tile.content ?? '');
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black12,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.none,
        child: provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
      );
    }

    if (tile.type == 'text') {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55),
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black12,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        alignment: Alignment.topLeft,
        child: Text(
          (tile.content ?? '').trim(),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    // Empty state
    return Container(
      decoration: BoxDecoration(
        color: Colors.black12.withOpacity(0.08),
        borderRadius: borderRadius,
        border: Border.all(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black12,
          width: isSelected ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.add, color: Colors.black54),
          SizedBox(height: 6),
          Text('Tap twice to add', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Removed the fixed 12px spacing toggle; keep the grid compact by default.
    const spacing = 0.0;
    final selected = _selectedTile();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit: ${widget.title}' : widget.title),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: _isEditing ? 'Switch to View Mode' : 'Switch to Edit Mode',
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
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
                    if (_isEditing) setState(() => _selectedIndex = null);
                  },
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                                    _isEditing && details.data != i,
                                onAcceptWithDetails: (details) =>
                                    _swapTileSlots(details.data, i),
                                builder: (context, candidateData, rejectedData) {
                                  final tile = _tileAt(i);
                                  final isSelected = _isEditing && _selectedIndex == i;
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
                                            color: Colors.black.withOpacity(0.55),
                                            shape: const CircleBorder(),
                                            child: IconButton(
                                              visualDensity: VisualDensity.compact,
                                              iconSize: 18,
                                              tooltip: 'Delete',
                                              color: Colors.white,
                                              onPressed: () => _deleteOrClearTile(i),
                                              icon: const Icon(Icons.delete_outline),
                                            ),
                                          ),
                                        ),
                                      if (isSelected)
                                        Positioned(
                                          // Keep the handle on the tile border (inside hit area) so
                                          // it doesn't lose hit-testing to drag & drop.
                                          right: 0,
                                          top: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onPanStart: (_) => _onResizeDragStart(),
                                              onPanUpdate: (d) => _onResizeDragUpdate(
                                                d,
                                                cellExtent: cellExtent,
                                                allowH: false,
                                              ),
                                              child: Container(
                                                width: 16,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.55),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.chevron_right, size: 14, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (isSelected)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onPanStart: (_) => _onResizeDragStart(),
                                              onPanUpdate: (d) => _onResizeDragUpdate(
                                                d,
                                                cellExtent: cellExtent,
                                                allowW: false,
                                              ),
                                              child: Container(
                                                width: 28,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.55),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.expand_more, size: 14, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (isSelected)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onPanStart: (_) => _onResizeDragStart(),
                                            onPanUpdate: (d) => _onResizeDragUpdate(
                                              d,
                                              cellExtent: cellExtent,
                                            ),
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.55),
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(Icons.open_in_full, size: 11, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );

                                  final content = InkWell(
                                    onTap: !_isEditing
                                        ? null
                                        : () async {
                                            final wasSelected = _selectedIndex == i;
                                            setState(() => _selectedIndex = i);

                                            // Second tap on a selected tile edits/adds content.
                                            if (!wasSelected) return;
                                            if (tile.type == 'empty') {
                                              await _showAddContentSheet(i);
                                              return;
                                            }
                                            if (tile.type == 'text') {
                                              await _editText(i);
                                            }
                                          },
                                    child: tileStack,
                                  );

                                  if (!_isEditing) return content;

                                  return LongPressDraggable<int>(
                                    data: i,
                                    dragAnchorStrategy: pointerDragAnchorStrategy,
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
                );
              },
            ),
      bottomNavigationBar: !_isEditing
          ? null
          : SafeArea(
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

