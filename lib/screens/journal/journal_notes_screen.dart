import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/grid_tile_model.dart';
import '../../models/journal_book.dart';
import '../../models/journal_entry.dart';
import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';
import '../../services/boards_storage_service.dart';
import '../../services/grid_tiles_storage_service.dart';
import '../../services/journal_book_storage_service.dart';
import '../../services/journal_storage_service.dart';
import '../../services/vision_board_components_storage_service.dart';

import 'journal_editor_screen.dart';
import 'models/journal_editor_models.dart';
import 'widgets/choose_cover_screen.dart';
import 'widgets/journal_browse.dart';
import 'widgets/journal_landing.dart';

final class JournalNotesScreen extends StatefulWidget {
  final bool embedded;

  const JournalNotesScreen({super.key, this.embedded = false});

  @override
  State<JournalNotesScreen> createState() => _JournalNotesScreenState();
}

// ---------------------------------------------------------------------------
// Internal model classes (only used by the state class below)
// ---------------------------------------------------------------------------

final class _NoteFeedItem {
  final DateTime at;
  final String title;
  final String body;
  final String? subtitle;
  final String? goalTitle;

  const _NoteFeedItem({
    required this.at,
    required this.title,
    required this.body,
    required this.subtitle,
    required this.goalTitle,
  });
}

final class _GoalSummary {
  final String title;
  final String? whyImportant;

  const _GoalSummary({required this.title, required this.whyImportant});
}

final class _ExtractedNotesResult {
  final List<String> goalTitles;
  final List<_GoalSummary> goals;
  final List<_NoteFeedItem> noteFeed;

  const _ExtractedNotesResult({
    required this.goalTitles,
    required this.goals,
    required this.noteFeed,
  });
}

// ---------------------------------------------------------------------------
// Main state
// ---------------------------------------------------------------------------

class _JournalNotesScreenState extends State<JournalNotesScreen> {
  bool _loading = true;

  SharedPreferences? _prefs;

  List<String> _goalTitles = const [];
  List<_GoalSummary> _goals = const [];
  List<_NoteFeedItem> _feedbackAndTaggedJournalFeed = const [];
  List<JournalEntry> _journalEntries = const [];
  bool _hasGoalLogs = false;

  // Stacked paper card overlay state
  bool _showLatestEntry = false;

  // Journal books state
  List<JournalBook> _books = const [];
  String? _selectedBookId;
  Map<String, int> _bookEntryCounts = const {};
  String? _newBookId; // ID of newly created book for auto-focus

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

  static String _fmtDateTime(DateTime dt) {
    String two(int x) => x.toString().padLeft(2, '0');
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mm = two(dt.month);
    final dd = two(dt.day);
    final hh = two(dt.hour);
    final min = two(dt.minute);
    return '$yyyy-$mm-$dd $hh:$min';
  }

