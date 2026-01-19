import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../models/grid_tile_model.dart';
import '../models/journal_entry.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import '../../services/board/boards_storage_service.dart';
import '../../services/board/grid_tiles_storage_service.dart';
import '../../services/journal/journal_storage_service.dart';
import '../../services/board/vision_board_components_storage_service.dart';

final class JournalNotesScreen extends StatefulWidget {
  final bool embedded;

  const JournalNotesScreen({super.key, this.embedded = false});

  @override
  State<JournalNotesScreen> createState() => _JournalNotesScreenState();
}

final class _NoteFeedItem {
  final DateTime at;
  final String title;
  final String body;
  final String? subtitle;
  /// When present, this note is associated with a specific goal title.
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

class _JournalNotesScreenState extends State<JournalNotesScreen> {
  bool _loading = true;

  SharedPreferences? _prefs;

  List<String> _goalTitles = const [];
  List<_GoalSummary> _goals = const [];
  List<_NoteFeedItem> _feedbackAndTaggedJournalFeed = const [];
  List<JournalEntry> _journalEntries = const [];
  String _journalTagFilter = '__all__';
  List<String> _pinnedJournalIds = const [];
  static const String _pinsKey = 'dv_journal_pins_v1';
  bool _hasGoalLogs = false;
  static String _entryTitle(JournalEntry e) {
    final t = (e.title ?? '').trim();
    if (t.isNotEmpty) return t;
    final words = _entryPlainText(e).trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.isEmpty ? 'Journal' : words.take(3).join(' ');
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _pinnedJournalIds = _loadPinnedIds(prefs: prefs);
    await _reload(prefs: prefs);
  }

  static List<String> _loadPinnedIds({required SharedPreferences prefs}) {
    final raw = prefs.getStringList(_pinsKey) ?? const <String>[];
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).take(2).toList();
  }

