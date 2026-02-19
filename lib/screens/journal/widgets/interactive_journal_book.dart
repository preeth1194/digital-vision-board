import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/journal_book.dart';
import '../../../models/journal_entry.dart';
import '../../../services/journal_book_storage_service.dart';

/// An interactive 3D journal book that opens on tap to reveal entries.
class InteractiveJournalBook extends StatefulWidget {
  final JournalBook book;
  final int entryCount;
  final List<JournalEntry> entries;
  final VoidCallback onNewEntry;
  final void Function(JournalEntry) onOpenEntry;
  final void Function(JournalEntry) onDeleteEntry;
  final VoidCallback onDeleteAllEntries;
  final VoidCallback onCustomizeColor;
  final void Function(String newTitle) onTitleChanged;
  final ValueChanged<bool>? onOpenChanged;
  final bool isActive;
  final bool isNewBook;

  const InteractiveJournalBook({
    super.key,
    required this.book,
    required this.entryCount,
    required this.entries,
    required this.onNewEntry,
    required this.onOpenEntry,
    required this.onDeleteEntry,
    required this.onDeleteAllEntries,
    required this.onCustomizeColor,
    required this.onTitleChanged,
    this.onOpenChanged,
    this.isActive = true,
    this.isNewBook = false,
  });

  @override
  State<InteractiveJournalBook> createState() => _InteractiveJournalBookState();
}