  Future<void> _reload({required SharedPreferences prefs}) async {
    setState(() => _loading = true);
    try {
      final boards = await BoardsStorageService.loadBoards(prefs: prefs);
      final extracted = await _extractFromBoards(boards: boards, prefs: prefs);
      final journal = await JournalStorageService.loadEntries(prefs: prefs);
      
      // Load books and ensure default book exists
      final books = await JournalBookStorageService.ensureDefaultBook(prefs: prefs);
      
      // Calculate entry counts per book
      final entryCounts = <String, int>{};
      for (final book in books) {
        final count = await JournalStorageService.getEntryCountForBook(book.id, prefs: prefs);
        entryCounts[book.id] = count;
      }
      
      if (!mounted) return;
      setState(() {
        _goalTitles = extracted.goalTitles;
        _goals = extracted.goals;
        _feedbackAndTaggedJournalFeed = extracted.noteFeed;
        _hasGoalLogs = extracted.noteFeed.any((n) => (n.goalTitle ?? '').trim().isNotEmpty);
        _journalEntries = journal;
        _books = books;
        _bookEntryCounts = entryCounts;
        // Select first book if none selected
        _selectedBookId ??= books.isNotEmpty ? books.first.id : null;
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  Future<void> _openJournalEditorForEdit(JournalEntry entry) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            JournalEntryEditorScreen(
          goalTitles: _goalTitles,
          existingTags: _allJournalTags(_journalEntries),
          existingEntry: entry,
        ),
        transitionsBuilder: _pageTransition,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await _reload(prefs: prefs);
  }

  static List<String> _allJournalTags(List<JournalEntry> entries) {
    final set = <String>{};
    for (final e in entries) {
      for (final t in e.tags) {
        final s = t.trim();
        if (s.isEmpty) continue;
        set.add(s);
      }
    }
    final out = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  Future<void> _openNewJournalEditor() async {
    // Open the editor directly for the selected book
    final res = await Navigator.of(context).push<JournalEditorResult?>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            JournalEntryEditorScreen(
          goalTitles: _goalTitles,
          existingTags: _allJournalTags(_journalEntries),
          bookId: _selectedBookId,
        ),
        transitionsBuilder: _pageTransition,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
    if (!mounted) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    if (res != null) {
      await JournalStorageService.addEntry(
        title: res.title,
        text: res.plainText,
        delta: res.deltaJson,
        tags: res.tags,
        goalTitle: res.legacyGoalTitle,
        bookId: _selectedBookId,
        prefs: prefs,
      );
    }
    await _reload(prefs: prefs);
  }

  Future<void> _openNewJournalEditorWithVoice() async {
    await Navigator.of(context).push<JournalEditorResult?>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            JournalEntryEditorScreen(
          goalTitles: _goalTitles,
          existingTags: _allJournalTags(_journalEntries),
          autoShowVoiceRecorder: true,
          bookId: _selectedBookId,
        ),
        transitionsBuilder: (context, animation, _, child) {
          final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
          );
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await _reload(prefs: prefs);
  }

  static Widget _pageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Journal Books
  // ---------------------------------------------------------------------------

  Future<void> _handleAddBook() async {
    // Show cover selection screen
    final result = await ChooseCoverScreen.show(context);
    if (result == null || !mounted) return;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    // Create book with selected cover, name, and optional image
    final book = await JournalBookStorageService.addBook(
      name: result.name,
      coverColor: result.color,
      coverImagePath: result.imagePath,
      prefs: prefs,
    );
    if (book != null && mounted) {
      setState(() {
        _selectedBookId = book.id;
        _newBookId = book.id; // Trigger auto-focus on title
      });
      await _reload(prefs: prefs);
      // Clear newBookId after a short delay to prevent re-triggering
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _newBookId = null);
      });
    }
  }

  void _handleBookSelected(JournalBook book) {
    setState(() => _selectedBookId = book.id);
  }

  Future<void> _handleOpenEntry(JournalEntry entry) async {
    await _openJournalEditorForEdit(entry);
  }

  Future<void> _handleDeleteEntry(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
          'This will permanently delete "${entry.title ?? 'Untitled'}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  Future<void> _handleDeleteBook(String bookId) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    
    // Delete all entries in the book first
    final entries = _journalEntries.where((e) {
      if (e.bookId == null || e.bookId!.isEmpty) {
        return bookId == JournalBookStorageService.defaultBookId;
      }
      return e.bookId == bookId;
    }).toList();
    for (final entry in entries) {
      await JournalStorageService.deleteEntry(entry.id, prefs: prefs);
    }
    
    // Delete the book itself
    await JournalBookStorageService.deleteBook(bookId, prefs: prefs);
    
    // Select another book if available
    if (_selectedBookId == bookId) {
      setState(() => _selectedBookId = null);
    }
    
    await _reload(prefs: prefs);
  }

  Future<void> _handleColorChanged(String bookId, int color) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await JournalBookStorageService.updateBook(
      id: bookId,
      coverColor: color,
      prefs: prefs,
    );
    await _reload(prefs: prefs);
  }

