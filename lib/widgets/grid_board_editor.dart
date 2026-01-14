import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import '../services/image_service.dart';
import '../utils/file_image_provider.dart';

class GridBoardEditor extends StatefulWidget {
  final String boardId;
  final String title;
  final bool initialIsEditing;

  const GridBoardEditor({
    super.key,
    required this.boardId,
    required this.title,
    required this.initialIsEditing,
  });

  @override
  State<GridBoardEditor> createState() => _GridBoardEditorState();
}

class _GridBoardEditorState extends State<GridBoardEditor> {
  static const int _crossAxisCount = 2;
  static const int _minMainAxisCells = 1;
  static const int _maxMainAxisCells = 4;

  // Shared pick/compress defaults (kept aligned with freeform editor)
  static const double _pickedImageMaxSide = 2048;
  static const int _pickedImageQuality = 92;

  late bool _isEditing;
  bool _resizeMode = false;
  bool _loading = true;

  SharedPreferences? _prefs;
  List<GridTileModel> _tiles = [];

  String get _gridTilesKey => 'vision_board_${widget.boardId}_grid_tiles_v1';

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialIsEditing;
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadTiles();
  }

  List<GridTileModel> _sortedTiles(List<GridTileModel> tiles) {
    final next = List<GridTileModel>.from(tiles)
      ..sort((a, b) => a.index.compareTo(b.index));
    return next;
  }

  List<GridTileModel> _normalizeIndices(List<GridTileModel> tiles) {
    final sorted = _sortedTiles(tiles);
    return List<GridTileModel>.generate(
      sorted.length,
      (i) => sorted[i].index == i ? sorted[i] : sorted[i].copyWith(index: i),
    );
  }

  Future<void> _loadTiles() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final raw = prefs.getString(_gridTilesKey);
    List<GridTileModel> tiles = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        tiles = decoded.map((e) => GridTileModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        tiles = [];
      }
    }

    if (!mounted) return;
    setState(() {
      _tiles = _normalizeIndices(tiles);
      _loading = false;
    });
  }

  Future<void> _saveTiles(List<GridTileModel> tiles) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final normalized = _normalizeIndices(tiles);
    await prefs.setString(
      _gridTilesKey,
      jsonEncode(normalized.map((t) => t.toJson()).toList()),
    );
    if (!mounted) return;
    setState(() => _tiles = normalized);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _resizeMode = false;
    });
  }

  void _toggleResizeMode() {
    if (!_isEditing) return;
    setState(() => _resizeMode = !_resizeMode);
  }

  Future<void> _showAddTileDialog() async {
    if (!_isEditing) return;
    final String? choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to grid'),
        content: const Text('Choose what to add'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop('text'),
            icon: const Icon(Icons.text_fields),
            label: const Text('Add Text'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop('image'),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Add Image'),
          ),
        ],
      ),
    );

    if (choice == null) return;
    if (choice == 'text') {
      await _addTextTile();
      return;
    }
    if (choice == 'image') {
      await _addImageTile();
      return;
    }
  }

  Future<String?> _showImageSourceSheet() async {
    if (kIsWeb) {
      return 'gallery';
    }

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addImageTile() async {
    final sourceChoice = await _showImageSourceSheet();
    if (sourceChoice == null) return;

    final source = sourceChoice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final String? croppedPath = await ImageService.pickAndCropImage(
      context,
      source: source,
      maxWidth: _pickedImageMaxSide,
      maxHeight: _pickedImageMaxSide,
      imageQuality: _pickedImageQuality,
    );
    if (croppedPath == null || croppedPath.isEmpty) return;

    final id = 'tile_${DateTime.now().millisecondsSinceEpoch}';
    final next = [
      ..._tiles,
      GridTileModel(
        id: id,
        type: 'image',
        content: croppedPath,
        crossAxisCellCount: 1,
        mainAxisCellCount: 1,
        index: _tiles.length,
      ),
    ];
    await _saveTiles(next);
  }

  Future<void> _addTextTile() async {
    final String? text = await _showTextEditorDialog(title: 'Add text', initialText: '');
    if (text == null || text.trim().isEmpty) return;

    final id = 'tile_${DateTime.now().millisecondsSinceEpoch}';
    final next = [
      ..._tiles,
      GridTileModel(
        id: id,
        type: 'text',
        content: text.trim(),
        crossAxisCellCount: 1,
        mainAxisCellCount: 1,
        index: _tiles.length,
      ),
    ];
    await _saveTiles(next);
  }

  Future<void> _editTextTile(GridTileModel tile) async {
    final String? text = await _showTextEditorDialog(
      title: 'Edit text',
      initialText: tile.content ?? '',
    );
    if (text == null) return;
    final updated = tile.copyWith(content: text.trim());
    await _saveTiles(_tiles.map((t) => t.id == tile.id ? updated : t).toList());
  }

  Future<void> _deleteTile(GridTileModel tile) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove tile?'),
        content: const Text('This tile will be removed from the grid.'),
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
    if (confirm != true) return;
    await _saveTiles(_tiles.where((t) => t.id != tile.id).toList());
  }

  Future<String?> _showTextEditorDialog({
    required String title,
    required String initialText,
  }) async {
    final controller = TextEditingController(text: initialText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Type something...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _adjustTileSize(
    GridTileModel tile, {
    int? deltaW,
    int? deltaH,
  }) async {
    final nextW = (tile.crossAxisCellCount + (deltaW ?? 0)).clamp(1, _crossAxisCount);
    final nextH = (tile.mainAxisCellCount + (deltaH ?? 0)).clamp(_minMainAxisCells, _maxMainAxisCells);
    final updated = tile.copyWith(
      crossAxisCellCount: nextW,
      mainAxisCellCount: nextH,
    );
    await _saveTiles(_tiles.map((t) => t.id == tile.id ? updated : t).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tiles = _sortedTiles(_tiles);

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
          if (_isEditing)
            IconButton(
              tooltip: _resizeMode ? 'Exit Resize Mode' : 'Resize Mode',
              icon: Icon(_resizeMode ? Icons.close_fullscreen : Icons.open_in_full),
              onPressed: _toggleResizeMode,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: StaggeredGrid.count(
            crossAxisCount: _crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              ...tiles.map((tile) {
                return StaggeredGridTile.count(
                  crossAxisCellCount: tile.crossAxisCellCount,
                  mainAxisCellCount: tile.mainAxisCellCount,
                  child: _GridTileCard(
                    tile: tile,
                    isEditing: _isEditing,
                    resizeMode: _resizeMode,
                    onTap: () async {
                      if (!_isEditing) return;
                      if (tile.type == 'text') {
                        await _editTextTile(tile);
                      }
                    },
                    onLongPress: () {
                      // Quick shortcut: long-press toggles resize mode.
                      if (_isEditing) _toggleResizeMode();
                    },
                    onResize: (deltaW, deltaH) => _adjustTileSize(tile, deltaW: deltaW, deltaH: deltaH),
                    onDelete: () => _deleteTile(tile),
                  ),
                );
              }),
              // "Empty tile" placeholder (always present at end while editing)
              if (_isEditing)
                StaggeredGridTile.count(
                  crossAxisCellCount: 1,
                  mainAxisCellCount: 1,
                  child: _AddTileCard(onTap: _showAddTileDialog),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTileCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 32),
              SizedBox(height: 6),
              Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridTileCard extends StatelessWidget {
  final GridTileModel tile;
  final bool isEditing;
  final bool resizeMode;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(int deltaW, int deltaH)? onResize;
  final VoidCallback? onDelete;

  const _GridTileCard({
    required this.tile,
    required this.isEditing,
    required this.resizeMode,
    required this.onTap,
    required this.onLongPress,
    required this.onResize,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);

    Widget content;
    if (tile.type == 'image') {
      final path = tile.content ?? '';
      final provider = fileImageProviderFromPath(path);
      content = ClipRRect(
        borderRadius: borderRadius,
        child: provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55),
          borderRadius: borderRadius,
        ),
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            (tile.content ?? '').trim().isEmpty ? 'Tap to edit' : (tile.content ?? ''),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: Colors.black12),
              ),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
          ),
          if (isEditing && resizeMode)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MiniIconButton(
                      icon: Icons.remove,
                      tooltip: 'Width -',
                      onPressed: () => onResize?.call(-1, 0),
                    ),
                    _MiniIconButton(
                      icon: Icons.add,
                      tooltip: 'Width +',
                      onPressed: () => onResize?.call(1, 0),
                    ),
                    const SizedBox(width: 8),
                    _MiniIconButton(
                      icon: Icons.expand_less,
                      tooltip: 'Height -',
                      onPressed: () => onResize?.call(0, -1),
                    ),
                    _MiniIconButton(
                      icon: Icons.expand_more,
                      tooltip: 'Height +',
                      onPressed: () => onResize?.call(0, 1),
                    ),
                    const Spacer(),
                    _MiniIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Remove',
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: Colors.white),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onPressed,
    );
  }
}

