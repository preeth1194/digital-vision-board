import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/grid_tile_model.dart';
import '../../utils/app_typography.dart';
import '../../models/journal_book.dart';
import '../../models/journal_entry.dart';
import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';
import '../../services/boards_storage_service.dart';
import '../../services/grid_tiles_storage_service.dart';
import '../../services/journal_book_storage_service.dart';
import '../../services/journal_storage_service.dart';
import '../../services/recipe_storage_service.dart';
import '../../services/vision_board_components_storage_service.dart';
import '../recipes/recipe_book_screen.dart';

import '../../widgets/dashboard/affirmation_summary_card.dart';
import 'journal_book_detail_screen.dart';
import 'widgets/choose_cover_screen.dart';
import 'widgets/journal_hero_section.dart';

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

  // Journal books state
  List<JournalBook> _books = const [];
  Map<String, int> _bookEntryCounts = const {};
  int _recipeCount = 0;

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
      final recipes = await RecipeStorageService.loadAll(prefs: prefs);

      // Load books and ensure default book exists
      final books = await JournalBookStorageService.ensureDefaultBook(
        prefs: prefs,
      );

      // Calculate entry counts per book
      final entryCounts = <String, int>{};
      for (final book in books) {
        final count = await JournalStorageService.getEntryCountForBook(
          book.id,
          prefs: prefs,
        );
        entryCounts[book.id] = count;
      }

      if (!mounted) return;
      setState(() {
        _goalTitles = extracted.goalTitles;
        _goals = extracted.goals;
        _feedbackAndTaggedJournalFeed = extracted.noteFeed;
        _hasGoalLogs = extracted.noteFeed.any(
          (n) => (n.goalTitle ?? '').trim().isNotEmpty,
        );
        _journalEntries = journal;
        _books = books;
        _bookEntryCounts = entryCounts;
        _recipeCount = recipes.length;
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      await _reload(prefs: prefs);
    }
  }

  Future<void> _handleBookTap(JournalBook book) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (book.id == JournalBookStorageService.recipeBookId) {
      await nav.push(
        MaterialPageRoute(builder: (_) => const RecipeBookScreen()),
      );
    } else {
      final goalTitles = _goalTitles;
      await nav.push(
        PageRouteBuilder(
          pageBuilder: (ctx, anim, secAnim) => JournalBookDetailScreen(
            book: book,
            goalTitles: goalTitles,
          ),
          transitionsBuilder: (ctx, animation, secAnim, child) {
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
    if (!mounted) return;
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

  // ---------------------------------------------------------------------------
  // Tab builders
  // ---------------------------------------------------------------------------

  Widget _journalTab() {
    return ListView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      children: [
        JournalHeroSection(
          books: _books,
          entryCounts: _bookEntryCounts,
          recipeCount: _recipeCount,
          onBookTap: _handleBookTap,
          onAddBook: _handleAddBook,
          onColorChanged: _handleColorChanged,
          onDeleteBook: _handleDeleteBook,
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AffirmationSummaryCard(),
        ),
        const SizedBox(height: 12),
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
        .where(
          (g) => (notesByGoal[g.title] ?? const <_NoteFeedItem>[]).isNotEmpty,
        )
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padBottom),
      children: [
        Text(
          'Goal logs',
          style: AppTypography.heading2(
            context,
          ).copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (goalsWithNotes.isEmpty) const Text('No habit feedback logged yet.'),
        for (final g in goalsWithNotes)
          Card(
            child: ExpansionTile(
              title: Text(g.title, style: AppTypography.heading3(context)),
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
                            if ((n.subtitle ?? '').trim().isNotEmpty)
                              n.subtitle!,
                          ].join(' • '),
                          style: AppTypography.caption(context),
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
                      final prefs =
                          _prefs ?? await SharedPreferences.getInstance();
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
      final comps = await VisionBoardComponentsStorageService.loadComponents(
        b.id,
        prefs: prefs,
      );
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
  final goalsSorted = uniqueGoals.values.toList()
    ..sort((a, b) => a.title.compareTo(b.title));
  final titlesSorted = goalTitlesSet.toList()..sort((a, b) => a.compareTo(b));
  feed.sort((a, b) => b.at.compareTo(a.at));

  return _ExtractedNotesResult(
    goalTitles: titlesSorted,
    goals: goalsSorted,
    noteFeed: feed,
  );
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
  })
  addFeedbackNote,
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
        subtitle: [
          h.name,
          boardTitle,
        ].where((s) => s.trim().isNotEmpty).join(' • '),
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
  })
  addFeedbackNote,
}) {
  for (final h in component.habits) {
    for (final e in h.feedbackByDate.entries) {
      final note = (e.value.note ?? '').trim();
      if (note.isEmpty) continue;
      addFeedbackNote(
        isoDate: e.key,
        title: e.key,
        body: note,
        subtitle: [
          h.name,
          boardTitle,
        ].where((s) => s.trim().isNotEmpty).join(' • '),
        goalTitle: goalTitle,
      );
    }
  }
}