  Future<void> _savePinnedIds(List<String> ids) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    final next = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList().take(2).toList();
    await prefs.setStringList(_pinsKey, next);
    if (!mounted) return;
    setState(() => _pinnedJournalIds = next);
  }

  Future<void> _togglePin(JournalEntry e) async {
    final id = e.id;
    final current = List<String>.of(_pinnedJournalIds);
    if (current.contains(id)) {
      current.remove(id);
      await _savePinnedIds(current);
      return;
    }
    if (current.length >= 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can pin up to 2 entries. Unpin one first.')),
      );
      return;
    }
    current.insert(0, id);
    await _savePinnedIds(current);
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
      if (!mounted) return;
      setState(() {
        _goalTitles = extracted.goalTitles;
        _goals = extracted.goals;
        _feedbackAndTaggedJournalFeed = extracted.noteFeed;
        // Only show Goal logs when there is at least one goal-linked habit feedback note.
        _hasGoalLogs = extracted.noteFeed.any((n) => (n.goalTitle ?? '').trim().isNotEmpty);
        _journalEntries = journal;
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _plainTextFromDoc(quill.Document doc) {
    // Quill often includes a trailing newline; keep UX clean.
    return doc.toPlainText().replaceAll('\r', '').trim();
  }

  static String _entryPlainText(JournalEntry e) {
    final t = e.text.trim();
    if (t.isNotEmpty) return t;
    final delta = e.delta;
    if (delta is List && delta.isNotEmpty) {
      try {
        return _plainTextFromDoc(quill.Document.fromJson(delta));
      } catch (_) {}
    }
    return '';
  }

  static String _firstLines(String text, int maxLines) {
    final lines = text.replaceAll('\r', '').split('\n');
    if (lines.length <= maxLines) return text.trim();
    return lines.take(maxLines).join('\n').trim();
  }

  void _openJournalEntryViewer(JournalEntry e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _JournalEntryViewerScreen(entry: e),
      ),
    );
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
    final res = await Navigator.of(context).push<_JournalEditorResult?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _JournalEntryEditorScreen(
          goalTitles: _goalTitles,
          existingTags: _allJournalTags(_journalEntries),
        ),
      ),
    );
    if (res == null) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await JournalStorageService.addEntry(
      title: res.title,
      text: res.plainText,
      delta: res.deltaJson,
      tags: res.tags,
      goalTitle: res.legacyGoalTitle,
      prefs: prefs,
    );
    await _reload(prefs: prefs);
  }

  Future<void> _deleteJournalEntry(JournalEntry e) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    if (_pinnedJournalIds.contains(e.id)) {
      final nextPins = List<String>.of(_pinnedJournalIds)..remove(e.id);
      await prefs.setStringList(_pinsKey, nextPins);
      _pinnedJournalIds = nextPins;
    }
    await JournalStorageService.deleteEntry(e.id, prefs: prefs);
    await _reload(prefs: prefs);
  }

  Widget _journalTab() {
    final padBottom = MediaQuery.of(context).padding.bottom;
    final tags = _allJournalTags(_journalEntries);
    final filtered = _journalTagFilter == '__all__'
        ? _journalEntries
        : _journalEntries.where((e) => e.tags.contains(_journalTagFilter)).toList();
    final pinnedSet = _pinnedJournalIds.toSet();
    final pinned = filtered.where((e) => pinnedSet.contains(e.id)).toList()
      ..sort((a, b) => _pinnedJournalIds.indexOf(a.id).compareTo(_pinnedJournalIds.indexOf(b.id)));
    final unpinned = filtered.where((e) => !pinnedSet.contains(e.id)).toList();
    final filteredEntries = [...pinned, ...unpinned];
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padBottom),
      children: [
        Card(
          child: InkWell(
            onTap: _openNewJournalEditor,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap to write a journal entry…',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Your entries', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (tags.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _journalTagFilter == '__all__',
                  onSelected: (_) => setState(() => _journalTagFilter = '__all__'),
                ),
                const SizedBox(width: 8),
                for (final t in tags) ...[
                  FilterChip(
                    label: Text(t),
                    selected: _journalTagFilter == t,
                    onSelected: (_) => setState(() => _journalTagFilter = t),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (filteredEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No journal entries yet.'),
          ),
        if (filteredEntries.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: filteredEntries.length,
            itemBuilder: (ctx, idx) {
              final e = filteredEntries[idx];
              final isPinned = pinnedSet.contains(e.id);
              return Card(
                child: InkWell(
                  onTap: () => _openJournalEntryViewer(e),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _entryTitle(e),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              tooltip: isPinned ? 'Unpin' : 'Pin',
                              icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                              onPressed: () => _togglePin(e),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fmtDateTime(e.createdAt),
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                        if (e.tags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in e.tags.take(4))
                                Chip(
                                  label: Text(tag),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            _firstLines(_entryPlainText(e), 5),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteJournalEntry(e),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _notesTab() {
    final padBottom = MediaQuery.of(context).padding.bottom;
    final notesByGoal = <String, List<_NoteFeedItem>>{};
    for (final n in _feedbackAndTaggedJournalFeed) {
      final gt = (n.goalTitle ?? '').trim();
      if (gt.isEmpty) continue; // hide unassigned items in grouped Notes view
      (notesByGoal[gt] ??= <_NoteFeedItem>[]).add(n);
    }
    for (final list in notesByGoal.values) {
      list.sort((a, b) => b.at.compareTo(a.at));
    }
    final goalsWithNotes = _goals.where((g) => (notesByGoal[g.title] ?? const <_NoteFeedItem>[]).isNotEmpty).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padBottom),
      children: [
        const Text('Goal logs', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (goalsWithNotes.isEmpty)
          const Text('No habit feedback logged yet.'),
        for (final g in goalsWithNotes)
          Card(
            child: ExpansionTile(
              title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                (g.whyImportant ?? '').trim().isEmpty ? 'Why important: (not set)' : 'Why important: ${g.whyImportant}',
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
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
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
                ),
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
                              children: [
                                _journalTab(),
                                _notesTab(),
                              ],
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
                          children: [
                            _journalTab(),
                            _notesTab(),
                          ],
                        )
                      : _journalTab(),
            ),
    );
  }
}

final class _JournalEditorResult {
  final List<dynamic> deltaJson;
  final String plainText;
  final String title;
  final List<String> tags;
  /// Legacy goal title (optional). If set, this entry is considered goal-tagged.
  final String? legacyGoalTitle;

  const _JournalEditorResult({
    required this.deltaJson,
    required this.plainText,
    required this.title,
    required this.tags,
    required this.legacyGoalTitle,
  });
}

final class _JournalEntryEditorScreen extends StatefulWidget {
  final List<String> goalTitles;
  final List<String> existingTags;
  const _JournalEntryEditorScreen({
    required this.goalTitles,
    required this.existingTags,
  });

  @override
  State<_JournalEntryEditorScreen> createState() => _JournalEntryEditorScreenState();
}

class _JournalEntryEditorScreenState extends State<_JournalEntryEditorScreen> {
  late final quill.QuillController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;
  final Set<String> _tags = <String>{};

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _focused = _focusNode.hasFocus);
    });
    // Auto-focus for distraction-free writing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickTags() async {
    final goals = widget.goalTitles;
    final existing = widget.existingTags;
    final all = <String>{
      ...existing.map((e) => e.trim()).where((e) => e.isNotEmpty),
      ...goals.map((e) => e.trim()).where((e) => e.isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final q = TextEditingController();
        List<String> filtered = List.of(all);
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void applyFilter(String v) {
              final t = v.trim().toLowerCase();
              setLocal(() {
                filtered = (t.isEmpty)
                    ? List.of(all)
                    : all.where((g) => g.toLowerCase().contains(t)).toList();
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + MediaQuery.of(ctx).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Tag (optional)', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: q,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search or add a tag…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: applyFilter,
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length + 2,
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            return ListTile(
                              leading: const Icon(Icons.done),
                              title: const Text('Done'),
                              onTap: () => Navigator.of(ctx).pop(),
                            );
                          }
                          if (i == 1) {
                            final candidate = q.text.trim();
                            final canAdd = candidate.isNotEmpty && !all.any((t) => t.toLowerCase() == candidate.toLowerCase());
                            if (!canAdd) return const SizedBox.shrink();
                            return ListTile(
                              leading: const Icon(Icons.add),
                              title: Text('Add “$candidate”'),
                              onTap: () {
                                setState(() => _tags.add(candidate));
                                setLocal(() {
                                  q.clear();
                                  filtered = List.of(all);
                                });
                              },
                            );
                          }
                          final g = filtered[i - 2];
                          final selected = _tags.contains(g);
                          return ListTile(
                            leading: Icon(selected ? Icons.check_box : Icons.check_box_outline_blank),
                            title: Text(g),
                            trailing: goals.contains(g) ? const Icon(Icons.flag_outlined) : null,
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _tags.remove(g);
                                } else {
                                  _tags.add(g);
                                }
                              });
                              setLocal(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _deriveTitleFromDeltaOrPlain({
    required List<dynamic> deltaJson,
    required String plainText,
  }) {
    // 1) If the user used a header style, Quill stores the 'header' attribute on the newline op.
    // We'll scan line-by-line: when we hit a newline with header attribute, use that line's text.
    final words = plainText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final fallback = words.isEmpty ? 'Journal' : words.take(3).join(' ');

    try {
      final ops = deltaJson.whereType<Map>().toList();
      var lineBuf = StringBuffer();
      for (final op in ops) {
        final insert = op['insert'];
        final attrs = op['attributes'];
        if (insert is! String) continue;

        for (var i = 0; i < insert.length; i++) {
          final ch = insert[i];
          if (ch == '\n') {
            final header = (attrs is Map) ? attrs['header'] : null;
            final line = lineBuf.toString().trim();
            lineBuf = StringBuffer();
            if (header != null && line.isNotEmpty) {
              return line;
            }
          } else {
            lineBuf.write(ch);
          }
        }
      }
    } catch (_) {}

    return fallback;
  }

  void _save() {
    final deltaJson = _controller.document.toDelta().toJson();
    final plain = _controller.document.toPlainText().replaceAll('\r', '').trim();
    if (plain.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before saving.')),
      );
      return;
    }
    final title = _deriveTitleFromDeltaOrPlain(deltaJson: deltaJson, plainText: plain);
    final tagsNorm = _tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    String? legacyGoal;
    for (final t in tagsNorm) {
      if (widget.goalTitles.contains(t)) {
        legacyGoal = t;
        break;
      }
    }
    Navigator.of(context).pop(
      _JournalEditorResult(
        deltaJson: deltaJson,
        plainText: plain,
        title: title,
        tags: tagsNorm,
        legacyGoalTitle: legacyGoal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagsSorted = _tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write'),
        actions: [
          IconButton(
            tooltip: 'Tag',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () async {
              await _pickTags();
              if (!mounted) return;
              setState(() {});
            },
          ),
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_focused)
            quill.QuillSimpleToolbar(
              controller: _controller,
              config: quill.QuillSimpleToolbarConfig(
                // Make icons compact so the toolbar fits on screen.
                toolbarSize: 24,
                multiRowsDisplay: false,
                showDividers: false,
                toolbarSectionSpacing: 0,
                toolbarRunSpacing: 2,
                buttonOptions: const quill.QuillSimpleToolbarButtonOptions(
                  base: quill.QuillToolbarBaseButtonOptions(
                    iconSize: 13,
                    iconButtonFactor: 1.35,
                  ),
                ),
                showFontFamily: false,
                showFontSize: false,
                showStrikeThrough: false,
                showInlineCode: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: false,
                showAlignmentButtons: false,
                showHeaderStyle: false,
                showIndent: false,
                showLink: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showUndo: true,
                showRedo: true,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showListBullets: true,
                showListNumbers: true,
                showListCheck: true,
                showQuote: true,
                showCodeBlock: false,
              ),
            ),
          if (tagsSorted.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in tagsSorted)
                      Chip(
                        label: Text(t),
                        onDeleted: () => setState(() => _tags.remove(t)),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: quill.QuillEditor.basic(
              controller: _controller,
              focusNode: _focusNode,
              config: const quill.QuillEditorConfig(
                placeholder: 'Write your journal entry…',
                padding: EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _JournalEntryViewerScreen extends StatelessWidget {
  final JournalEntry entry;
  const _JournalEntryViewerScreen({required this.entry});

  @override
  Widget build(BuildContext context) {
    final delta = entry.delta;
    quill.QuillController? controller;
    if (delta is List && delta.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(delta);
        controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      } catch (_) {
        controller = null;
      }
    }
    final plain = _JournalNotesScreenState._entryPlainText(entry);
    return Scaffold(
      appBar: AppBar(
        title: Text(_JournalNotesScreenState._fmtDateTime(entry.createdAt)),
      ),
      body: SafeArea(
        child: controller != null
            ? Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: const quill.QuillEditorConfig(
                    checkBoxReadOnly: true,
                    padding: EdgeInsets.zero,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                child: SelectableText(plain),
              ),
      ),
    );
  }
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
        final whyImportant = goal?.cbt?.visualization; // wizard stores "whyImportant" here
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
        String? goalTitle;
        if (c is GoalOverlayComponent) {
          final overlayTitle = (c.goal.title ?? '').trim();
          final whyImportant = c.goal.cbt?.visualization;
          if (overlayTitle.isNotEmpty) addGoal(title: overlayTitle, whyImportant: whyImportant);
          goalTitle = overlayTitle.isEmpty ? null : overlayTitle;
        }

        _extractFeedbackFromComponent(
          component: c,
          boardTitle: b.title,
          goalTitle: goalTitle,
          addFeedbackNote: addFeedbackNote,
        );
      }
    }
  }

  // Note: Journal entries are intentionally NOT included in Goal logs.

  // Normalize: unique goals, sorted by title.
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
  // Goal logs should include ONLY habit feedback notes (no tasks/checklists, no CBT notes).
  for (final h in tile.habits) {
    for (final e in h.feedbackByDate.entries) {
      final fb = e.value;
      final note = (fb.note ?? '').trim();
      if (note.isEmpty) continue;
      addFeedbackNote(
        isoDate: e.key,
        // Title should be the logged date (date-only).
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
  // Goal logs should include ONLY habit feedback notes.
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

