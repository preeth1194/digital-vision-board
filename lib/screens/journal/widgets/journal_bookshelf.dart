import 'package:flutter/material.dart';

import '../../../models/journal_book.dart';
import '../../../services/journal_book_storage_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/app_typography.dart';

/// Gradient pairs matching the habit color system, aligned with
/// [JournalBook.presetColors] order.
const List<List<Color>> _coverGradients = [
  [AppColors.habitRedLight, AppColors.habitRedDark],
  [AppColors.habitOrangeLight, AppColors.habitOrangeDark],
  [AppColors.habitYellowLight, AppColors.habitYellowDark],
  [AppColors.habitGreenLight, AppColors.habitGreenDark],
  [AppColors.habitBlueLight, AppColors.habitBlueDark],
  [AppColors.habitIndigoLight, AppColors.habitIndigoDark],
  [AppColors.habitVioletLight, AppColors.habitVioletDark],
];

enum _OverlayMode { colorPicker, deleteConfirm, userBookActions }

/// A bookshelf layout for journal books.
///
/// Renders a top row of featured book covers, two wood shelf lines, and a
/// scrollable row of user-created book spines at the bottom.
class JournalBookshelf extends StatefulWidget {
  final List<JournalBook> books;
  final Map<String, int> entryCounts;
  final int recipeCount;
  final void Function(JournalBook) onBookTap;
  final VoidCallback onAddBook;
  final void Function(String bookId, int color) onColorChanged;
  final void Function(String bookId) onDeleteBook;

  const JournalBookshelf({
    super.key,
    required this.books,
    required this.entryCounts,
    this.recipeCount = 0,
    required this.onBookTap,
    required this.onAddBook,
    required this.onColorChanged,
    required this.onDeleteBook,
  });

  @override
  State<JournalBookshelf> createState() => _JournalBookshelfState();
}

