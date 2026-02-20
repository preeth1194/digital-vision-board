import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';
import '../../../models/journal_book.dart';
import '../../../models/journal_entry.dart';
import '../../../services/journal_book_storage_service.dart';
import 'book_action_bar.dart';
import 'interactive_journal_book.dart';

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

enum _OverlayMode { colorPicker, deleteConfirm }

/// A horizontal carousel of interactive journal books.
class JournalBookCarousel extends StatefulWidget {
  final List<JournalBook> books;
  final String? selectedBookId;
  final Map<String, int> entryCounts;
  final Map<String, List<JournalEntry>> entriesByBook;
  final ValueChanged<JournalBook> onBookSelected;
  final VoidCallback onAddBook;
  final void Function(JournalEntry) onOpenEntry;
  final void Function(JournalEntry) onDeleteEntry;
  final VoidCallback onNewEntry;
  final void Function(String bookId) onDeleteBook;
  final void Function(String bookId, int color) onColorChanged;
  final void Function(String bookId, String newTitle) onTitleChanged;
  final String? newBookId;
  final ValueChanged<bool>? onBookOpenChanged;

  const JournalBookCarousel({
    super.key,
    required this.books,
    required this.selectedBookId,
    required this.entryCounts,
    required this.entriesByBook,
    required this.onBookSelected,
    required this.onAddBook,
    required this.onOpenEntry,
    required this.onDeleteEntry,
    required this.onNewEntry,
    required this.onDeleteBook,
    required this.onColorChanged,
    required this.onTitleChanged,
    this.newBookId,
    this.onBookOpenChanged,
  });

  @override
  State<JournalBookCarousel> createState() => _JournalBookCarouselState();
}

