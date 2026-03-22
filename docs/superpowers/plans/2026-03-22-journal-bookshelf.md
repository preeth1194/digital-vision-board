# Journal Bookshelf Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the journal book carousel (expand-in-place) with a bookshelf UI — a default row of portrait covers (Journal + Goal Logs wide/featured, Recipe Book normal) above wood shelf lines, then a row of variable-height spines for user books, tapping any book pushes to a dedicated detail screen.

**Architecture:** `JournalBookshelf` (new) replaces `JournalBookCarousel`. Tapping a book pushes `JournalBookDetailScreen` (new, self-contained). `JournalHeroSection` is simplified (no open-in-place state). `JournalNotesScreen` removes per-book entry display, just reloads counts on return.

**Tech Stack:** Flutter/Dart, SharedPreferences, existing services (`JournalStorageService`, `JournalBookStorageService`), Material 3 / Morning Garden design tokens.

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `lib/screens/journal/widgets/journal_bookshelf.dart` | Bookshelf widget: default row + spine row + add spine + overlay |
| Create | `lib/screens/journal/journal_book_detail_screen.dart` | Full-page screen for a single book's entries |
| Modify | `lib/screens/journal/widgets/journal_hero_section.dart` | Replace carousel with bookshelf, remove open-in-place state |
| Modify | `lib/screens/journal/journal_notes_screen.dart` | Remove per-book entry display state, update tap handler |

---

## Task 1: Create `JournalBookshelf` widget

**Files:**
- Create: `lib/screens/journal/widgets/journal_bookshelf.dart`

The bookshelf renders two sections:
1. **Default row** — horizontal `Row` of 3 portrait covers. Journal (`defaultBookId`) and Goal Logs (`goalLogsBookId`) use `flex: 5` each (wider/featured). Recipe Book (`recipeBookId`) uses `flex: 3` (normal). All tap → `onBookTap(book)`. Long press → show color overlay (only color picker; delete disabled for system books).
2. **Wood shelf line** — `Container` with `LinearGradient(#C4956A → #A0724A → #7A5520)`, height 6, box shadow.
3. **User spines row** — horizontal `SingleChildScrollView` with `Row`. Each spine: `width: 40`, `height: clamp(entryCount × 5.0, 52.0, 130.0)`, gradient from `book.coverColor`, vertical text (book name + entry count). Aligned to bottom. Plus a dashed "+ Book" spine at the end.
4. **Second shelf line**.

Long-press behavior: show the same `_JournalOverlayPanel` from the current carousel (copy/adapt it). System books (Journal, Goal Logs, Recipe) show only color picker (no delete option). User books show color picker + delete.

- [ ] **Step 1: Create the file with widget skeleton**

```dart
// lib/screens/journal/widgets/journal_bookshelf.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';
import '../../../models/journal_book.dart';
import '../../../services/journal_book_storage_service.dart';

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
    required this.recipeCount,
    required this.onBookTap,
    required this.onAddBook,
    required this.onColorChanged,
    required this.onDeleteBook,
  });

  @override
  State<JournalBookshelf> createState() => _JournalBookshelfState();
}
```

- [ ] **Step 2: Add overlay fields and helpers to state**

Copy the `_OverlayMode` enum, `_overlayController`, `_overlayEntry`, `_showOverlay`, `_hideOverlay`, `_removeOverlay` pattern from `journal_book_carousel.dart:88-203`. Adapt: `_showColorPicker` and `_confirmDeleteBook`.

Add to `_JournalBookshelfState`:
```dart
late AnimationController _overlayController;
OverlayEntry? _overlayEntry;

// Reuse _JournalOverlayPanel inline or import (prefer inline copy here)
```

In `initState`, `dispose`: init/dispose `_overlayController`.

- [ ] **Step 3: Build default row**

Three constants at top of file:
```dart
static const List<String> _defaultBookIds = [
  JournalBookStorageService.defaultBookId,
  JournalBookStorageService.goalLogsBookId,
  JournalBookStorageService.recipeBookId,
];
static const Set<String> _featuredIds = {
  JournalBookStorageService.defaultBookId,
  JournalBookStorageService.goalLogsBookId,
};
```

In `build`:
```dart
Widget _buildDefaultRow(BuildContext context) {
  final defaultBooks = widget.books
      .where((b) => _defaultBookIds.contains(b.id))
      .toList()
    ..sort((a, b) =>
        _defaultBookIds.indexOf(a.id).compareTo(_defaultBookIds.indexOf(b.id)));

  return Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: defaultBooks.map((book) {
      final flex = _featuredIds.contains(book.id) ? 5 : 3;
      return Expanded(
        flex: flex,
        child: _DefaultBookCover(
          book: book,
          entryCount: book.id == JournalBookStorageService.recipeBookId
              ? widget.recipeCount
              : (widget.entryCounts[book.id] ?? 0),
          onTap: () => widget.onBookTap(book),
          onLongPress: () => _showColorPicker(book),
        ),
      );
    }).toList(),
  );
}
```

