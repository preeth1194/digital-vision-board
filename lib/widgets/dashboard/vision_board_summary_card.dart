import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../screens/vision_boards_screen.dart';
import '../../services/boards_storage_service.dart';

class VisionBoardSummaryCard extends StatefulWidget {
  final VoidCallback onCreateBoard;
  final ValueChanged<VisionBoardInfo> onOpenEditor;
  final ValueChanged<VisionBoardInfo> onOpenViewer;
  final ValueChanged<VisionBoardInfo> onDeleteBoard;

  const VisionBoardSummaryCard({
    super.key,
    required this.onCreateBoard,
    required this.onOpenEditor,
    required this.onOpenViewer,
    required this.onDeleteBoard,
  });

  @override
  State<VisionBoardSummaryCard> createState() => _VisionBoardSummaryCardState();
}

class _VisionBoardSummaryCardState extends State<VisionBoardSummaryCard>
    with WidgetsBindingObserver {
  List<VisionBoardInfo> _boards = [];
  VisionBoardInfo? _activeBoard;
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
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    final activeId = await BoardsStorageService.loadActiveBoardId(prefs: prefs);

    VisionBoardInfo? active;
    if (activeId != null) {
      active = boards.cast<VisionBoardInfo?>().firstWhere(
            (b) => b?.id == activeId,
            orElse: () => null,
          );
    }
    active ??= boards.isNotEmpty ? boards.first : null;

    if (mounted) {
      setState(() {
        _boards = boards;
        _activeBoard = active;
        _loaded = true;
      });
    }
  }

  void _openVisionBoards() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisionBoardsScreen(
          onCreateBoard: widget.onCreateBoard,
          onOpenEditor: widget.onOpenEditor,
          onOpenViewer: widget.onOpenViewer,
          onDeleteBoard: widget.onDeleteBoard,
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
        onTap: _openVisionBoards,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.dashboard_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vision Board',
                      style: TextStyle(
                        fontSize: 13,
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
                              colorScheme.onPrimary.withValues(alpha: 0.3),
                        ),
                      )
                    else if (_activeBoard != null) ...[
                      Icon(
                        boardIconFromCodePoint(_activeBoard!.iconCodePoint),
                        size: 36,
                        color: Color(_activeBoard!.tileColorValue),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activeBoard!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '${_boards.length} board${_boards.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.dashboard_outlined,
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.5),
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No boards yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        'Tap to create',
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
