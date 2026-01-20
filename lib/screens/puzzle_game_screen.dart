import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/puzzle_image_splitter.dart';
import '../utils/file_image_provider.dart';
import '../services/puzzle_service.dart';
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
    });

    try {
      final pieces = await PuzzleImageSplitter.splitImage(
        widget.imagePath,
        gridSize,
      );

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

      if (!mounted) return;
      setState(() {
        _puzzlePieces = pieces;
        _piecePositions = positions;
        _positionPieces = positionPieces;
        _loading = false;
        _startTime = DateTime.now();
      });
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

  void _shufflePuzzle() {
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
      _startTime = DateTime.now();
    });
  }

  void _movePiece(int pieceIndex, int targetPosition) {
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
  }

  void _checkCompletion() {
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

      // Show completion dialog
      _showCompletionDialog(duration);
    }
  }

  Future<void> _showCompletionDialog(Duration duration) async {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

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
        content: Text(
          'Congratulations! You solved the puzzle in ${minutes}m ${seconds}s.',
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
}