- [ ] **Step 4: Build `_DefaultBookCover` private widget**

```dart
class _DefaultBookCover extends StatefulWidget {
  final JournalBook book;
  final int entryCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _DefaultBookCover({...});
}
```

State uses `AnimationController` for press-lift: on press, `translateY(-4)` + shadow boost. Cover is a `Container` with:
- `decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(...coverColor))`
- Left spine strip: `Container(width: 5, color: Colors.black26)`
- Content: book title (bottom-left, white, bold), entry count (small, white 60%)
- `height: 110` for featured books, `88` for normal
- `margin: EdgeInsets.symmetric(horizontal: 3)`

```dart
@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: widget.onTap,
    onLongPress: widget.onLongPress,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientFor(widget.book.coverColor),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 4)),
        ],
      ),
      child: Stack(
        children: [
          // Left spine strip
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
          ),
          // Book content
          Positioned(
            left: 9, right: 6, bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.book.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.entryCount} ${widget.entryCount == 1 ? "entry" : "entries"}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

Helper `_gradientFor`:
```dart
List<Color> _gradientFor(int? colorValue) {
  final base = Color(colorValue ?? JournalBook.defaultCoverColor);
  return [
    Color.lerp(base, Colors.white, 0.25) ?? base,
    base,
  ];
}
```

- [ ] **Step 5: Build user spines row**

```dart
Widget _buildUserSpinesRow(BuildContext context, List<JournalBook> userBooks) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...userBooks.asMap().entries.map((entry) {
          final book = entry.value;
          final count = widget.entryCounts[book.id] ?? 0;
          final spineHeight = (count * 5.0).clamp(52.0, 130.0);
          return _UserBookSpine(
            book: book,
            entryCount: count,
            height: spineHeight,
            onTap: () => widget.onBookTap(book),
            onLongPress: () => _confirmDeleteBook(book),
          );
        }),
        _AddBookSpine(onTap: widget.onAddBook),
      ],
    ),
  );
}
```

- [ ] **Step 6: Build `_UserBookSpine` and `_AddBookSpine` private widgets**

`_UserBookSpine`:
```dart
class _UserBookSpine extends StatefulWidget {
  final JournalBook book;
  final int entryCount;
  final double height;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _UserBookSpine({...});
}
```

State uses a `bool _pressed` to animate `translateY(-5)` + stronger shadow on press.

```dart
@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: widget.onTap,
    onLongPress: widget.onLongPress,
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) => setState(() => _pressed = false),
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      transform: Matrix4.translationValues(0, _pressed ? -5 : 0, 0),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 40,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _spineGradient(widget.book.coverColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_pressed ? 0.35 : 0.2),
            blurRadius: _pressed ? 12 : 6,
            offset: Offset(_pressed ? 3 : 2, _pressed ? 6 : 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Left spine strip
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.28),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(3),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
          ),
          // Vertical text
          Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.book.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.entryCount > 0)
                    Text(
                      '${widget.entryCount}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 6,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

List<Color> _spineGradient(int? colorValue) {
  final base = Color(colorValue ?? JournalBook.defaultCoverColor);
  return [
    Color.lerp(base, Colors.white, 0.2) ?? base,
    base,
    Color.lerp(base, Colors.black, 0.15) ?? base,
  ];
}
```

`_AddBookSpine`:
```dart
class _AddBookSpine extends StatelessWidget {
  final VoidCallback onTap;
  const _AddBookSpine({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 40,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5,
            style: BorderStyle.solid,
          ),
          color: color.withOpacity(0.06),
        ),
        child: Center(
          child: Icon(Icons.add, size: 18, color: color.withOpacity(0.5)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Build shelf line helper and wire up `build`**

```dart
Widget _buildShelfLine() {
  return Container(
    height: 6,
    margin: const EdgeInsets.only(top: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFC4956A), Color(0xFFA0724A), Color(0xFF7A5520)],
        stops: [0.0, 0.55, 1.0],
      ),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
      ],
    ),
  );
}

@override
Widget build(BuildContext context) {
  final userBooks = widget.books
      .where((b) => !_defaultBookIds.contains(b.id))
      .toList();

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDefaultRow(context),
        _buildShelfLine(),
        const SizedBox(height: 12),
        if (userBooks.isNotEmpty || true) // always show user row for add button
          _buildUserSpinesRow(context, userBooks),
        _buildShelfLine(),
      ],
    ),
  );
}
```

- [ ] **Step 8: Add overlay panel (copy from `journal_book_carousel.dart`)**

Copy `_JournalOverlayPanel`, `_NotchedBottomClipper`, and the `_OverlayMode` enum directly into this file.

The original `_showOverlay` signature is `void _showOverlay(_OverlayMode mode, JournalBook book)` — no extra params. Copy it verbatim, then add two convenience wrappers:

```dart
void _showColorPicker(JournalBook book) =>
    _showOverlay(_OverlayMode.colorPicker, book);

void _confirmDeleteBook(JournalBook book) =>
    _showOverlay(_OverlayMode.deleteConfirm, book);
```

System books (`defaultBookId`, `goalLogsBookId`, `recipeBookId`) call `_showColorPicker` on long press (no delete option). User books call `_confirmDeleteBook` on long press, which shows the delete-confirm panel (matching existing carousel behavior). The overlay's `onColorApplied` fires `widget.onColorChanged`; `onDeleteConfirmed` fires `widget.onDeleteBook`.

- [ ] **Step 9: Run `flutter analyze` — fix any errors**

```bash
cd /Users/preeth/digital-vision-board && flutter analyze lib/screens/journal/widgets/journal_bookshelf.dart
```

Expected: no errors.

- [ ] **Step 10: Commit**

```bash
git add lib/screens/journal/widgets/journal_bookshelf.dart
git commit -m "feat: add JournalBookshelf widget with default row + spine row"
```

---

## Task 2: Create `JournalBookDetailScreen`

**Files:**
- Create: `lib/screens/journal/journal_book_detail_screen.dart`

A full-page screen that owns its own entry loading for a given `bookId`. It shows the entry list, handles new/edit/delete, reloads on return from editor.

- [ ] **Step 1: Create file with scaffold**

```dart
// lib/screens/journal/journal_book_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/journal_book.dart';
import '../../models/journal_entry.dart';
import '../../services/journal_book_storage_service.dart';
import '../../services/journal_storage_service.dart';
import '../../utils/app_typography.dart';
import '../../utils/app_colors.dart';
import 'journal_editor_screen.dart';
import 'models/journal_editor_models.dart';

class JournalBookDetailScreen extends StatefulWidget {
  final JournalBook book;
  final List<String> goalTitles;

  const JournalBookDetailScreen({
    super.key,
    required this.book,
    required this.goalTitles,
  });

  @override
  State<JournalBookDetailScreen> createState() =>
      _JournalBookDetailScreenState();
}
```

- [ ] **Step 2: Add state with loading/entries**

```dart
class _JournalBookDetailScreenState extends State<JournalBookDetailScreen> {
  bool _loading = true;
  List<JournalEntry> _entries = const [];
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    await _reload(prefs: prefs);
  }

  Future<void> _reload({required SharedPreferences prefs}) async {
    setState(() => _loading = true);
    try {
      final allEntries = await JournalStorageService.loadEntries(prefs: prefs);
      final bookEntries = allEntries.where((e) {
        if (e.bookId == null || e.bookId!.isEmpty) {
          return widget.book.id == JournalBookStorageService.defaultBookId;
        }
        return e.bookId == widget.book.id;
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _entries = bookEntries;
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
```

- [ ] **Step 3: Add navigation helpers**

```dart
  static List<String> _allTags(List<JournalEntry> entries) {
    final set = <String>{};
    for (final e in entries) {
      for (final t in e.tags) {
        final s = t.trim();
        if (s.isNotEmpty) set.add(s);
      }
    }
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> _openEditor({JournalEntry? existing}) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    final res = await Navigator.of(context).push<JournalEditorResult?>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => JournalEntryEditorScreen(
          goalTitles: widget.goalTitles,
          existingTags: _allTags(_entries),
          existingEntry: existing,
          bookId: existing == null ? widget.book.id : null,
        ),
        transitionsBuilder: _pageTransition,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (!mounted) return;
    if (res != null && existing == null) {
      // New entry: save it
      await JournalStorageService.addEntry(
        title: res.title,
        text: res.plainText,
        delta: res.deltaJson,
        tags: res.tags,
        goalTitle: res.legacyGoalTitle,
        bookId: widget.book.id,
        prefs: prefs,
      );
    }
    await _reload(prefs: prefs);
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          'Delete "${entry.title ?? 'Untitled'}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await JournalStorageService.deleteEntry(entry.id, prefs: prefs);
    await _reload(prefs: prefs);
  }

  static Widget _pageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return SlideTransition(position: slide, child: child);
  }
```

- [ ] **Step 4: Build AppBar and body**

```dart
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bookColor = Color(widget.book.coverColor ?? JournalBook.defaultCoverColor);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: bookColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.book.name,
                style: AppTypography.heading3(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _openEditor(),
            child: Text(
              '+ Entry',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 80,
              ),
              itemCount: _entries.length,
              itemBuilder: (context, index) =>
                  _buildEntryRow(context, _entries[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'No entries yet',
            style: AppTypography.heading3(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + Entry or the button below to start writing.',
            style: AppTypography.bodySmall(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(BuildContext context, JournalEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final bookColor = Color(widget.book.coverColor ?? JournalBook.defaultCoverColor);
    final dateStr = _formatDate(entry.createdAt);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        await _deleteEntry(entry);
        return false; // we handle deletion ourselves
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openEditor(existing: entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bookColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title ?? 'Untitled',
                        style: AppTypography.body(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: AppTypography.caption(context).copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.outlineVariant,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
```

- [ ] **Step 5: Run `flutter analyze` — fix any errors**

```bash
cd /Users/preeth/digital-vision-board && flutter analyze lib/screens/journal/journal_book_detail_screen.dart
```

- [ ] **Step 6: Commit**

```bash
git add lib/screens/journal/journal_book_detail_screen.dart
git commit -m "feat: add JournalBookDetailScreen with entry list and FAB"
```

---

## Task 3: Update `JournalHeroSection`

**Files:**
- Modify: `lib/screens/journal/widgets/journal_hero_section.dart`

Remove `_isBookOpen` state, `onBookOpenChanged` callback, and the animated padding/size collapsing. Replace `JournalBookCarousel` with `JournalBookshelf`.

- [ ] **Step 1: Remove `onBookOpenChanged`, `onBookTap` from widget interface; add new bookshelf callbacks**

Remove fields: `onBookTap`, `onBookSelected`, `onOpenEntry`, `onDeleteEntry`, `onDeleteBook`, `onColorChanged`, `onTitleChanged`, `newBookId`. These are no longer needed since the bookshelf + detail screen own their own interactions.

Keep: `books`, `entryCounts`, `recipeCount`, `onAddBook`. Add new fields:
- `void Function(JournalBook) onBookTap` — fires when user taps a book (navigate to detail)
- `void Function(String, int) onColorChanged`
- `void Function(String) onDeleteBook`

Updated widget class:
```dart
class JournalHeroSection extends StatelessWidget {
  final VoidCallback onType;        // kept for FAB/record area (optional removal)
  final VoidCallback onRecord;
  final List<JournalBook> books;
  final Map<String, int> entryCounts;
  final int recipeCount;
  final void Function(JournalBook) onBookTap;
  final VoidCallback onAddBook;
  final void Function(String bookId, int color) onColorChanged;
  final void Function(String bookId) onDeleteBook;

  const JournalHeroSection({
    super.key,
    required this.onType,
    required this.onRecord,
    this.books = const [],
    this.entryCounts = const {},
    this.recipeCount = 0,
    required this.onBookTap,
    required this.onAddBook,
    required this.onColorChanged,
    required this.onDeleteBook,
  });
```

Since `_isBookOpen` and the entry-open callbacks are gone, make the widget stateless (or keep minimal state for entrance animation).

- [ ] **Step 2: Simplify build — remove all `_isBookOpen` logic**

Remove `TickerProviderStateMixin`, `AnimationController`, the `AnimatedPadding`, and the `AnimatedSize` title collapse. Just use `FadeTransition` with a simple entrance animation (optional: make fully stateless if entrance animation is removed).

Simplest approach — make it `StatelessWidget`:
```dart
@override
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 12),
        if (books.isNotEmpty)
          JournalBookshelf(
            books: books,
            entryCounts: entryCounts,
            recipeCount: recipeCount,
            onBookTap: onBookTap,
            onAddBook: onAddBook,
            onColorChanged: onColorChanged,
            onDeleteBook: onDeleteBook,
          ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
```

- [ ] **Step 3: Run `flutter analyze` — fix any errors**

```bash
cd /Users/preeth/digital-vision-board && flutter analyze lib/screens/journal/widgets/journal_hero_section.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/journal/widgets/journal_hero_section.dart
git commit -m "refactor: simplify JournalHeroSection to use JournalBookshelf"
```

---

## Task 4: Update `JournalNotesScreen`

**Files:**
- Modify: `lib/screens/journal/journal_notes_screen.dart`

Remove entry-per-book state, update `_handleBookTap` to push `JournalBookDetailScreen`, simplify `_journalTab`.

- [ ] **Step 1: Remove unused state fields**

Remove these fields from `_JournalNotesScreenState`:
- `_selectedBookId`
- `_newBookId`
- `List<JournalEntry> _journalEntries` (still needed for `_hasGoalLogs` check)

Wait — `_journalEntries` is still needed to check `_hasGoalLogs` (goal logs tab). Keep it. But remove:
- `_selectedBookId`
- `_newBookId`
- `Map<String, List<JournalEntry>> _entriesByBook` (no longer passed to hero)

- [ ] **Step 2: Replace `_handleBookTap` with push navigation**

```dart
Future<void> _handleBookTap(JournalBook book) async {
  if (book.id == JournalBookStorageService.recipeBookId) {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecipeBookScreen()),
    );
  } else {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => JournalBookDetailScreen(
          book: book,
          goalTitles: _goalTitles,
        ),
        transitionsBuilder: (context, animation, _, child) {
          final slide = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return SlideTransition(position: slide, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }
  // Reload to refresh entry counts shown on bookshelf
  final prefs = _prefs ?? await SharedPreferences.getInstance();
  _prefs ??= prefs;
  if (mounted) await _reload(prefs: prefs);
}
```

- [ ] **Step 3: Remove old handlers no longer needed at this level**

Remove: `_handleBookSelected`, `_openJournalEditorForEdit`, `_openNewJournalEditor`, `_openNewJournalEditorWithVoice`, `_handleOpenEntry`, `_handleDeleteEntry`, `_handleAddBook` (keep), `_openRecipeBook` (inline into `_handleBookTap`).

Keep: `_handleAddBook`, `_handleDeleteBook`, `_handleColorChanged`, `_handleTitleChanged`.

- [ ] **Step 4: Update `_journalTab` to pass simplified props to `JournalHeroSection`**

```dart
Widget _journalTab() {
  return Column(
    children: [
      JournalBrowseSection(onAddBook: _handleAddBook),
      Expanded(
        child: ListView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 100,
          ),
          children: [
            JournalHeroSection(
              onType: () {},    // no longer used at this level
              onRecord: () {},  // no longer used at this level
              books: _books,
              entryCounts: _bookEntryCounts,
              recipeCount: _recipeCount,
              onBookTap: _handleBookTap,
              onAddBook: _handleAddBook,
              onColorChanged: _handleColorChanged,
              onDeleteBook: _handleDeleteBook,
            ),
          ],
        ),
      ),
    ],
  );
}
```

- [ ] **Step 5: Run `flutter analyze` on all modified files**

```bash
cd /Users/preeth/digital-vision-board && flutter analyze lib/screens/journal/
```

Expected: no errors. Fix any type mismatches.

- [ ] **Step 6: Run `flutter test` to verify no regressions**

```bash
cd /Users/preeth/digital-vision-board && flutter test
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/journal/journal_notes_screen.dart
git commit -m "refactor: update JournalNotesScreen to use bookshelf + push navigation"
```

---

## Task 5: Final wiring check and cleanup

- [ ] **Step 1: Check `_handleAddBook` still works end-to-end**

`_handleAddBook` in `JournalNotesScreen` → `ChooseCoverScreen.show` → `JournalBookStorageService.addBook` → `_reload`. This creates user books that appear in the user spines row. Verify the flow still works with the simplified state.

- [ ] **Step 2: Verify `_handleTitleChanged` is still reachable**

With the new bookshelf, title editing is no longer done inline. The `onTitleChanged` callback was used by `InteractiveJournalBook`. Since that widget is replaced, title editing can be removed or moved to a long-press → "Rename" action in the overlay. For now, remove `onTitleChanged` from the public API if it's no longer triggered. If it was used, add a "Rename" text field to the overlay panel.

Check if any code still calls `_handleTitleChanged` → if not, remove it.

- [ ] **Step 3: Remove `onType` and `onRecord` from `JournalHeroSection` if truly unused**

If the "Type" / "Record" quick-action buttons were moved to `JournalBrowseSection` or are no longer in the hero area, remove these params to avoid dead code. Confirm by searching:

```bash
grep -r "onType\|onRecord" lib/screens/journal/ --include="*.dart"
```

- [ ] **Step 4: Run full analyze + test**

```bash
cd /Users/preeth/digital-vision-board && flutter analyze && flutter test
```

Expected: 0 errors, all tests pass.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete journal bookshelf UI with push navigation"
```
