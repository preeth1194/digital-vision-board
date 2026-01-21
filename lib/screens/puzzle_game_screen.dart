import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/puzzle_image_splitter.dart';
import '../utils/file_image_provider.dart';
import '../services/puzzle_service.dart';
import '../services/puzzle_state_service.dart';
import '../services/puzzle_widget_snapshot_service.dart';
import '../widgets/dialogs/puzzle_image_selector_sheet.dart';
import '../models/vision_board_info.dart';
import '../services/boards_storage_service.dart';

class PuzzleGameScreen extends StatefulWidget {
  final String imagePath;
  final SharedPreferences? prefs;

  const PuzzleGameScreen({
    super.key,
    required this.imagePath,
    this.prefs,
  });

  @override
  State<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends State<PuzzleGameScreen> {
  static const int gridSize = 4;
  static const int totalPieces = gridSize * gridSize;

  List<Uint8List>? _puzzlePieces;
  List<int?> _piecePositions = List.filled(totalPieces, null); // Index in _puzzlePieces -> position (0-15)
  List<int?> _positionPieces = List.filled(totalPieces, null); // Position (0-15) -> index in _puzzlePieces
  bool _loading = true;
  bool _showReference = false;
  bool _isCompleted = false;
  bool _showingCompletionTile = false;
  String? _goalTitle;
  DateTime? _startTime;
  List<VisionBoardInfo>? _boards;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    final prefs = widget.prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    if (!mounted) return;
    setState(() => _boards = boards);
  }