class _InteractiveJournalBookState extends State<InteractiveJournalBook>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _openAnimation;
  bool _isOpen = false;
  bool _isEditingTitle = false;
  late TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _openAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _titleController = TextEditingController(text: widget.book.name);

    // Auto-focus title if this is a new book
    if (widget.isNewBook) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _isEditingTitle = true);
        _titleFocusNode.requestFocus();
        _titleController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _titleController.text.length,
        );
      });
    }

    _titleFocusNode.addListener(_onTitleFocusChanged);
  }

  @override
  void didUpdateWidget(InteractiveJournalBook oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.book.name != oldWidget.book.name && !_isEditingTitle) {
      _titleController.text = widget.book.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _onTitleFocusChanged() {
    if (!_titleFocusNode.hasFocus && _isEditingTitle) {
      _saveTitle();
    }
  }

  void _saveTitle() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.book.name) {
      widget.onTitleChanged(newTitle);
    } else if (newTitle.isEmpty) {
      _titleController.text = widget.book.name;
    }
    setState(() => _isEditingTitle = false);
  }

  void _toggleBook() {
    if (_isEditingTitle) return;
    
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onOpenChanged?.call(_isOpen);
  }

  void _startEditingTitle() {
    setState(() => _isEditingTitle = true);
    _titleFocusNode.requestFocus();
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _titleController.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bookWidth = math.min(200.0, size.width * 0.5);
    final bookHeight = math.min(260.0, size.height * 0.32);
    final openWidth = math.min(size.width * 0.88, bookWidth * 2.6);
    final bottomNav = MediaQuery.of(context).padding.bottom + 80;
    final topBar = MediaQuery.of(context).padding.top + 56;
    final openHeight = size.height - topBar - bottomNav - 48;
    final coverColor = Color(widget.book.coverColor ?? JournalBook.defaultCoverColor);

    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _openAnimation,
      builder: (context, child) {
        // Interpolate width between closed and open
        final currentWidth = bookWidth + (_openAnimation.value * (openWidth - bookWidth));

        final currentHeight = bookHeight + (_openAnimation.value * (openHeight - bookHeight));

        final extraPadding = 60.0 * (1.0 - _openAnimation.value) + 10.0 * _openAnimation.value;

        return SizedBox(
          width: currentWidth + 40,
          height: currentHeight + extraPadding,
          child: Stack(
            alignment: _isOpen ? Alignment.topCenter : Alignment.center,
            children: [
              // Book shadow (hidden when open)
              if (_openAnimation.value < 0.95)
                Positioned(
                  bottom: 20,
                  child: Opacity(
                    opacity: 1.0 - _openAnimation.value,
                    child: Container(
                      width: currentWidth * 0.85,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(currentWidth / 2),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.25),
                            blurRadius: 25,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Expanded entries list - fades/scales in
              if (_openAnimation.value > 0.05)
                Opacity(
                  opacity: _openAnimation.value,
                  child: Transform.scale(
                    scale: 0.9 + _openAnimation.value * 0.1,
                    child: _ExpandedEntriesList(
                      width: openWidth,
                      height: openHeight,
                      coverColor: coverColor,
                      entries: widget.entries,
                      onOpenEntry: widget.onOpenEntry,
                      onDeleteEntry: widget.onDeleteEntry,
                      onNewEntry: widget.onNewEntry,
                      onDeleteBook: widget.onDeleteAllEntries,
                      onCustomize: widget.onCustomizeColor,
                      bookName: widget.book.name,
                      bookId: widget.book.id,
                      isFullyOpen: _openAnimation.value > 0.95,
                      onClose: _toggleBook,
                    ),
                  ),
                ),

              // Closed book cover - fades/scales out, tappable to open
              if (_openAnimation.value < 0.95)
                GestureDetector(
                  onTap: _toggleBook,
                  onLongPress: _startEditingTitle,
                  child: Opacity(
                    opacity: 1.0 - _openAnimation.value,
                    child: Transform.scale(
                      scale: 1.0 - _openAnimation.value * 0.15,
                      child: _BookCover(
                        width: bookWidth,
                        height: bookHeight,
                        color: coverColor,
                        coverImagePath: widget.book.coverImagePath,
                        title: widget.book.name,
                        entryCount: widget.entryCount,
                        isEditingTitle: _isEditingTitle,
                        titleController: _titleController,
                        titleFocusNode: _titleFocusNode,
                        onTitleTap: _startEditingTitle,
                        onTitleSubmitted: (_) => _saveTitle(),
                        isOpen: _isOpen,
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
}

/// The book cover with spine effect.
class _BookCover extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final String? coverImagePath;
  final String title;
  final int entryCount;
  final bool isEditingTitle;
  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final VoidCallback onTitleTap;
  final ValueChanged<String> onTitleSubmitted;
  final bool isOpen;

  const _BookCover({
    required this.width,
    required this.height,
    required this.color,
    this.coverImagePath,
    required this.title,
    required this.entryCount,
    required this.isEditingTitle,
    required this.titleController,
    required this.titleFocusNode,
    required this.onTitleTap,
    required this.onTitleSubmitted,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final darkerColor = HSLColor.fromColor(color).withLightness(
      (HSLColor.fromColor(color).lightness - 0.15).clamp(0.0, 1.0),
    ).toColor();
    final spineWidth = width * 0.08;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Spine
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: spineWidth,
              decoration: BoxDecoration(
                color: darkerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.3),
                    offset: const Offset(2, 0),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // Main cover
          Positioned(
            left: spineWidth - 2,
            top: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: coverImagePath == null ? color : null,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: Border.all(
                  color: darkerColor.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: isOpen
                    ? []
                    : [
                        BoxShadow(
                          color: colorScheme.shadow.withOpacity(0.2),
                          offset: const Offset(4, 4),
                          blurRadius: 8,
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Stack(
                  children: [
                    // Background image if available
                    if (coverImagePath != null)
                      Positioned.fill(
                        child: Image.file(
                          File(coverImagePath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    // Gradient overlay for text readability on images
                    if (coverImagePath != null)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colorScheme.shadow.withOpacity(0.1),
                                colorScheme.shadow.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Title
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: isEditingTitle
                                ? TextField(
                                    controller: titleController,
                                    focusNode: titleFocusNode,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.merriweather(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    onSubmitted: onTitleSubmitted,
                                  )
                                : GestureDetector(
                                    onTap: onTitleTap,
                                    child: Text(
                                      title,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.merriweather(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: colorScheme.shadow.withOpacity(0.5),
                                            offset: const Offset(1, 1),
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Written by you',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.6),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Page count
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$entryCount ${entryCount == 1 ? 'Page' : 'Pages'}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                  shadows: coverImagePath != null
                                      ? [
                                          Shadow(
                                            color: colorScheme.shadow.withOpacity(0.5),
                                            offset: const Offset(1, 1),
                                            blurRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Page edges on right side
          if (!isOpen)
            Positioned(
              right: 0,
              top: 8,
              bottom: 8,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.outlineVariant,
                      colorScheme.surfaceContainerLow,
                      colorScheme.outlineVariant,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded entries list (replaces old open-book spread)
// ---------------------------------------------------------------------------

/// Inline expanded entries list shown when a book is tapped open.
/// Features staggered entrance animations for each entry row.
class _ExpandedEntriesList extends StatefulWidget {
  final double width;
  final double height;
  final Color coverColor;
  final List<JournalEntry> entries;
  final void Function(JournalEntry) onOpenEntry;
  final void Function(JournalEntry) onDeleteEntry;
  final VoidCallback onNewEntry;
  final VoidCallback onDeleteBook;
  final VoidCallback onCustomize;
  final String bookName;
  final String bookId;
  final bool isFullyOpen;
  final VoidCallback onClose;

  const _ExpandedEntriesList({
    required this.width,
    required this.height,
    required this.coverColor,
    required this.entries,
    required this.onOpenEntry,
    required this.onDeleteEntry,
    required this.onNewEntry,
    required this.onDeleteBook,
    required this.onCustomize,
    required this.bookName,
    required this.bookId,
    required this.isFullyOpen,
    required this.onClose,
  });

  @override
  State<_ExpandedEntriesList> createState() => _ExpandedEntriesListState();
}

class _ExpandedEntriesListState extends State<_ExpandedEntriesList>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: Duration(milliseconds: 300 + widget.entries.length * 60),
      vsync: this,
    );
    // Start the stagger animation after a brief delay for the panel to appear
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final darkerCover = HSLColor.fromColor(widget.coverColor)
        .withLightness(
            (HSLColor.fromColor(widget.coverColor).lightness - 0.15)
                .clamp(0.0, 1.0))
        .toColor();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.coverColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Header with book name and entry count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: widget.coverColor.withOpacity(isDark ? 0.25 : 0.12),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: darkerCover,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bookName,
                          style: GoogleFonts.merriweather(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.entries.length} ${widget.entries.length == 1 ? 'entry' : 'entries'}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderActionBtn(
                        icon: Icons.more_horiz_rounded,
                        tooltip: 'More options',
                        onTap: widget.onCustomize,
                        isDark: isDark,
                      ),
                      if (widget.bookId != JournalBookStorageService.goalLogsBookId) ...[
                        const SizedBox(width: 4),
                        _HeaderActionBtn(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Delete book',
                          onTap: widget.onDeleteBook,
                          isDark: isDark,
                        ),
                      ],
                      const SizedBox(width: 4),
                      _HeaderActionBtn(
                        icon: Icons.add_rounded,
                        tooltip: 'New entry',
                        onTap: widget.onNewEntry,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 4),
                      _HeaderActionBtn(
                        icon: Icons.keyboard_arrow_up_rounded,
                        tooltip: 'Close',
                        onTap: widget.onClose,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Entries list or empty state
            Expanded(
              child: widget.entries.isEmpty
                  ? _buildEmptyState(isDark, colorScheme)
                  : _buildEntriesList(isDark, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 32,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 10),
          Text(
            'No entries yet',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + below to add your first entry',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(bool isDark, ColorScheme colorScheme) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          itemCount: widget.entries.length,
          itemBuilder: (context, index) {
            // Calculate stagger for this item
            final itemCount = widget.entries.length;
            final start = (index / (itemCount + 2)).clamp(0.0, 1.0);
            final end = ((index + 2) / (itemCount + 2)).clamp(0.0, 1.0);
            final itemAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _staggerController,
                curve: Interval(start, end, curve: Curves.easeOutCubic),
              ),
            );

            final entry = widget.entries[index];
            return Transform.translate(
              offset: Offset(0, 16 * (1 - itemAnimation.value)),
              child: Opacity(
                opacity: itemAnimation.value,
                child: _EntryRow(
                  entry: entry,
                  formattedDate: _formatDate(entry.createdAt),
                  isDark: isDark,
                  colorScheme: colorScheme,
                  coverColor: widget.coverColor,
                  onEdit: () => widget.onOpenEntry(entry),
                  onDelete: () => widget.onDeleteEntry(entry),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// A single entry row with edit and delete action buttons.
class _EntryRow extends StatefulWidget {
  final JournalEntry entry;
  final String formattedDate;
  final bool isDark;
  final ColorScheme colorScheme;
  final Color coverColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryRow({
    required this.entry,
    required this.formattedDate,
    required this.isDark,
    required this.colorScheme,
    required this.coverColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _editPressed = false;
  bool _deletePressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? widget.colorScheme.surfaceContainerHighest
        : widget.colorScheme.surface;
    final borderColor = widget.isDark
        ? widget.colorScheme.outlineVariant.withOpacity(0.3)
        : widget.colorScheme.outlineVariant;

    return GestureDetector(
      onTap: widget.onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: widget.colorScheme.shadow.withOpacity(widget.isDark ? 0.15 : 0.04),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          children: [
            // Color accent bar
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: widget.coverColor.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            // Entry info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.title ?? 'Untitled',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.formattedDate,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: widget.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Edit button
            GestureDetector(
              onTapDown: (_) => setState(() => _editPressed = true),
              onTapUp: (_) {
                setState(() => _editPressed = false);
                widget.onEdit();
              },
              onTapCancel: () => setState(() => _editPressed = false),
              child: AnimatedScale(
                scale: _editPressed ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: widget.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            // Delete button
            GestureDetector(
              onTapDown: (_) => setState(() => _deletePressed = true),
              onTapUp: (_) {
                setState(() => _deletePressed = false);
                widget.onDelete();
              },
              onTapCancel: () => setState(() => _deletePressed = false),
              child: AnimatedScale(
                scale: _deletePressed ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: _deletePressed
                        ? widget.colorScheme.error
                        : widget.colorScheme.outline,
                  ),
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
// Small icon button for the expanded entries list header
// ---------------------------------------------------------------------------

class _HeaderActionBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  const _HeaderActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_HeaderActionBtn> createState() => _HeaderActionBtnState();
}

class _HeaderActionBtnState extends State<_HeaderActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedScale(
          scale: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _pressed
                  ? colorScheme.onSurface.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
