import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../../models/vision_board_info.dart';
import '../../services/puzzle_service.dart';
import '../../services/puzzle_state_service.dart';
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
  bool _isCompleted = false;
  String? _goalTitle;

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
      _isCompleted = false;
      _goalTitle = null;
    });

    try {
      final prefs = widget.prefs ?? await SharedPreferences.getInstance();
      final imagePath = await PuzzleService.getCurrentPuzzleImage(
        boards: widget.boards,
        prefs: prefs,
      );

      if (imagePath == null || imagePath.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No images available';
        });
        return;
      }

      // Load saved state
      final savedState = await PuzzleStateService.loadPuzzleState(
        imagePath: imagePath,
        prefs: prefs,
      );

      // Split image into 4x4 pieces
      const gridSize = 4;
      final pieces = await PuzzleImageSplitter.splitImage(imagePath, gridSize);

      if (!mounted) return;

      if (savedState != null && savedState.imagePath == imagePath) {
        // Use saved state positions
        final positionPieces = savedState.positionPieces;
        final shuffledIndices = List<int>.generate(
          pieces.length,
          (i) => positionPieces[i] ?? i,
        );

        setState(() {
          _currentImagePath = imagePath;
          _puzzlePieces = pieces;
          _shuffledIndices = shuffledIndices;
          _isCompleted = savedState.isCompleted;
          _loading = false;
        });

        // Load goal title if completed
        if (_isCompleted) {
          final goal = await PuzzleService.getGoalForImagePath(
            imagePath: imagePath,
            boards: widget.boards,
            prefs: prefs,
          );
          if (mounted) {
            setState(() {
              _goalTitle = goal?.title;
            });
          }
        }
      } else {
        // Use shuffled state
        final shuffledIndices = PuzzleImageSplitter.shufflePieces(pieces.length);

        setState(() {
          _currentImagePath = imagePath;
          _puzzlePieces = pieces;
          _shuffledIndices = shuffledIndices;
          _loading = false;
        });
      }
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

  Future<void> _openPuzzleGame() async {
    if (_currentImagePath == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleGameScreen(
          imagePath: _currentImagePath!,
          prefs: widget.prefs,
        ),
      ),
    );
    // Reload puzzle state after returning from game screen
    if (mounted) {
      await _loadPuzzle();
    }
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

    // Show completion tile if puzzle is completed
    if (_isCompleted) {
      final goalMessage = _goalTitle != null && _goalTitle!.isNotEmpty
          ? 'You are 1 step closer in reaching your goal: $_goalTitle'
          : 'You are 1 step closer in reaching your goal!';

      return InkWell(
        onTap: _openPuzzleGame,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: show first piece or reference image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _currentImagePath != null
                    ? Image(
                        image: fileImageProviderFromPath(_currentImagePath!)!,
                        fit: BoxFit.cover,
                      )
                    : Image.memory(
                        _puzzlePieces![0],
                        fit: BoxFit.cover,
                      ),
              ),
              // Overlay with message
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.celebration,
                          color: Colors.amber,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          goalMessage,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show shuffled puzzle preview
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
