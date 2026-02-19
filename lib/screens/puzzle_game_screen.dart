import 'dart:async';
import 'dart:typed_data';
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
  int _gridSize = 4;
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
        title: const Text('Puzzle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            tooltip: _actionsLocked ? 'Locked during cooldown' : 'Change image',
            onPressed: _actionsLocked ? null : _selectNewImage,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _puzzlePieces == null
                      ? const Center(child: Text('Failed to load puzzle'))
                      : _showingCompletionTile
                          ? _buildCompletionTile(scheme)
                          : _showReference
                              ? _buildReferenceView(scheme)
                              : _buildBoardArea(scheme),
            ),
            _buildControlsBar(scheme),
            if (_actionsLocked)
              _buildCooldownBanner(scheme),
          ],
        ),
      ),
    );
  }

  // ── Reference image (full view, replaces board) ────────────────────

  Widget _buildReferenceView(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380, maxHeight: 380),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildReferenceImage(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reference Image',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the eye icon to return to the puzzle',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceImage() {
    final provider = fileImageProviderFromPath(widget.imagePath);
    if (provider == null) return const SizedBox.shrink();
    return Image(image: provider, fit: BoxFit.cover);
  }

  // ── Styled puzzle board area ───────────────────────────────────────

  Widget _buildBoardArea(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.15),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(6),
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
        ),
      ),
    );
  }

  Widget _buildPuzzleSlot(int position) {
    final pieceIndex = _positionPieces[position];
    final isCorrectPosition = pieceIndex == position;
    final scheme = Theme.of(context).colorScheme;

    return DragTarget<int>(
      onAccept: (draggedPieceIndex) => _movePiece(draggedPieceIndex, position),
      builder: (context, candidateData, rejectedData) {
        final isTargeted = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isTargeted
                ? scheme.primaryContainer
                : isCorrectPosition
                    ? scheme.tertiaryContainer
                    : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: isTargeted
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: 0.2),
              width: isTargeted ? 2 : 0.5,
            ),
          ),
          child: pieceIndex != null
              ? _buildPuzzlePiece(pieceIndex, position)
              : Center(
                  child: Icon(
                    Icons.extension_outlined,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    size: _gridSize > 4 ? 12 : 24,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPuzzlePiece(int pieceIndex, int currentPosition) {
    final pieceBytes = _puzzlePieces![pieceIndex];
    final isCorrectPosition = pieceIndex == currentPosition;
    final feedbackSize = _gridSize > 4 ? 50.0 : 80.0;
    final scheme = Theme.of(context).colorScheme;

    return Draggable<int>(
      data: pieceIndex,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: feedbackSize,
          height: feedbackSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: scheme.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Image.memory(pieceBytes, fit: BoxFit.cover),
          ),
        ),
      ),
      childWhenDragging: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: isCorrectPosition
              ? Border.all(color: scheme.tertiary, width: 1.5)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: Image.memory(pieceBytes, fit: BoxFit.cover),
        ),
      ),
    );
  }

  // ── Controls bar ───────────────────────────────────────────────────

  Widget _buildControlsBar(ColorScheme scheme) {
    final isEasy = _gridSize == 4;
    final ptsColor = scheme.onPrimaryContainer.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                Expanded(
                  child: Center(
                    child: Text(
                      '${CoinsService.puzzle4x4Coins}pts',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: ptsColor,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${CoinsService.puzzle8x8Coins}pts',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: ptsColor,
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _buildControlItem(
                    icon: _showReference
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    label: _showReference ? 'Hide' : 'Peek',
                    isActive: _showReference,
                    onTap: () =>
                        setState(() => _showReference = !_showReference),
                    scheme: scheme,
                  ),
                ),
                Expanded(
                  child: _buildControlItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Easy',
                    isActive: isEasy,
                    onTap: _actionsLocked
                        ? null
                        : () => _changeGridSize(4),
                    scheme: scheme,
                  ),
                ),
                Expanded(
                  child: _buildControlItem(
                    icon: Icons.apps_rounded,
                    label: 'Hard',
                    isActive: !isEasy,
                    onTap: _actionsLocked
                        ? null
                        : () => _changeGridSize(8),
                    scheme: scheme,
                  ),
                ),
                Expanded(
                  child: _buildControlItem(
                    icon: Icons.shuffle_rounded,
                    label: 'Shuffle',
                    isActive: false,
                    onTap: _actionsLocked ? null : _shufflePuzzle,
                    scheme: scheme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback? onTap,
    required ColorScheme scheme,
  }) {
    final isDisabled = onTap == null;
    final color = isDisabled
        ? scheme.onPrimaryContainer.withValues(alpha: 0.3)
        : isActive
            ? scheme.primary
            : scheme.onPrimaryContainer;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? scheme.primary.withValues(alpha: 0.15)
                  : scheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Cooldown banner ────────────────────────────────────────────────

  Widget _buildCooldownBanner(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, size: 16, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Text(
              'Next puzzle in ${_formatCooldown(_cooldownRemaining)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Completion tile ────────────────────────────────────────────────

  Widget _buildCompletionTile(ColorScheme scheme) {
    final goalMessage = _goalTitle != null && _goalTitle!.isNotEmpty
        ? 'You are 1 step closer\nin reaching your goal!'
        : 'You are 1 step closer\nin reaching your goal!';

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
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildReferenceImage(),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Icon(Icons.celebration, color: scheme.tertiary, size: 40),
            const SizedBox(height: 8),
            Text(
              goalMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
            ),
            if (_goalTitle != null && _goalTitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _goalTitle!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
            ],
            const SizedBox(height: 24),
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
                      color: scheme.error,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
