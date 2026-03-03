import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/puzzle_game_screen.dart';
import '../../utils/app_typography.dart';
import '../../services/image_service.dart';
import '../../services/puzzle_service.dart';
import '../../services/puzzle_state_service.dart';
import '../../utils/file_image_provider.dart';
import '../../utils/puzzle_image_splitter.dart';
import 'glass_card.dart';

class PuzzleSummaryCard extends StatefulWidget {
  const PuzzleSummaryCard({super.key});

  @override
  State<PuzzleSummaryCard> createState() => _PuzzleSummaryCardState();
}

class _PuzzleSummaryCardState extends State<PuzzleSummaryCard>
    with WidgetsBindingObserver {
  String? _imagePath;
  bool _isCompleted = false;
  bool _loaded = false;
  SharedPreferences? _prefs;
  List<Uint8List>? _previewPieces;
  List<int?> _previewPositionPieces = const [];
  int _previewGridSize = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final imagePath = await PuzzleService.getCurrentPuzzleImage(prefs: prefs);

    bool completed = false;
    List<Uint8List>? previewPieces;
    List<int?> previewPositionPieces = const [];
    int previewGridSize = 0;

    if (imagePath != null && imagePath.isNotEmpty) {
      final puzzleState = await PuzzleStateService.loadPuzzleState(
        imagePath: imagePath,
        prefs: prefs,
      );
      completed = puzzleState?.isCompleted ?? false;

      if (puzzleState != null &&
          !completed &&
          puzzleState.positionPieces.isNotEmpty) {
        final inferredGridSize = _inferGridSize(puzzleState.positionPieces.length);
        if (inferredGridSize > 1) {
          try {
            previewPieces = await PuzzleImageSplitter.splitImage(
              imagePath,
              inferredGridSize,
            );
            previewPositionPieces = puzzleState.positionPieces;
            previewGridSize = inferredGridSize;
          } catch (_) {}
        }
      }
    }

    if (mounted) {
      setState(() {
        _imagePath = imagePath;
        _isCompleted = completed;
        _previewPieces = previewPieces;
        _previewPositionPieces = previewPositionPieces;
        _previewGridSize = previewGridSize;
        _loaded = true;
      });
    }
  }

  int _inferGridSize(int count) {
    if (count <= 0) return 0;
    final root = math.sqrt(count).round();
    if (root * root != count) return 0;
    return root;
  }

  Future<void> _openPuzzle() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    String resolvedPath;
    final current = _imagePath;

    if (current == null || current.isEmpty) {
      if (!mounted) return;
      final cropped = await ImageService.pickAndCropPuzzleImage(
        context,
        source: ImageSource.gallery,
      );
      if (cropped == null || !mounted) return;
      await PuzzleService.setPuzzleImage(cropped, prefs: prefs);
      resolvedPath = cropped;
    } else {
      resolvedPath = current;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleGameScreen(
          imagePath: resolvedPath,
          prefs: prefs,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      onTap: _openPuzzle,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  Icons.extension_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Puzzle',
                    style: AppTypography.heading3(context).copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: colorScheme.onPrimaryContainer
                      .withValues(alpha: 0.6),
                ),
              ],
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_loaded)
                    SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        backgroundColor:
                            colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                      ),
                    )
                  else if (_imagePath != null) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: (_previewPieces != null &&
                                _previewPositionPieces.isNotEmpty &&
                                !_isCompleted)
                            ? _buildPuzzleBoardPreview(colorScheme)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  color: colorScheme.surface.withValues(alpha: 0.35),
                                  child: Image(
                                    image: fileImageProviderFromPath(_imagePath!) ??
                                        const AssetImage('assets/placeholder.png')
                                            as ImageProvider,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stack) => Icon(
                                      Icons.extension_rounded,
                                      size: 36,
                                      color: colorScheme.onPrimaryContainer
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                            ),
                      ),
                    ),
                    if (_previewPieces != null &&
                        _previewPositionPieces.isNotEmpty &&
                        !_isCompleted) ...[
                      const SizedBox(height: 8),
                      Text(
                        'In progress',
                        style: AppTypography.caption(context).copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ] else ...[
                    Icon(
                      Icons.extension_outlined,
                      color: colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.5),
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No puzzle yet',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      'Tap to start',
                      style: AppTypography.caption(context).copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzleBoardPreview(ColorScheme colorScheme) {
    final pieces = _previewPieces!;
    final gridSize = _previewGridSize;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: colorScheme.surface.withValues(alpha: 0.35),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(4),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            crossAxisSpacing: 1.5,
            mainAxisSpacing: 1.5,
          ),
          itemCount: _previewPositionPieces.length,
          itemBuilder: (context, position) {
            final pieceIndex = _previewPositionPieces[position];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: colorScheme.surfaceContainerHighest,
              ),
              child: (pieceIndex != null &&
                      pieceIndex >= 0 &&
                      pieceIndex < pieces.length)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.memory(
                        pieces[pieceIndex],
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.extension_outlined,
                      size: 10,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
            );
          },
        ),
      ),
    );
  }
}