  Future<void> _handleTitleChanged(String bookId, String newTitle) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await JournalBookStorageService.updateBook(
      id: bookId,
      name: newTitle,
      prefs: prefs,
    );
    await _reload(prefs: prefs);
  }

  // Get entries grouped by book
  Map<String, List<JournalEntry>> get _entriesByBook {
    final result = <String, List<JournalEntry>>{};
    for (final entry in _journalEntries) {
      final bookId = (entry.bookId == null || entry.bookId!.isEmpty)
          ? JournalBookStorageService.defaultBookId
          : entry.bookId!;
      (result[bookId] ??= []).add(entry);
    }
    // Sort entries by date (newest first)
    for (final list in result.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return result;
  }

  // Get entries filtered by selected book
  List<JournalEntry> get _filteredJournalEntries {
    if (_selectedBookId == null) return _journalEntries;
    return _journalEntries.where((e) {
      if (e.bookId == null || e.bookId!.isEmpty) {
        return _selectedBookId == JournalBookStorageService.defaultBookId;
      }
      return e.bookId == _selectedBookId;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Tab builders
  // ---------------------------------------------------------------------------

  Widget _journalTab() {
    final filteredEntries = _filteredJournalEntries;

    return Stack(
      children: [
        Column(
          children: [
            // Pinned header (acts like an app bar)
            JournalBrowseSection(
              onAddBook: _handleAddBook,
            ),
            // Scrollable content beneath
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(
                  top: 0,
                  bottom: MediaQuery.of(context).padding.bottom + 100,
                ),
                children: [
                  JournalHeroSection(
                    onType: _openNewJournalEditor,
                    onRecord: _openNewJournalEditorWithVoice,
                    onBookTap: () {
                      if (filteredEntries.isNotEmpty) {
                        setState(() => _showLatestEntry = !_showLatestEntry);
                      }
                    },
                    entryCount: filteredEntries.length,
                    books: _books,
                    selectedBookId: _selectedBookId,
                    entryCounts: _bookEntryCounts,
                    entriesByBook: _entriesByBook,
                    onBookSelected: _handleBookSelected,
                    onAddBook: _handleAddBook,
                    onOpenEntry: _handleOpenEntry,
                    onDeleteEntry: _handleDeleteEntry,
                    onDeleteBook: _handleDeleteBook,
                    onColorChanged: _handleColorChanged,
                    onTitleChanged: _handleTitleChanged,
                    newBookId: _newBookId,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_showLatestEntry && filteredEntries.isNotEmpty)
          LatestEntryOverlay(
            entry: filteredEntries.first,
            onTap: () {
              setState(() => _showLatestEntry = false);
              _openJournalEditorForEdit(filteredEntries.first);
            },
            onDismiss: () => setState(() => _showLatestEntry = false),
          ),
      ],
    );
  }

  Widget _notesTab() {
    final padBottom = MediaQuery.of(context).padding.bottom;
    final notesByGoal = <String, List<_NoteFeedItem>>{};
    for (final n in _feedbackAndTaggedJournalFeed) {
      final gt = (n.goalTitle ?? '').trim();
      if (gt.isEmpty) continue;
      (notesByGoal[gt] ??= <_NoteFeedItem>[]).add(n);
    }
    for (final list in notesByGoal.values) {
      list.sort((a, b) => b.at.compareTo(a.at));
    }
    final goalsWithNotes = _goals
        .where((g) => (notesByGoal[g.title] ?? const <_NoteFeedItem>[]).isNotEmpty)
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padBottom),
      children: [
        const Text('Goal logs', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (goalsWithNotes.isEmpty) const Text('No habit feedback logged yet.'),
        for (final g in goalsWithNotes)
          Card(
            child: ExpansionTile(
              title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                (g.whyImportant ?? '').trim().isEmpty
                    ? 'Why important: (not set)'
                    : 'Why important: ${g.whyImportant}',
              ),
              children: [
                const Divider(height: 1),
                ...notesByGoal[g.title]!.map(
                  (n) => ListTile(
                    title: Text(n.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(n.body),
                        const SizedBox(height: 8),
                        Text(
                          [
                            _fmtDateTime(n.at),
                            if ((n.subtitle ?? '').trim().isNotEmpty) n.subtitle!,
                          ].join(' • '),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final showGoalLogs = _hasGoalLogs;
    final embedded = widget.embedded;
    final title = showGoalLogs ? 'Journal & Notes' : 'Journal';
    return DefaultTabController(
      key: ValueKey<bool>(showGoalLogs),
      length: showGoalLogs ? 2 : 1,
      child: embedded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_loading && showGoalLogs)
                  const TabBar(
                    tabs: [
                      Tab(text: 'Journal'),
                      Tab(text: 'Goal logs'),
                    ],
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : showGoalLogs
                          ? TabBarView(
                              key: const ValueKey<String>('with_goal_logs'),
                              children: [_journalTab(), _notesTab()],
                            )
                          : _journalTab(),
                ),
              ],
            )
          : Scaffold(
              appBar: AppBar(
                title: Text(title),
                bottom: _loading
                    ? null
                    : showGoalLogs
                        ? const TabBar(
                            tabs: [
                              Tab(text: 'Journal'),
                              Tab(text: 'Goal logs'),
                            ],
                          )
                        : null,
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      final prefs = _prefs ?? await SharedPreferences.getInstance();
                      _prefs ??= prefs;
                      await _reload(prefs: prefs);
                    },
                  ),
                ],
              ),
              body: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : showGoalLogs
                      ? TabBarView(
                          key: const ValueKey<String>('with_goal_logs'),
                          children: [_journalTab(), _notesTab()],
                        )
                      : _journalTab(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Board extraction helpers (top-level private functions)
// ---------------------------------------------------------------------------

Future<_ExtractedNotesResult> _extractFromBoards({
  required List<VisionBoardInfo> boards,
  required SharedPreferences prefs,
}) async {
  final goals = <_GoalSummary>[];
  final goalTitlesSet = <String>{};
  final feed = <_NoteFeedItem>[];

  void addGoal({required String title, required String? whyImportant}) {
    final t = title.trim();
    if (t.isEmpty) return;
    final wi = (whyImportant ?? '').trim();
    goalTitlesSet.add(t);
    goals.add(_GoalSummary(title: t, whyImportant: wi.isEmpty ? null : wi));
  }

  void addFeedbackNote({
    required String isoDate,
    required String title,
    required String body,
    required String? subtitle,
    required String? goalTitle,
  }) {
    final b = body.trim();
    if (b.isEmpty) return;
    DateTime at;
    try {
      at = DateTime.parse(isoDate);
    } catch (_) {
      at = DateTime.now();
    }
    final gt = (goalTitle ?? '').trim();
    feed.add(
      _NoteFeedItem(
        at: at,
        title: title,
        body: b,
        subtitle: subtitle,
        goalTitle: gt.isEmpty ? null : gt,
      ),
    );
  }

  for (final b in boards) {
    if (b.layoutType == VisionBoardInfo.layoutGrid) {
      final tiles = await GridTilesStorageService.loadTiles(b.id, prefs: prefs);
      for (final t in tiles) {
        final goal = t.goal;
        final goalTitle = (goal?.title ?? '').trim();
        final whyImportant = goal?.cbt?.visualization;
        if (goalTitle.isNotEmpty) {
          addGoal(title: goalTitle, whyImportant: whyImportant);
        }
        _extractCbtAndFeedbackFromTile(
          tile: t,
          boardTitle: b.title,
          goalTitle: goalTitle.isEmpty ? null : goalTitle,
          addFeedbackNote: addFeedbackNote,
          feed: feed,
        );
      }
    } else {
      final comps = await VisionBoardComponentsStorageService.loadComponents(b.id, prefs: prefs);
      for (final c in comps) {
        _extractFeedbackFromComponent(
          component: c,
          boardTitle: b.title,
          goalTitle: null,
          addFeedbackNote: addFeedbackNote,
        );
      }
    }
  }

  final uniqueGoals = <String, _GoalSummary>{};
  for (final g in goals) {
    uniqueGoals[g.title] = g;
  }
  final goalsSorted = uniqueGoals.values.toList()..sort((a, b) => a.title.compareTo(b.title));
  final titlesSorted = goalTitlesSet.toList()..sort((a, b) => a.compareTo(b));
  feed.sort((a, b) => b.at.compareTo(a.at));

  return _ExtractedNotesResult(goalTitles: titlesSorted, goals: goalsSorted, noteFeed: feed);
}

void _extractCbtAndFeedbackFromTile({
  required GridTileModel tile,
  required String boardTitle,
  required String? goalTitle,
  required void Function({
    required String isoDate,
    required String title,
    required String body,
    required String? subtitle,
    required String? goalTitle,
  }) addFeedbackNote,
  required List<_NoteFeedItem> feed,
}) {
  for (final h in tile.habits) {
    for (final e in h.feedbackByDate.entries) {
      final fb = e.value;
      final note = (fb.note ?? '').trim();
      if (note.isEmpty) continue;
      addFeedbackNote(
        isoDate: e.key,
        title: e.key,
        body: note,
        subtitle: [h.name, boardTitle].where((s) => s.trim().isNotEmpty).join(' • '),
        goalTitle: goalTitle,
      );
    }
  }
}

void _extractFeedbackFromComponent({
  required VisionComponent component,
  required String boardTitle,
  required String? goalTitle,
  required void Function({
    required String isoDate,
    required String title,
    required String body,
    required String? subtitle,
    required String? goalTitle,
  }) addFeedbackNote,
}) {
  for (final h in component.habits) {
    for (final e in h.feedbackByDate.entries) {
      final note = (e.value.note ?? '').trim();
      if (note.isEmpty) continue;
      addFeedbackNote(
        isoDate: e.key,
        title: e.key,
        body: note,
        subtitle: [h.name, boardTitle].where((s) => s.trim().isNotEmpty).join(' • '),
        goalTitle: goalTitle,
      );
    }
  }
}
