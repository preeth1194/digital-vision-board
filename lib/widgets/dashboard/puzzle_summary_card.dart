import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/puzzle_game_screen.dart';
import '../../services/image_service.dart';
import '../../services/puzzle_service.dart';
import '../../services/puzzle_state_service.dart';
import '../../utils/file_image_provider.dart';

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
    if (imagePath != null && imagePath.isNotEmpty) {
      final puzzleState = await PuzzleStateService.loadPuzzleState(
        imagePath: imagePath,
        prefs: prefs,
      );
      completed = puzzleState?.isCompleted ?? false;
    }

    if (mounted) {
      setState(() {
        _imagePath = imagePath;
        _isCompleted = completed;
        _loaded = true;
      });
    }
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Puzzle',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image(
                              image: fileImageProviderFromPath(_imagePath!) ??
                                  const AssetImage('assets/placeholder.png')
                                      as ImageProvider,
                              fit: BoxFit.cover,
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
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        'Tap to start',
                        style: TextStyle(
                          fontSize: 12,
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
      ),
    );
  }
}