class _JournalBookCarouselState extends State<JournalBookCarousel>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isBookOpen = false;
  final Map<String, GlobalKey> _bookKeys = {};

  static const double _closedViewportFraction = 0.65;
  static const double _openViewportFraction = 0.95;

  late AnimationController _overlayController;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _currentPage = _getInitialPage();
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: _closedViewportFraction,
    );
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  int _getInitialPage() {
    if (widget.selectedBookId == null) return 0;
    final idx = widget.books.indexWhere((b) => b.id == widget.selectedBookId);
    return idx >= 0 ? idx : 0;
  }

  @override
  void didUpdateWidget(JournalBookCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.books.length > oldWidget.books.length && widget.newBookId != null) {
      final newIdx = widget.books.indexWhere((b) => b.id == widget.newBookId);
      if (newIdx >= 0 && _pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.animateToPage(
            newIdx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _overlayController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onBookOpenChanged(bool isOpen) {
    if (_isBookOpen == isOpen) return;
    setState(() {
      _isBookOpen = isOpen;
    });
    final page = _currentPage;
    _pageController.dispose();
    _pageController = PageController(
      initialPage: page,
      viewportFraction: isOpen ? _openViewportFraction : _closedViewportFraction,
    );
    if (isOpen) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _isBookOpen) {
          widget.onBookOpenChanged?.call(true);
        }
      });
    } else {
      widget.onBookOpenChanged?.call(false);
    }
  }

  // ─── Overlay helpers ─────────────────────────────────────────────────────

  void _showOverlay(_OverlayMode mode, JournalBook book) {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (_) => _JournalOverlayPanel(
        animation: _overlayController,
        mode: mode,
        book: book,
        entryCount: widget.entryCounts[book.id] ?? 0,
        onDismiss: _hideOverlay,
        onColorApplied: (color) {
          widget.onColorChanged(book.id, color);
          _hideOverlay();
        },
        onDeleteConfirmed: () {
          _hideOverlay();
          widget.onDeleteBook(book.id);
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

  void _confirmDeleteBook(JournalBook book) {
    if (book.id == JournalBookStorageService.goalLogsBookId) return;
    _showOverlay(_OverlayMode.deleteConfirm, book);
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final closedHeight = math.min(320.0, size.height * 0.4);
    final bottomNav = MediaQuery.of(context).padding.bottom + 80;
    final topBar = MediaQuery.of(context).padding.top + 56;
    final openHeight = size.height - topBar - bottomNav - 24;
    final itemHeight = _isBookOpen ? openHeight : closedHeight;
    final totalItems = widget.books.length + 1;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          height: itemHeight,
          child: PageView.builder(
            key: ValueKey(_isBookOpen),
            controller: _pageController,
            itemCount: totalItems,
            physics: _isBookOpen
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              if (page < widget.books.length) {
                widget.onBookSelected(widget.books[page]);
              }
            },
            itemBuilder: (context, index) {
              if (index == widget.books.length) {
                return _AddBookCard(
                  onTap: widget.onAddBook,
                  isActive: _currentPage == index,
                );
              }

              final book = widget.books[index];
              final isActive = _currentPage == index;
              final entryCount = widget.entryCounts[book.id] ?? 0;
              final entries = widget.entriesByBook[book.id] ?? [];
              final isNewBook = book.id == widget.newBookId;

              final bookKey = _bookKeys.putIfAbsent(book.id, () => GlobalKey());

              return AnimatedScale(
                scale: isActive ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: isActive ? 1.0 : (_isBookOpen ? 0.0 : 0.7),
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: InteractiveJournalBook(
                      key: bookKey,
                      book: book,
                      entryCount: entryCount,
                      entries: entries,
                      onNewEntry: widget.onNewEntry,
                      onOpenEntry: widget.onOpenEntry,
                      onDeleteEntry: widget.onDeleteEntry,
                      onDeleteAllEntries: () => _confirmDeleteBook(book),
                      onCustomizeColor: () => _showColorPicker(book),
                      onTitleChanged: (title) =>
                          widget.onTitleChanged(book.id, title),
                      onOpenChanged: _onBookOpenChanged,
                      isActive: isActive,
                      isNewBook: isNewBook,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_currentPage < widget.books.length)
          BookActionBar(
            onColor: () => _showColorPicker(widget.books[_currentPage]),
            onDelete: () => _confirmDeleteBook(widget.books[_currentPage]),
            onAdd: widget.onNewEntry,
            isVisible: !_isBookOpen,
          ),
      ],
    );
  }
}

// ─── Full-screen overlay panel (uses OverlayEntry) ───────────────────────

class _JournalOverlayPanel extends StatefulWidget {
  final AnimationController animation;
  final _OverlayMode mode;
  final JournalBook book;
  final int entryCount;
  final VoidCallback onDismiss;
  final ValueChanged<int> onColorApplied;
  final VoidCallback onDeleteConfirmed;

  const _JournalOverlayPanel({
    required this.animation,
    required this.mode,
    required this.book,
    required this.entryCount,
    required this.onDismiss,
    required this.onColorApplied,
    required this.onDeleteConfirmed,
  });

  @override
  State<_JournalOverlayPanel> createState() => _JournalOverlayPanelState();
}

class _JournalOverlayPanelState extends State<_JournalOverlayPanel> {
  late int _pickerSelectedColor;

  @override
  void initState() {
    super.initState();
    _pickerSelectedColor =
        widget.book.coverColor ?? JournalBook.defaultCoverColor;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const barHeight = 64.0;
    const circleOverflow = 20.0;
    final navTotalHeight = barHeight + circleOverflow + bottomPad;
    final colorScheme = Theme.of(context).colorScheme;

    final panelHeight =
        widget.mode == _OverlayMode.colorPicker ? 240.0 : 200.0;

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: widget.animation,
          curve: Curves.easeOutCubic,
        ).value;

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Scrim
              Positioned.fill(
                child: GestureDetector(
                  onTap: widget.onDismiss,
                  child: ColoredBox(
                    color: Colors.black.withOpacity(0.35 * t),
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
                            padding:
                                const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: widget.mode == _OverlayMode.colorPicker
                                ? _buildColorPickerContent(colorScheme)
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

  Widget _buildColorPickerContent(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Choose Cover Color',
          style: AppTypography.heading3(context),
        ),
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
                    ? Icon(Icons.check,
                        color: colorScheme.onPrimary, size: 20)
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
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Apply',
                style: AppTypography.button(context)
                    .copyWith(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteConfirmContent(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded,
            size: 36, color: colorScheme.error),
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
            style: AppTypography.bodySmall(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
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
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel',
                    style: AppTypography.bodySmall(context)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: widget.onDeleteConfirmed,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Delete',
                    style: AppTypography.button(context)
                        .copyWith(color: colorScheme.onError)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Add book card ────────────────────────────────────────────────────────

class _AddBookCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _AddBookCard({
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final bgColor = isDark
        ? colorScheme.surfaceContainerHigh.withOpacity(0.5)
        : colorScheme.surfaceContainerLow.withOpacity(0.7);
    final borderColor = isDark
        ? colorScheme.outlineVariant.withOpacity(0.3)
        : colorScheme.outlineVariant.withOpacity(0.4);

    return AnimatedScale(
      scale: isActive ? 1.0 : 0.85,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: math.min(200.0, size.width * 0.5),
              height: math.min(260.0, size.height * 0.32),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        colorScheme.shadow.withOpacity(isDark ? 0.3 : 0.08),
                    offset: const Offset(4, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'New Book',
                    style: AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.6),
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

// ─── Notched bottom clipper (same as dashboard) ──────────────────────────

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
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, size.width, size.height),
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
      ));

    final cutout = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height + cutoutCenterOffset),
        radius: cutoutRadius,
      ));

    return Path.combine(PathOperation.difference, rect, cutout);
  }

  @override
  bool shouldReclip(_NotchedBottomClipper oldClipper) =>
      cutoutRadius != oldClipper.cutoutRadius ||
      cutoutCenterOffset != oldClipper.cutoutCenterOffset;
}
