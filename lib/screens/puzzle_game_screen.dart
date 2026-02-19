import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/puzzle_image_splitter.dart';
import '../utils/file_image_provider.dart';
import '../services/puzzle_service.dart';
import '../services/puzzle_state_service.dart';
import '../services/puzzle_widget_snapshot_service.dart';
import '../services/coins_service.dart';
import '../services/subscription_service.dart';
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
  int _gridSize = 6;
  int get _totalPieces => _gridSize * _gridSize;

  List<Uint8List>? _puzzlePieces;
  List<int?> _piecePositions = [];
  List<int?> _positionPieces = [];
  bool _loading = true;
  bool _showReference = false;
  bool _isCompleted = false;
  bool _showingCompletionTile = false;
  String? _goalTitle;
  DateTime? _startTime;
  List<VisionBoardInfo>? _boards;

  bool _onCooldown = false;
  Duration _cooldownRemaining = Duration.zero;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _initCooldownState();
    _loadPuzzle();
    _loadBoards();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  bool get _isSubscribed => SubscriptionService.isSubscribed.value;

  Future<void> _initCooldownState() async {
    if (_isSubscribed) return;
    final remaining = await PuzzleService.getPuzzleCooldownRemaining(
      prefs: widget.prefs,
    );
    if (!mounted) return;
    setState(() {
      _cooldownRemaining = remaining;
      _onCooldown = remaining > Duration.zero;
    });
    if (_onCooldown) _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final remaining = await PuzzleService.getPuzzleCooldownRemaining(
        prefs: widget.prefs,
      );
      if (!mounted) {
        _cooldownTimer?.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining = remaining;
        _onCooldown = remaining > Duration.zero;
      });
      if (!_onCooldown) _cooldownTimer?.cancel();
    });
  }

  String _formatCooldown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  bool get _actionsLocked => !_isSubscribed && _onCooldown;

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
      _piecePositions = List.filled(_totalPieces, null);
      _positionPieces = List.filled(_totalPieces, null);
    });

    try {
      final prefs = widget.prefs ?? await SharedPreferences.getInstance();

      final savedState = await PuzzleStateService.loadPuzzleState(
        imagePath: widget.imagePath,
        prefs: prefs,
      );

      final pieces = await PuzzleImageSplitter.splitImage(
        widget.imagePath,
        _gridSize,
      );

      if (!mounted) return;

      if (savedState != null &&
          savedState.imagePath == widget.imagePath &&
          savedState.piecePositions.length == _totalPieces) {
        setState(() {
          _puzzlePieces = pieces;
          _piecePositions = savedState.piecePositions;
          _positionPieces = savedState.positionPieces;
          _isCompleted = savedState.isCompleted;
          _loading = false;
        });

        if (_isCompleted) {
          await _loadGoalTitle();
          if (mounted) {
            setState(() => _showingCompletionTile = true);
          }
        }
      } else {
        final shuffledIndices =
            PuzzleImageSplitter.shufflePieces(pieces.length);
        final positions = List<int?>.filled(_totalPieces, null);
        final positionPieces = List<int?>.filled(_totalPieces, null);

        for (int i = 0; i < shuffledIndices.length; i++) {
          final pieceIndex = shuffledIndices[i];
          positions[pieceIndex] = i;
          positionPieces[i] = pieceIndex;
        }

        setState(() {
          _puzzlePieces = pieces;
          _piecePositions = positions;
          _positionPieces = positionPieces;
          _loading = false;
          _startTime = DateTime.now();
        });

        await _saveState();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load puzzle: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadGoalTitle() async {
    final prefs = widget.prefs ?? await SharedPreferences.getInstance();
    _boards ??= await BoardsStorageService.loadBoards(prefs: prefs);
    final goal = await PuzzleService.getGoalForImagePath(
      imagePath: widget.imagePath,
      boards: _boards,
      prefs: prefs,
    );
    if (mounted) setState(() => _goalTitle = goal?.title);
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
    await PuzzleWidgetSnapshotService.refreshBestEffort(prefs: prefs);
  }

  Future<void> _shufflePuzzle() async {
    if (_puzzlePieces == null || _actionsLocked) return;

    final shuffledIndices =
        List.generate(_totalPieces, (i) => i)..shuffle();

    final positions = List<int?>.filled(_totalPieces, null);
    final positionPieces = List<int?>.filled(_totalPieces, null);

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

  void _changeGridSize(int newSize) {
    if (newSize == _gridSize || _actionsLocked) return;
    setState(() => _gridSize = newSize);
    // Clear old state so it re-shuffles with the new grid
    PuzzleStateService.clearPuzzleState(
      imagePath: widget.imagePath,
      prefs: widget.prefs,
    );
    _loadPuzzle();
  }

  Future<void> _movePiece(int pieceIndex, int targetPosition) async {
    if (_piecePositions[pieceIndex] == targetPosition) return;

    final oldPosition = _piecePositions[pieceIndex];
    final oldPieceAtTarget = _positionPieces[targetPosition];

    _piecePositions[pieceIndex] = targetPosition;
    _positionPieces[targetPosition] = pieceIndex;

    if (oldPosition != null) _positionPieces[oldPosition] = oldPieceAtTarget;
    if (oldPieceAtTarget != null) _piecePositions[oldPieceAtTarget] = oldPosition;

    setState(() {});
    await _checkCompletion();
    await _saveState();
  }

  Future<void> _checkCompletion() async {
    if (_puzzlePieces == null) return;

    bool completed = true;
    for (int i = 0; i < _totalPieces; i++) {
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

      await _saveState();
      await _loadGoalTitle();

      final earnedCoins = CoinsService.coinsForPuzzleGrid(_gridSize);
      await CoinsService.awardPuzzleCompletion(_gridSize, prefs: widget.prefs);

      if (!_isSubscribed) {
        await PuzzleService.setPuzzleCooldown(prefs: widget.prefs);
        await _initCooldownState();
      }

      await _showCompletionDialog(duration, earnedCoins);
    }
  }

  Future<void> _showCompletionDialog(Duration duration, int earnedCoins) async {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final goalMessage = _goalTitle != null && _goalTitle!.isNotEmpty
        ? 'You are 1 step closer in reaching your goal: $_goalTitle'
        : 'You are 1 step closer in reaching your goal!';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.celebration, color: colorScheme.tertiary),
              const SizedBox(width: 8),
              const Text('Puzzle Completed!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Congratulations! You solved the puzzle in ${minutes}m ${seconds}s.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.monetization_on, color: colorScheme.tertiary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '+$earnedCoins coins earned!',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          color: colorScheme.tertiary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                goalMessage,
                style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
              ),
              if (_actionsLocked) ...[
                const SizedBox(height: 12),
                Text(
                  'Next puzzle available in ${_formatCooldown(_cooldownRemaining)}',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                ),
              ],
            ],
          ),
          actions: [
            if (!_actionsLocked)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _shufflePuzzle();
                },
                child: const Text('Play Again'),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showCompletionTile();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showCompletionTile() {
    setState(() => _showingCompletionTile = true);
  }

  Future<void> _selectNewImage() async {
    if (_actionsLocked) return;

    _boards ??= await BoardsStorageService.loadBoards(
      prefs: widget.prefs ?? await SharedPreferences.getInstance(),
    );

    final selected = await showPuzzleImageSelectorSheet(
      context,
      boards: _boards ?? [],
      prefs: widget.prefs,
    );

    if (selected != null && selected != widget.imagePath) {
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

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzle Game'),
        actions: [
          IconButton(
            icon: Icon(
                _showReference ? Icons.visibility_off : Icons.visibility),
            tooltip: _showReference ? 'Hide reference' : 'Show reference',
            onPressed: () =>
                setState(() => _showReference = !_showReference),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: _actionsLocked
                ? 'Available in ${_formatCooldown(_cooldownRemaining)}'
                : 'Shuffle',
            onPressed: _actionsLocked ? null : _shufflePuzzle,
          ),
          IconButton(
            icon: const Icon(Icons.image_outlined),
            tooltip: _actionsLocked ? 'Locked during cooldown' : 'Select image',
            onPressed: _actionsLocked ? null : _selectNewImage,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildGridSizeSelector(scheme),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _puzzlePieces == null
                    ? const Center(child: Text('Failed to load puzzle'))
                    : _showingCompletionTile
                        ? _buildCompletionTile()
                        : _buildPuzzleGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSizeSelector(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 6,
                  label: Text('6x6  (${CoinsService.puzzle6x6Coins} pts)'),
                ),
                ButtonSegment(
                  value: 12,
                  label: Text('12x12  (${CoinsService.puzzle12x12Coins} pts)'),
                ),
              ],
              selected: {_gridSize},
              onSelectionChanged: _actionsLocked
                  ? null
                  : (s) => _changeGridSize(s.first),
            ),
          ),
          if (_actionsLocked) ...[
            const SizedBox(width: 12),
            Tooltip(
              message: 'Cooldown active',
              child: Chip(
                avatar: Icon(Icons.timer, size: 16, color: scheme.error),
                label: Text(
                  _formatCooldown(_cooldownRemaining),
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPuzzleGrid() {
    return Stack(
      children: [
        if (_showReference)
          Positioned.fill(
            child: Opacity(opacity: 0.3, child: _buildReferenceImage()),
          ),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridSize,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: _totalPieces,
              itemBuilder: (context, position) => _buildPuzzleSlot(position),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceImage() {
    final provider = fileImageProviderFromPath(widget.imagePath);
    if (provider == null) return Container();
    return Image(image: provider, fit: BoxFit.contain);
  }

  Widget _buildPuzzleSlot(int position) {
    final pieceIndex = _positionPieces[position];
    final isCorrectPosition = pieceIndex == position;

    return DragTarget<int>(
      onAccept: (draggedPieceIndex) => _movePiece(draggedPieceIndex, position),
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
                    size: _gridSize > 6 ? 16 : 32,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPuzzlePiece(int pieceIndex, int currentPosition) {
    final pieceBytes = _puzzlePieces![pieceIndex];
    final isCorrectPosition = pieceIndex == currentPosition;
    final feedbackSize = _gridSize > 6 ? 50.0 : 80.0;

    return Draggable<int>(
      data: pieceIndex,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: feedbackSize,
          height: feedbackSize,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: Image.memory(pieceBytes, fit: BoxFit.cover),
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
        child: Image.memory(pieceBytes, fit: BoxFit.cover),
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
            TweenAnimationBuilder<double>(
              key: const ValueKey('completion_tile_animation'),
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
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
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
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
                            _buildReferenceImage(),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Theme.of(context).colorScheme.shadow.withOpacity(0.7),
                                    Theme.of(context).colorScheme.shadow.withOpacity(0.9),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.celebration,
                                          color: Theme.of(context).colorScheme.tertiary, size: 64),
                                      const SizedBox(height: 16),
                                      Text(
                                        goalMessage,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              color: Theme.of(context).colorScheme.surface,
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
            if (!_actionsLocked)
              FilledButton.icon(
                onPressed: () {
                  setState(() => _showingCompletionTile = false);
                  _shufflePuzzle();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Play Again'),
              )
            else
              Text(
                'Next puzzle available in ${_formatCooldown(_cooldownRemaining)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