  Future<void> _loadPuzzle() async {
    setState(() {
      _loading = true;
      _isCompleted = false;
      _showingCompletionTile = false;
      _goalTitle = null;
    });

    try {
      final prefs = widget.prefs ?? await SharedPreferences.getInstance();
      
      // Try to load saved state
      final savedState = await PuzzleStateService.loadPuzzleState(
        imagePath: widget.imagePath,
        prefs: prefs,
      );

      final pieces = await PuzzleImageSplitter.splitImage(
        widget.imagePath,
        gridSize,
      );

      if (!mounted) return;

      if (savedState != null && savedState.imagePath == widget.imagePath) {
        // Load saved state
        setState(() {
          _puzzlePieces = pieces;
          _piecePositions = savedState.piecePositions;
          _positionPieces = savedState.positionPieces;
          _isCompleted = savedState.isCompleted;
          _loading = false;
        });

        // If completed, show completion tile
        if (_isCompleted) {
          await _loadGoalTitle();
          if (mounted) {
            setState(() {
              _showingCompletionTile = true;
            });
          }
        }
      } else {
        // Initialize shuffled state
        final shuffledIndices = PuzzleImageSplitter.shufflePieces(pieces.length);
        final positions = List<int?>.filled(totalPieces, null);
        final positionPieces = List<int?>.filled(totalPieces, null);

        // Place pieces in shuffled positions
        for (int i = 0; i < shuffledIndices.length; i++) {
          final pieceIndex = shuffledIndices[i];
          positions[pieceIndex] = i; // Piece at index pieceIndex is at position i
          positionPieces[i] = pieceIndex; // Position i has piece at index pieceIndex
        }

        setState(() {
          _puzzlePieces = pieces;
          _piecePositions = positions;
          _positionPieces = positionPieces;
          _loading = false;
          _startTime = DateTime.now();
        });

        // Save initial state
        await _saveState();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load puzzle: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadGoalTitle() async {
    final prefs = widget.prefs ?? await SharedPreferences.getInstance();
    if (_boards == null) {
      _boards = await BoardsStorageService.loadBoards(prefs: prefs);
    }
    final goal = await PuzzleService.getGoalForImagePath(
      imagePath: widget.imagePath,
      boards: _boards,
      prefs: prefs,
    );
    if (mounted) {
      setState(() {
        _goalTitle = goal?.title;
      });
    }
  }

  Future<void> _saveState() async {
    final prefs = widget.prefs ?? await SharedPreferences.getInstance();
    await PuzzleStateService.savePuzzleState(
      imagePath: widget.imagePath,
      piecePositions: _piecePositions,
      positionPieces: _positionPieces,
      isCompleted: _isCompleted,
      prefs: prefs,
    );
    // Refresh widget snapshot
    await PuzzleWidgetSnapshotService.refreshBestEffort(prefs: prefs);
  }

  Future<void> _shufflePuzzle() async {
    if (_puzzlePieces == null) return;

    final random = Random();
    final shuffledIndices = List.generate(totalPieces, (i) => i)..shuffle();

    final positions = List<int?>.filled(totalPieces, null);
    final positionPieces = List<int?>.filled(totalPieces, null);

    for (int i = 0; i < shuffledIndices.length; i++) {
      final pieceIndex = shuffledIndices[i];
      positions[pieceIndex] = i;
      positionPieces[i] = pieceIndex;
    }

    setState(() {
      _piecePositions = positions;
      _positionPieces = positionPieces;
      _isCompleted = false;
      _showingCompletionTile = false;
      _startTime = DateTime.now();
    });

    await _saveState();
  }

  Future<void> _movePiece(int pieceIndex, int targetPosition) async {
    if (_piecePositions[pieceIndex] == targetPosition) return; // Already in place

    final oldPosition = _piecePositions[pieceIndex];
    final oldPieceAtTarget = _positionPieces[targetPosition];

    // Swap pieces
    _piecePositions[pieceIndex] = targetPosition;
    _positionPieces[targetPosition] = pieceIndex;

    if (oldPosition != null) {
      _positionPieces[oldPosition] = oldPieceAtTarget;
    }

    if (oldPieceAtTarget != null) {
      _piecePositions[oldPieceAtTarget] = oldPosition;
    }

    setState(() {
      // Check if puzzle is completed
      _checkCompletion();
    });

    // Save state after move
    await _saveState();
  }

  Future<void> _checkCompletion() async {
    if (_puzzlePieces == null) return;

    bool completed = true;
    for (int i = 0; i < totalPieces; i++) {
      if (_piecePositions[i] != i) {
        completed = false;
        break;
      }
    }

    if (completed && !_isCompleted) {
      _isCompleted = true;
      final duration = _startTime != null
          ? DateTime.now().difference(_startTime!)
          : Duration.zero;

      // Save completed state
      await _saveState();

      // Load goal title
      await _loadGoalTitle();

      // Show completion dialog
      await _showCompletionDialog(duration);
    }
  }

  Future<void> _showCompletionDialog(Duration duration) async {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final goalMessage = _goalTitle != null && _goalTitle!.isNotEmpty
        ? 'You are 1 step closer in reaching your goal: $_goalTitle'
        : 'You are 1 step closer in reaching your goal!';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber),
            SizedBox(width: 8),
            Text('Puzzle Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations! You solved the puzzle in ${minutes}m ${seconds}s.',
            ),
            const SizedBox(height: 16),
            Text(
              goalMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _shufflePuzzle();
            },
            child: const Text('Play Again'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Animate tiles flipping back and show completion tile
              _showCompletionTile();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showCompletionTile() {
    setState(() {
      _showingCompletionTile = true;
    });
  }

  Future<void> _selectNewImage() async {
    if (_boards == null) {
      final prefs = widget.prefs ?? await SharedPreferences.getInstance();
      _boards = await BoardsStorageService.loadBoards(prefs: prefs);
    }

    final selected = await showPuzzleImageSelectorSheet(
      context,
      boards: _boards ?? [],
      prefs: widget.prefs,
    );

    if (selected != null && selected != widget.imagePath) {
      // Clear old puzzle state
      final prefs = widget.prefs ?? await SharedPreferences.getInstance();
      await PuzzleStateService.clearPuzzleState(
        imagePath: widget.imagePath,
        prefs: prefs,
      );
      
      await PuzzleService.setPuzzleImage(selected, prefs: widget.prefs);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PuzzleGameScreen(
              imagePath: selected,
              prefs: widget.prefs,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle Game'),
        actions: [
          IconButton(
            icon: Icon(_showReference ? Icons.visibility_off : Icons.visibility),
            tooltip: _showReference ? 'Hide reference' : 'Show reference',
            onPressed: () => setState(() => _showReference = !_showReference),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Shuffle',
            onPressed: _shufflePuzzle,
          ),
          IconButton(
            icon: const Icon(Icons.image_outlined),
            tooltip: 'Select image',
            onPressed: _selectNewImage,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _puzzlePieces == null
              ? const Center(child: Text('Failed to load puzzle'))
              : _showingCompletionTile
                  ? _buildCompletionTile()
                  : _buildPuzzleGrid(),
    );
  }

  Widget _buildPuzzleGrid() {
    return Stack(
      children: [
        // Reference image (optional)
        if (_showReference)
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: _buildReferenceImage(),
            ),
          ),
        // Puzzle grid
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridSize,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: totalPieces,
              itemBuilder: (context, position) {
                return _buildPuzzleSlot(position);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceImage() {
    final provider = fileImageProviderFromPath(widget.imagePath);
    if (provider == null) {
      return Container();
    }
    return Image(
      image: provider,
      fit: BoxFit.contain,
    );
  }

  Widget _buildPuzzleSlot(int position) {
    final pieceIndex = _positionPieces[position];
    final isCorrectPosition = pieceIndex == position;

    return DragTarget<int>(
      onAccept: (draggedPieceIndex) {
        _movePiece(draggedPieceIndex, position);
      },
      builder: (context, candidateData, rejectedData) {
        final isTargeted = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isTargeted
                ? Theme.of(context).colorScheme.primaryContainer
                : isCorrectPosition
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
            border: Border.all(
              color: isTargeted
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: isTargeted ? 2 : 1,
            ),
          ),
          child: pieceIndex != null
              ? _buildPuzzlePiece(pieceIndex, position)
              : Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPuzzlePiece(int pieceIndex, int currentPosition) {
    final pieceBytes = _puzzlePieces![pieceIndex];
    final isCorrectPosition = pieceIndex == currentPosition;

    return Draggable<int>(
      data: pieceIndex,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: Image.memory(
            pieceBytes,
            fit: BoxFit.cover,
          ),
        ),
      ),
      childWhenDragging: Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Icon(
          Icons.image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: isCorrectPosition
              ? Border.all(
                  color: Theme.of(context).colorScheme.tertiary,
                  width: 2,
                )
              : null,
        ),
        child: Image.memory(
          pieceBytes,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildCompletionTile() {
    final goalMessage = _goalTitle != null && _goalTitle!.isNotEmpty
        ? 'You are 1 step closer in reaching your goal: $_goalTitle'
        : 'You are 1 step closer in reaching your goal!';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated completion tile
            TweenAnimationBuilder<double>(
              key: const ValueKey('completion_tile_animation'),
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                // Clamp values to valid range since easeOutBack can overshoot
                final clampedValue = value.clamp(0.0, 1.0);
                return Transform.scale(
                  scale: clampedValue,
                  child: Opacity(
                    opacity: clampedValue,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Background image
                            _buildReferenceImage(),
                            // Overlay with message
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.black.withOpacity(0.9),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.celebration,
                                        color: Colors.amber,
                                        size: 64,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        goalMessage,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
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
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _showingCompletionTile = false;
                });
                _shufflePuzzle();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Play Again'),
            ),
          ],
        ),
      ),
    );
  }
}