class _JournalBookshelfState extends State<JournalBookshelf>
    with SingleTickerProviderStateMixin {
  late AnimationController _overlayController;
  OverlayEntry? _overlayEntry;

  static const Set<String> _systemBookIds = {
    JournalBookStorageService.defaultBookId,
    JournalBookStorageService.goalLogsBookId,
    JournalBookStorageService.recipeBookId,
  };

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _overlayController.dispose();
    super.dispose();
  }

  // ─── Book helpers ─────────────────────────────────────────────────────────

  int _displayCountForBook(JournalBook book) {
    final isRecipeBook =
        book.id == JournalBookStorageService.recipeBookId;
    if (isRecipeBook) return widget.recipeCount;
    return widget.entryCounts[book.id] ?? 0;
  }

  JournalBook? _bookById(String id) {
    try {
      return widget.books.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  List<JournalBook> get _userBooks =>
      widget.books.where((b) => !_systemBookIds.contains(b.id)).toList();

  // ─── Gradient helpers ─────────────────────────────────────────────────────

  List<Color> _gradientFor(int? colorValue) {
    final base = Color(colorValue ?? JournalBook.defaultCoverColor);
    return [
      Color.lerp(base, Colors.white, 0.25) ?? base,
      base,
    ];
  }

  List<Color> _spineGradient(int? colorValue) {
    final base = Color(colorValue ?? JournalBook.defaultCoverColor);
    return [
      Color.lerp(base, Colors.white, 0.2) ?? base,
      base,
      Color.lerp(base, Colors.black, 0.15) ?? base,
    ];
  }

  // ─── Overlay helpers ──────────────────────────────────────────────────────

  void _showOverlay(_OverlayMode mode, JournalBook book) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (_) => _JournalOverlayPanel(
        animation: _overlayController,
        mode: mode,
        book: book,
        entryCount: _displayCountForBook(book),
        onDismiss: _hideOverlay,
        onColorApplied: (color) {
          widget.onColorChanged(book.id, color);
          _hideOverlay();
        },
        onDeleteConfirmed: () {
          _hideOverlay();
          widget.onDeleteBook(book.id);
        },
        onSwitchToColorPicker: () {
          _overlayController.reset();
          _showOverlay(_OverlayMode.colorPicker, book);
        },
        onSwitchToDelete: () {
          _overlayController.reset();
          _showOverlay(_OverlayMode.deleteConfirm, book);
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    _overlayController.forward();
  }

  void _hideOverlay() {
    _overlayController.reverse().then((_) {
      _removeOverlay();
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  void _showColorPicker(JournalBook book) =>
      _showOverlay(_OverlayMode.colorPicker, book);

  void _showUserBookActions(JournalBook book) =>
      _showOverlay(_OverlayMode.userBookActions, book);

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionLabel(context, 'DEFAULT BOOKS', colorScheme),
        _buildDefaultRow(context),
        _buildShelfLine(),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionLabel(context, 'MY BOOKS', colorScheme),
        _buildUserSpinesRow(context),
        _buildShelfLine(),
      ],
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String label,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        bottom: 4,
        top: AppSpacing.xs,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface.withValues(alpha: 0.38),
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  // ─── Default row (3 featured covers) ─────────────────────────────────────

  Widget _buildDefaultRow(BuildContext context) {
    final defaultBook = _bookById(JournalBookStorageService.defaultBookId);
    final goalLogsBook = _bookById(JournalBookStorageService.goalLogsBookId);
    final recipeBook = _bookById(JournalBookStorageService.recipeBookId);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (defaultBook != null)
            Expanded(
              flex: 5,
              child: _DefaultBookCover(
                book: defaultBook,
                height: 144,
                gradient: _gradientFor(defaultBook.coverColor),
                onTap: () => widget.onBookTap(defaultBook),
                onLongPress: () => _showColorPicker(defaultBook),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          if (goalLogsBook != null)
            Expanded(
              flex: 5,
              child: _DefaultBookCover(
                book: goalLogsBook,
                height: 144,
                gradient: _gradientFor(goalLogsBook.coverColor),
                onTap: () => widget.onBookTap(goalLogsBook),
                onLongPress: () => _showColorPicker(goalLogsBook),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          if (recipeBook != null)
            Expanded(
              flex: 3,
              child: _DefaultBookCover(
                book: recipeBook,
                height: 144,
                gradient: _gradientFor(recipeBook.coverColor),
                onTap: () => widget.onBookTap(recipeBook),
                onLongPress: () => _showColorPicker(recipeBook),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Wood shelf line ──────────────────────────────────────────────────────

  Widget _buildShelfLine() {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.shelfWoodLight,
            AppColors.shelfWoodMid,
            AppColors.honeyText,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  // ─── User spines row ──────────────────────────────────────────────────────

  Widget _buildUserSpinesRow(BuildContext context) {
    final userBooks = _userBooks;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Show exactly 4 books + hint of 5th before scroll kicks in
        const visibleBooks = 4.4;
        const spineMarginTotal = 6.0;
        final availableWidth = constraints.maxWidth - 2 * AppSpacing.md;
        final spineWidth =
            (availableWidth / visibleBooks - spineMarginTotal).clamp(52.0, 88.0);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ...userBooks.map((book) {
                  final entryCount = _displayCountForBook(book);
                  final spineHeight =
                      (120.0 + entryCount * 5.0).clamp(120.0, 220.0);
                  return _UserBookSpine(
                    book: book,
                    width: spineWidth,
                    height: spineHeight,
                    gradient: _spineGradient(book.coverColor),
                    entryCount: entryCount,
                    onTap: () => widget.onBookTap(book),
                    onLongPress: () => _showUserBookActions(book),
                  );
                }),
                _AddBookSpine(
                  width: spineWidth,
                  color: colorScheme.onSurfaceVariant,
                  onTap: widget.onAddBook,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Default book cover ───────────────────────────────────────────────────

class _DefaultBookCover extends StatelessWidget {
  final JournalBook book;
  final double height;
  final List<Color> gradient;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DefaultBookCover({
    required this.book,
    required this.height,
    required this.gradient,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Left spine accent
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 6,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
            ),
            // Book title
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.name,
                    style: AppTypography.caption(context).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── User book spine ──────────────────────────────────────────────────────

class _UserBookSpine extends StatefulWidget {
  final JournalBook book;
  final double width;
  final double height;
  final List<Color> gradient;
  final int entryCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _UserBookSpine({
    required this.book,
    required this.width,
    required this.height,
    required this.gradient,
    required this.entryCount,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_UserBookSpine> createState() => _UserBookSpineState();
}

class _UserBookSpineState extends State<_UserBookSpine> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _pressed ? -5 : 0, 0),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: widget.gradient,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: widget.gradient[1].withValues(alpha: _pressed ? 0.5 : 0.3),
              blurRadius: _pressed ? 10 : 5,
              offset: Offset(2, _pressed ? 6 : 3),
            ),
          ],
        ),
        child: RotatedBox(
          quarterTurns: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.book.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                    shadows: [
                      Shadow(color: Colors.black38, blurRadius: 3),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.entryCount > 0)
                  Text(
                    '${widget.entryCount} entries',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Add book spine ───────────────────────────────────────────────────────

class _AddBookSpine extends StatelessWidget {
  final double width;
  final Color color;
  final VoidCallback onTap;

  const _AddBookSpine({
    required this.width,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: width,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          color: color.withValues(alpha: 0.06),
        ),
        child: Center(
          child: Icon(Icons.add, size: 18, color: color.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

// ─── Full-screen overlay panel (uses OverlayEntry) ────────────────────────

class _JournalOverlayPanel extends StatefulWidget {
  final AnimationController animation;
  final _OverlayMode mode;
  final JournalBook book;
  final int entryCount;
  final VoidCallback onDismiss;
  final ValueChanged<int> onColorApplied;
  final VoidCallback onDeleteConfirmed;
  final VoidCallback? onSwitchToColorPicker;
  final VoidCallback? onSwitchToDelete;

  const _JournalOverlayPanel({
    required this.animation,
    required this.mode,
    required this.book,
    required this.entryCount,
    required this.onDismiss,
    required this.onColorApplied,
    required this.onDeleteConfirmed,
    this.onSwitchToColorPicker,
    this.onSwitchToDelete,
  });

  @override
  State<_JournalOverlayPanel> createState() => _JournalOverlayPanelState();
}

class _JournalOverlayPanelState extends State<_JournalOverlayPanel> {
  late int _pickerSelectedColor;
  late CurvedAnimation _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _pickerSelectedColor =
        widget.book.coverColor ?? JournalBook.defaultCoverColor;
    _curvedAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const barHeight = 64.0;
    const circleOverflow = 20.0;
    final navTotalHeight = barHeight + circleOverflow + bottomPad;
    final colorScheme = Theme.of(context).colorScheme;

    final panelHeight = widget.mode == _OverlayMode.colorPicker
        ? 260.0
        : widget.mode == _OverlayMode.userBookActions
            ? 190.0
            : 290.0;

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final t = _curvedAnimation.value;

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Scrim
              Positioned.fill(
                child: GestureDetector(
                  onTap: widget.onDismiss,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35 * t),
                  ),
                ),
              ),
              // Panel sliding up from behind the nav bar
              Positioned(
                left: 0,
                right: 0,
                bottom: navTotalHeight - circleOverflow,
                child: Transform.translate(
                  offset: Offset(0, panelHeight * (1 - t)),
                  child: Opacity(
                    opacity: t,
                    child: ClipPath(
                      clipper: _NotchedBottomClipper(
                        cutoutRadius: 34.0,
                        cutoutCenterOffset: 10.0,
                      ),
                      child: Material(
                        color: colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: SizedBox(
                          height: panelHeight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                            child: widget.mode == _OverlayMode.colorPicker
                                ? _buildColorPickerContent(colorScheme)
                                : widget.mode == _OverlayMode.userBookActions
                                    ? _buildUserActionsContent(colorScheme)
                                    : _buildDeleteConfirmContent(colorScheme),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserActionsContent(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.book.name, style: AppTypography.heading3(context)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onSwitchToColorPicker,
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Change Color'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.onSwitchToDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorPickerContent(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Choose Cover Color', style: AppTypography.heading3(context)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: List.generate(JournalBook.presetColors.length, (index) {
            final colorValue = JournalBook.presetColors[index];
            final gradientPair = index < _coverGradients.length
                ? _coverGradients[index]
                : [Color(colorValue), Color(colorValue)];
            final isSelected = colorValue == _pickerSelectedColor;

            return GestureDetector(
              onTap: () => setState(() => _pickerSelectedColor = colorValue),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientPair,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.onSurface
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientPair.first.withValues(alpha: 0.4),
                      blurRadius: isSelected ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(Icons.check, color: colorScheme.onPrimary, size: 20)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: () => widget.onColorApplied(_pickerSelectedColor),
            style: FilledButton.styleFrom(
              backgroundColor: Color(_pickerSelectedColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Apply',
              style: AppTypography.button(
                context,
              ).copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteConfirmContent(ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 36, color: colorScheme.error),
          const SizedBox(height: 12),
          Text('Delete Book?', style: AppTypography.heading3(context)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'This will permanently delete "${widget.book.name}" and all '
              '${widget.entryCount} '
              '${widget.entryCount == 1 ? 'entry' : 'entries'} in it. '
              'This cannot be undone.',
              style: AppTypography.bodySmall(
                context,
              ).copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onDismiss,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodySmall(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: widget.onDeleteConfirmed,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Delete',
                    style: AppTypography.button(
                      context,
                    ).copyWith(color: colorScheme.onError),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Notched bottom clipper ───────────────────────────────────────────────

class _NotchedBottomClipper extends CustomClipper<Path> {
  final double cutoutRadius;
  final double cutoutCenterOffset;

  _NotchedBottomClipper({
    required this.cutoutRadius,
    required this.cutoutCenterOffset,
  });

  @override
  Path getClip(Size size) {
    final rect = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, size.width, size.height),
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
        ),
      );

    final cutout = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height + cutoutCenterOffset),
          radius: cutoutRadius,
        ),
      );

    return Path.combine(PathOperation.difference, rect, cutout);
  }

  @override
  bool shouldReclip(_NotchedBottomClipper oldClipper) =>
      cutoutRadius != oldClipper.cutoutRadius ||
      cutoutCenterOffset != oldClipper.cutoutCenterOffset;
}


