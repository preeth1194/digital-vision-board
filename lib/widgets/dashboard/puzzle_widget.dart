import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../../models/vision_board_info.dart';
import '../../services/puzzle_service.dart';
import '../../utils/puzzle_image_splitter.dart';
import '../../utils/file_image_provider.dart';
import '../../screens/puzzle_game_screen.dart';
import '../../widgets/dialogs/puzzle_image_selector_sheet.dart';

class PuzzleWidget extends StatefulWidget {
  final List<VisionBoardInfo> boards;
  final SharedPreferences? prefs;

  const PuzzleWidget({
    super.key,
    required this.boards,
    this.prefs,
  });

  @override
  State<PuzzleWidget> createState() => _PuzzleWidgetState();
}

class _PuzzleWidgetState extends State<PuzzleWidget> {
  String? _currentImagePath;
  List<Uint8List>? _puzzlePieces;
  List<int>? _shuffledIndices;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  Future<void> _loadPuzzle() async {
    if (widget.boards.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No vision boards available';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final imagePath = await PuzzleService.getCurrentPuzzleImage(
        boards: widget.boards,
        prefs: widget.prefs,
      );

      if (imagePath == null || imagePath.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No images available';
        });
        return;
      }

      // Split image into 4x4 pieces
      const gridSize = 4;
      final pieces = await PuzzleImageSplitter.splitImage(imagePath, gridSize);
      final shuffledIndices = PuzzleImageSplitter.shufflePieces(pieces.length);

      if (!mounted) return;
      setState(() {
        _currentImagePath = imagePath;
        _puzzlePieces = pieces;
        _shuffledIndices = shuffledIndices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load puzzle: ${e.toString()}';
      });
    }
  }

  Future<void> _selectImage() async {
    final selected = await showPuzzleImageSelectorSheet(
      context,
      boards: widget.boards,
      prefs: widget.prefs,
    );

    if (selected != null && selected != _currentImagePath) {
      await PuzzleService.setPuzzleImage(selected, prefs: widget.prefs);
      await _loadPuzzle();
    }
  }

  void _openPuzzleGame() {
    if (_currentImagePath == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleGameScreen(
          imagePath: _currentImagePath!,
          prefs: widget.prefs,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.extension,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Puzzle Challenge',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  tooltip: 'Select puzzle image',
                  onPressed: _selectImage,
                ),
              ],
            ),
          ),
          // Puzzle preview
          Container(
            height: 200,
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: _buildPuzzleContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadPuzzle,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_puzzlePieces == null || _shuffledIndices == null) {
      return Center(
        child: Text(
          'No puzzle available',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return InkWell(
      onTap: _openPuzzleGame,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _puzzlePieces!.length,
        itemBuilder: (context, index) {
          // Get the shuffled piece index
          final pieceIndex = _shuffledIndices![index];
          final pieceBytes = _puzzlePieces![pieceIndex];

          return Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Image.memory(
              pieceBytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(
                    Icons.broken_image,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
