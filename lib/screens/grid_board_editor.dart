import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_template.dart';
import '../models/grid_tile_model.dart';
import '../services/boards_storage_service.dart';
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
  bool _compactSpacing = false;

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
    _compactSpacing = _prefs?.getBool(
          BoardsStorageService.boardGridCompactSpacingKey(widget.boardId),
        ) ??
        false;
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

  Future<void> _setCompactSpacing(bool value) async {
    setState(() => _compactSpacing = value);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await prefs.setBool(
      BoardsStorageService.boardGridCompactSpacingKey(widget.boardId),
      value,
    );
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

  Future<void> _removeSelectedTileSlot() async {
    if (!_isEditing) return;
    final selected = _selectedIndex;
    if (selected == null) return;
    if (_tiles.length <= widget.template.tiles.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot remove tiles below the template minimum.')),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove tile slot?'),
        content: const Text('This removes the tile position from the layout.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm != true) return;

    final kept = _tiles.where((t) => t.index != selected).toList();
    final reindexed = <GridTileModel>[];
    for (int i = 0; i < kept.length; i++) {
      reindexed.add(kept[i].index == i ? kept[i] : kept[i].copyWith(index: i));
    }
    await _saveTiles(reindexed);
    if (!mounted) return;
    setState(() => _selectedIndex = selected.clamp(0, reindexed.length - 1));
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

  Future<void> _showTileMenu(int index) async {
    final t = _tileAt(index);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Edit Text'),
              onTap: () {
                Navigator.of(context).pop();
                _editText(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.layers_clear_outlined),
              title: const Text('Clear Tile'),
              enabled: t.type != 'empty',
              onTap: t.type == 'empty'
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _clearTile(index);
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleEditMode() {
    setState(() => _isEditing = !_isEditing);
  }

  Widget _tileChild(GridTileModel tile) {
    final borderRadius = BorderRadius.circular(16);
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
        clipBehavior: Clip.antiAlias,
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
        padding: const EdgeInsets.all(12),
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
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.add, color: Colors.black54),
          SizedBox(height: 6),
          Text('Tap to Add', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = _compactSpacing ? 0.0 : 12.0;
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
          : Padding(
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: !_isEditing
                            ? null
                            : () {
                                final t = _tileAt(i);
                                setState(() => _selectedIndex = i);
                                if (t.type == 'empty') _pickAndSetImage(i);
                              },
                        onLongPress: !_isEditing ? null : () => _showTileMenu(i),
                        child: _tileChild(_tileAt(i)),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: !_isEditing
          ? null
          : BottomAppBar(
              height: 84 + MediaQuery.of(context).padding.bottom,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _compactSpacing ? 'Show spacing' : 'Remove spacing',
                      icon: Icon(_compactSpacing ? Icons.grid_on : Icons.grid_off),
                      onPressed: () => _setCompactSpacing(!_compactSpacing),
                    ),
                    IconButton(
                      tooltip: 'Add tile slot',
                      icon: const Icon(Icons.add_box_outlined),
                      onPressed: _addTileSlot,
                    ),
                    IconButton(
                      tooltip: 'Remove selected slot',
                      icon: const Icon(Icons.indeterminate_check_box_outlined),
                      onPressed: selected == null ? null : _removeSelectedTileSlot,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Width -',
                      icon: const Icon(Icons.remove),
                      onPressed: selected == null ? null : () => _resizeSelected(deltaW: -1),
                    ),
                    IconButton(
                      tooltip: 'Width +',
                      icon: const Icon(Icons.add),
                      onPressed: selected == null ? null : () => _resizeSelected(deltaW: 1),
                    ),
                    IconButton(
                      tooltip: 'Height -',
                      icon: const Icon(Icons.expand_less),
                      onPressed: selected == null ? null : () => _resizeSelected(deltaH: -1),
                    ),
                    IconButton(
                      tooltip: 'Height +',
                      icon: const Icon(Icons.expand_more),
                      onPressed: selected == null ? null : () => _resizeSelected(deltaH: 1),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

