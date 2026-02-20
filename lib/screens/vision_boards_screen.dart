import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_board_info.dart';
import '../utils/app_typography.dart';
import '../models/grid_tile_model.dart';
import '../services/boards_storage_service.dart';
import '../services/grid_tiles_storage_service.dart';
import '../utils/file_image_provider.dart';
import 'wizard/create_board_wizard_screen.dart';

class VisionBoardsScreen extends StatefulWidget {
  final VoidCallback onCreateBoard;
  final ValueChanged<VisionBoardInfo> onOpenEditor;
  final ValueChanged<VisionBoardInfo> onOpenViewer;
  final ValueChanged<VisionBoardInfo> onDeleteBoard;

  const VisionBoardsScreen({
    super.key,
    required this.onCreateBoard,
    required this.onOpenEditor,
    required this.onOpenViewer,
    required this.onDeleteBoard,
  });

  @override
  State<VisionBoardsScreen> createState() => _VisionBoardsScreenState();
}

class _VisionBoardsScreenState extends State<VisionBoardsScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List<VisionBoardInfo> _boards = [];
  String? _activeBoardId;
  bool _loaded = false;
  SharedPreferences? _prefs;

  late PageController _pageController;
  int _currentPage = 0;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  Map<String, List<GridTileModel>> _tilesCache = {};

  static const double _viewportFraction = 0.68;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: _viewportFraction,
    );
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _entranceController.dispose();
    super.dispose();
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

    final tilesCache = <String, List<GridTileModel>>{};
    for (final board in boards) {
      tilesCache[board.id] = await GridTilesStorageService.loadTiles(board.id, prefs: prefs);
    }

    if (mounted) {
      setState(() {
        _boards = boards;
        _activeBoardId = activeId;
        _tilesCache = tilesCache;
        _loaded = true;
      });
      _entranceController.forward();
    }
  }

  Future<void> _selectBoard(VisionBoardInfo board) async {
    await BoardsStorageService.setActiveBoardId(board.id, prefs: _prefs);
    if (mounted) setState(() => _activeBoardId = board.id);
  }

  Future<void> _createBoard() async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateBoardWizardScreen()),
    );
    if (mounted && res == true) _load();
  }

  void _confirmDelete(VisionBoardInfo board) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Board?'),
        content: Text(
          'This will permanently delete "${board.title}" and all its content. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteBoard(board);
              Future.delayed(const Duration(milliseconds: 500), () => _load());
            },
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasBoards = _boards.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Vision Boards')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : !hasBoards
              ? _buildEmptyState(colorScheme)
              : _buildCarousel(colorScheme),
      bottomNavigationBar: _loaded && hasBoards
          ? _VisionBoardsBottomBar(
              onEdit: _currentPage < _boards.length
                  ? () async {
                      widget.onOpenEditor(_boards[_currentPage]);
                      await Future.delayed(const Duration(milliseconds: 500));
                      _load();
                    }
                  : null,
              onDelete: _currentPage < _boards.length
                  ? () => _confirmDelete(_boards[_currentPage])
                  : null,
              onAdd: _createBoard,
            )
          : null,
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Vision Boards Yet',
              style: AppTypography.heading1(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first vision board to get started.',
              style: AppTypography.secondary(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createBoard,
              icon: const Icon(Icons.add),
              label: const Text('Create Board'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(ColorScheme colorScheme) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final appBarH = kToolbarHeight + topPad;
    const bottomBarH = _VisionBoardsBottomBar._totalHeight;
    final available = size.height - appBarH - bottomBarH - 48;
    final cardHeight = math.min(520.0, available * 0.82);
    final totalItems = _boards.length + 1;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalItems,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  if (page < _boards.length) {
                    _selectBoard(_boards[page]);
                  }
                },
                itemBuilder: (context, index) {
                  if (index == _boards.length) {
                    return _AddBoardCard(
                      onTap: _createBoard,
                      isActive: _currentPage == index,
                    );
                  }
                  final board = _boards[index];
                  final isActive = _currentPage == index;
                  final tiles = _tilesCache[board.id] ?? [];

                  return AnimatedScale(
                    scale: isActive ? 1.0 : 0.88,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: isActive ? 1.0 : 0.55,
                      duration: const Duration(milliseconds: 200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: _BoardCard(
                          board: board,
                          tiles: tiles,
                          isActive: isActive,
                          onTap: () => widget.onOpenViewer(board),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_currentPage < _boards.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _boards[_currentPage].id == _activeBoardId ? 'Active Board' : 'Tap to view',
                  style: AppTypography.secondary(context).copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Board card – tall rectangle with image collage
// ---------------------------------------------------------------------------

class _BoardCard extends StatelessWidget {
  final VisionBoardInfo board;
  final List<GridTileModel> tiles;
  final bool isActive;
  final VoidCallback onTap;

  const _BoardCard({
    required this.board,
    required this.tiles,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = Color(board.tileColorValue);
    final imageTiles = tiles
        .where((t) => t.type == 'image' && (t.content ?? '').trim().isNotEmpty)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHigh : tileColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.25),
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: isDark ? 0.4 : 0.12),
              offset: const Offset(4, 8),
              blurRadius: 24,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: imageTiles.isEmpty
                  ? _buildPlaceholder(context, tileColor)
                  : _buildImageCollage(context, imageTiles),
            ),
            _buildTitleBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCollage(BuildContext context, List<GridTileModel> imageTiles) {
    if (imageTiles.length == 1) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _buildTileImage(context, imageTiles.first),
        ),
      );
    }

    const spacing = 3.0;
    final displayTiles = imageTiles.take(6).toList();

    return Padding(
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: StaggeredGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          children: [
            for (int i = 0; i < displayTiles.length; i++)
              StaggeredGridTile.count(
                crossAxisCellCount: (i == 0 && displayTiles.length >= 3) ? 2 : 1,
                mainAxisCellCount: 1,
                child: _buildTileImage(context, displayTiles[i]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTileImage(BuildContext context, GridTileModel tile) {
    final imagePath = (tile.content ?? '').trim();
    final provider = fileImageProviderFromPath(imagePath);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: provider != null
          ? SizedBox.expand(
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _emptyTile(context),
              ),
            )
          : _emptyTile(context),
    );
  }

  Widget _emptyTile(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
      child: Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
        size: 20,
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, Color tileColor) {
    final iconColor = tileColor.computeLuminance() < 0.45 ? Colors.white : Colors.black87;
    return Container(
      color: tileColor.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          boardIconFromCodePoint(board.iconCodePoint),
          size: 56,
          color: iconColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            board.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(context).copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${tiles.where((t) => t.type == 'image').length} images · ${tiles.length} tiles',
            style: AppTypography.secondary(context).copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add board card at end of carousel
// ---------------------------------------------------------------------------

class _AddBoardCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _AddBoardCard({required this.onTap, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
        : colorScheme.surfaceContainerLow.withValues(alpha: 0.7);
    final borderColor = isDark
        ? colorScheme.outlineVariant.withValues(alpha: 0.3)
        : colorScheme.outlineVariant.withValues(alpha: 0.4);

    return AnimatedScale(
      scale: isActive ? 1.0 : 0.88,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.55,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: isDark ? 0.3 : 0.08),
                    offset: const Offset(4, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 34,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'New Board',
                    style: AppTypography.heading3(context).copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom bar – matches main screen's animated nav bar aesthetic
// ---------------------------------------------------------------------------

class _VisionBoardsBottomBar extends StatefulWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onAdd;

  static const double _barHeight = 64.0;
  static const double _circleOverflow = 20.0;
  static const double _totalHeight = _barHeight + _circleOverflow;

  const _VisionBoardsBottomBar({
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  State<_VisionBoardsBottomBar> createState() => _VisionBoardsBottomBarState();
}

class _VisionBoardsBottomBarState extends State<_VisionBoardsBottomBar>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late AnimationController _tapController;
  late Animation<double> _tapScale;

  static const double _barHeight = _VisionBoardsBottomBar._barHeight;
  static const double _circleOverflow = _VisionBoardsBottomBar._circleOverflow;
  static const double _centerBtnSize = 52.0;
  static const double _centerBtnBorder = 4.0;
  static const double _centerBtnTotalRadius = (_centerBtnSize + 2 * _centerBtnBorder) / 2;
  static const double _centerCutoutRadius = _centerBtnTotalRadius + 4.0;
  static const double _centerCutoutCenterY = _centerBtnTotalRadius - _circleOverflow;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_tapController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  Future<void> _handleCenterTap() async {
    _pulseController.stop();
    await _tapController.forward(from: 0.0);
    widget.onAdd();
    if (mounted) _pulseController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final totalHeight = _barHeight + _circleOverflow + bottomPadding;
    final hasActions = widget.onEdit != null || widget.onDelete != null;

    return SizedBox(
      height: totalHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final centerX = totalWidth / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Bar body
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _barHeight + bottomPadding,
                child: CustomPaint(
                  painter: _CenterNotchBarPainter(
                    centerX: centerX,
                    cutoutCenterY: _centerCutoutCenterY,
                    cutoutRadius: _centerCutoutRadius,
                    color: colorScheme.onSurface,
                    shadowColor: colorScheme.shadow,
                  ),
                  size: Size(totalWidth, _barHeight + bottomPadding),
                ),
              ),

              // Side icons
              if (hasActions)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomPadding,
                  height: _barHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: widget.onEdit != null
                            ? _BarIconButton(
                                icon: Icons.edit_outlined,
                                label: 'Edit',
                                color: colorScheme.outlineVariant,
                                onTap: widget.onEdit!,
                              )
                            : const SizedBox.shrink(),
                      ),
                      SizedBox(width: _centerBtnTotalRadius * 2 + 24),
                      Expanded(
                        child: widget.onDelete != null
                            ? _BarIconButton(
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete',
                                color: colorScheme.outlineVariant,
                                onTap: widget.onDelete!,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

              // Center "+" button
              Positioned(
                left: centerX - _centerBtnTotalRadius,
                top: 0,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseController, _tapController]),
                  builder: (context, _) {
                    final isTapping = _tapController.isAnimating;
                    final scale = isTapping ? _tapScale.value : _pulseScale.value;
                    final glowOpacity = isTapping
                        ? 0.5
                        : 0.25 + (_pulseScale.value - 1.0) * 2.5;

                    return GestureDetector(
                      onTap: _handleCenterTap,
                      behavior: HitTestBehavior.opaque,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: _centerBtnSize + _centerBtnBorder * 2,
                          height: _centerBtnSize + _centerBtnBorder * 2,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: _centerBtnBorder,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary
                                    .withOpacity(glowOpacity.clamp(0.0, 1.0)),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: colorScheme.onPrimary,
                            size: 26,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BarIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notched bar painter – center cutout only
// ---------------------------------------------------------------------------

class _CenterNotchBarPainter extends CustomPainter {
  final double centerX;
  final double cutoutCenterY;
  final double cutoutRadius;
  final Color color;
  final Color shadowColor;

  _CenterNotchBarPainter({
    required this.centerX,
    required this.cutoutCenterY,
    required this.cutoutRadius,
    required this.color,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutout = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(centerX, cutoutCenterY),
        radius: cutoutRadius,
      ));

    final result = Path.combine(PathOperation.difference, barPath, cutout);
    canvas.drawShadow(result, shadowColor, 10.0, true);
    canvas.drawPath(result, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CenterNotchBarPainter old) =>
      old.centerX != centerX || old.color != color;
}
