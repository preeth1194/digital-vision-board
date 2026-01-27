import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';

import '../services/journal_image_storage_service.dart';

import '../models/grid_tile_model.dart';
import '../models/journal_entry.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import '../services/boards_storage_service.dart';
import '../services/grid_tiles_storage_service.dart';
import '../services/journal_storage_service.dart';
import '../services/vision_board_components_storage_service.dart';

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
  bool _selectionMode = false;
  final Set<String> _selectedEntryIds = <String>{};
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
    // Update image paths with actual entry ID after creation
    final entry = await JournalStorageService.addEntry(
      title: res.title,
      text: res.plainText,
      delta: res.deltaJson,
      tags: res.tags,
      goalTitle: res.legacyGoalTitle,
      imagePaths: res.imagePaths,
      prefs: prefs,
    );
    
    // If entry was created and we have images, update image filenames with actual entry ID
    if (entry != null && res.imagePaths.isNotEmpty) {
      final updatedImagePaths = <String>[];
      for (int i = 0; i < res.imagePaths.length; i++) {
        final oldPath = res.imagePaths[i];
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          final newPath = await JournalImageStorageService.saveImage(
            oldFile,
            entry.id,
            i,
          );
          updatedImagePaths.add(newPath);
          // Delete old temp file
          await JournalImageStorageService.deleteImage(oldPath);
        }
      }
      
      // Update entry with correct image paths
      if (updatedImagePaths.isNotEmpty) {
        final allEntries = await JournalStorageService.loadEntries(prefs: prefs);
        final updatedEntries = allEntries.map((e) {
          if (e.id == entry.id) {
            return JournalEntry(
              id: e.id,
              createdAtMs: e.createdAtMs,
              title: e.title,
              text: e.text,
              delta: e.delta,
              goalTitle: e.goalTitle,
              tags: e.tags,
              imagePaths: updatedImagePaths,
            );
          }
          return e;
        }).toList();
        await JournalStorageService.saveEntries(updatedEntries, prefs: prefs);
      }
    }
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
    // Delete associated images
    await JournalImageStorageService.deleteImagesForEntry(e.id);
    await JournalStorageService.deleteEntry(e.id, prefs: prefs);
    await _reload(prefs: prefs);
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedEntryIds.clear();
      }
    });
  }

  void _toggleEntrySelection(String entryId) {
    setState(() {
      if (_selectedEntryIds.contains(entryId)) {
        _selectedEntryIds.remove(entryId);
      } else {
        _selectedEntryIds.add(entryId);
      }
      if (_selectedEntryIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _mergeSelectedEntries() async {
    if (_selectedEntryIds.length < 2) return;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    
    final entriesToMerge = _journalEntries
        .where((e) => _selectedEntryIds.contains(e.id))
        .toList();
    
    if (entriesToMerge.length < 2) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Entries'),
        content: Text('Merge ${entriesToMerge.length} entries into one?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Sort by creation date (earliest first)
    entriesToMerge.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    
    // Merge content
    final firstEntry = entriesToMerge.first;
    final mergedDelta = <dynamic>[];
    final mergedTags = <String>{};
    final mergedImagePaths = <String>[];
    
    // Start with first entry's delta
    if (firstEntry.delta is List) {
      mergedDelta.addAll(firstEntry.delta as List);
    }
    
    // Add separator
    mergedDelta.add({
      'insert': '\n---\n',
      'attributes': {'header': 2}
    });
    
    // Merge remaining entries
    for (int i = 1; i < entriesToMerge.length; i++) {
      final entry = entriesToMerge[i];
      if (entry.delta is List) {
        mergedDelta.addAll(entry.delta as List);
      }
      mergedTags.addAll(entry.tags);
      mergedImagePaths.addAll(entry.imagePaths);
    }
    
    // Combine tags
    mergedTags.addAll(firstEntry.tags);
    final mergedTagsList = mergedTags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    
    // Combine images
    mergedImagePaths.addAll(firstEntry.imagePaths);
    
    // Get plain text
    String mergedPlainText = '';
    try {
      if (mergedDelta.isNotEmpty) {
        final doc = quill.Document.fromJson(mergedDelta);
        mergedPlainText = doc.toPlainText().replaceAll('\r', '').trim();
      }
    } catch (_) {
      // Fallback: combine plain text
      mergedPlainText = entriesToMerge.map((e) => _entryPlainText(e)).join('\n---\n');
    }
    
    // Create merged entry
    final now = DateTime.now().millisecondsSinceEpoch;
    final mergedEntry = JournalEntry(
      id: 'jrnl_$now',
      createdAtMs: firstEntry.createdAtMs, // Use earliest date
      title: firstEntry.title,
      text: mergedPlainText,
      delta: mergedDelta.isEmpty ? null : mergedDelta,
      goalTitle: firstEntry.goalTitle,
      tags: mergedTagsList,
      imagePaths: mergedImagePaths,
    );
    
    // Delete source entries and their images
    for (final entry in entriesToMerge) {
      await JournalImageStorageService.deleteImagesForEntry(entry.id);
      await JournalStorageService.deleteEntry(entry.id, prefs: prefs);
    }
    
    // Save merged entry
    final allEntries = await JournalStorageService.loadEntries(prefs: prefs);
    await JournalStorageService.saveEntries([mergedEntry, ...allEntries], prefs: prefs);
    
    // Clear selection
    setState(() {
      _selectedEntryIds.clear();
      _selectionMode = false;
    });
    
    await _reload(prefs: prefs);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Merged ${entriesToMerge.length} entries.')),
    );
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
        Row(
          children: [
            Expanded(
              child: const Text('Your entries', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            if (_selectionMode) ...[
              if (_selectedEntryIds.length >= 2)
                TextButton.icon(
                  icon: const Icon(Icons.merge),
                  label: Text('Merge (${_selectedEntryIds.length})'),
                  onPressed: _mergeSelectedEntries,
                ),
              TextButton(
                onPressed: _toggleSelectionMode,
                child: const Text('Cancel'),
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: 'Select entries',
                onPressed: _toggleSelectionMode,
              ),
          ],
        ),
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
              final isSelected = _selectedEntryIds.contains(e.id);
              return Card(
                elevation: isSelected ? 4 : 1,
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                    : null,
                child: InkWell(
                  onTap: _selectionMode
                      ? () => _toggleEntrySelection(e.id)
                      : () => _openJournalEntryViewer(e),
                  onLongPress: () {
                    if (!_selectionMode) {
                      setState(() {
                        _selectionMode = true;
                        _selectedEntryIds.add(e.id);
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                _entryTitle(e),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (!_selectionMode)
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
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
                        if (!_selectionMode)
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
                  if (_selectionMode && _selectedEntryIds.length >= 2)
                    TextButton.icon(
                      icon: const Icon(Icons.merge),
                      label: Text('Merge (${_selectedEntryIds.length})'),
                      onPressed: _mergeSelectedEntries,
                    ),
                  if (_selectionMode)
                    TextButton(
                      onPressed: _toggleSelectionMode,
                      child: const Text('Cancel'),
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
  final List<String> imagePaths;

  const _JournalEditorResult({
    required this.deltaJson,
    required this.plainText,
    required this.title,
    required this.tags,
    required this.legacyGoalTitle,
    this.imagePaths = const [],
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
  final List<String> _imagePaths = <String>[];
  final ImagePicker _imagePicker = ImagePicker();
  bool _hasUnsavedChanges = false;
  

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController.basic();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _focused = _focusNode.hasFocus);
    });
    // Track content changes
    _controller.document.changes.listen((event) {
      if (mounted) {
        setState(() => _hasUnsavedChanges = true);
      }
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
  
  /// Public method to save editor content (called from back button handler)
  Future<bool> save() async {
    if (!_hasUnsavedChanges) return true;
    
    final deltaJson = _controller.document.toDelta().toJson();
    final plain = _controller.document.toPlainText().replaceAll('\r', '').trim();
    
    if (plain.isEmpty && _imagePaths.isEmpty) {
      // Allow saving empty if user explicitly wants to
      return true;
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
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final entry = await JournalStorageService.addEntry(
        title: title,
        text: plain,
        delta: deltaJson,
        tags: tagsNorm,
        goalTitle: legacyGoal,
        imagePaths: _imagePaths,
        prefs: prefs,
      );
      
      // Update image paths with actual entry ID
      if (entry != null && _imagePaths.isNotEmpty) {
        final updatedImagePaths = <String>[];
        for (int i = 0; i < _imagePaths.length; i++) {
          final oldPath = _imagePaths[i];
          final oldFile = File(oldPath);
          if (await oldFile.exists()) {
            final newPath = await JournalImageStorageService.saveImage(
              oldFile,
              entry.id,
              i,
            );
            updatedImagePaths.add(newPath);
            await JournalImageStorageService.deleteImage(oldPath);
          }
        }
        
        if (updatedImagePaths.isNotEmpty) {
          final allEntries = await JournalStorageService.loadEntries(prefs: prefs);
          final updatedEntries = allEntries.map((e) {
            if (e.id == entry.id) {
              return JournalEntry(
                id: e.id,
                createdAtMs: e.createdAtMs,
                title: e.title,
                text: e.text,
                delta: e.delta,
                goalTitle: e.goalTitle,
                tags: e.tags,
                imagePaths: updatedImagePaths,
              );
            }
            return e;
          }).toList();
          await JournalStorageService.saveEntries(updatedEntries, prefs: prefs);
        }
      }
      
      _hasUnsavedChanges = false;
      return true;
    } catch (e) {
      return false;
    }
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

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      if (!await file.exists()) return;

      // Generate a temporary entry ID for saving (will be replaced when entry is actually saved)
      final tempEntryId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final savedPath = await JournalImageStorageService.saveImage(
        file,
        tempEntryId,
        _imagePaths.length,
      );

      setState(() {
        _imagePaths.add(savedPath);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteImage(int index) async {
    final path = _imagePaths[index];
    await JournalImageStorageService.deleteImage(path);
    setState(() {
      _imagePaths.removeAt(index);
    });
  }

  void _save() async {
    final deltaJson = _controller.document.toDelta().toJson();
    final plain = _controller.document.toPlainText().replaceAll('\r', '').trim();
    if (plain.isEmpty && _imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something or add an image before saving.')),
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
    _hasUnsavedChanges = false;
    Navigator.of(context).pop(
      _JournalEditorResult(
        deltaJson: deltaJson,
        plainText: plain,
        title: title,
        tags: tagsNorm,
        legacyGoalTitle: legacyGoal,
        imagePaths: _imagePaths,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagsSorted = _tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_hasUnsavedChanges) {
          final saved = await save();
          if (saved && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Write'),
          actions: [
            IconButton(
              tooltip: 'Add Image',
              icon: const Icon(Icons.image_outlined),
              onPressed: _pickImage,
            ),
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
          if (_imagePaths.isNotEmpty)
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _imagePaths.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_imagePaths[index]),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 100,
                                height: 100,
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                child: Icon(
                                  Icons.broken_image,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(24, 24),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _deleteImage(index),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      ),
    );
  }
}

final class _JournalEntryViewerScreen extends StatefulWidget {
  final JournalEntry entry;
  const _JournalEntryViewerScreen({required this.entry});

  @override
  State<_JournalEntryViewerScreen> createState() => _JournalEntryViewerScreenState();
}

class _JournalEntryViewerScreenState extends State<_JournalEntryViewerScreen> {
  bool _isEditMode = false;
  quill.QuillController? _controller;
  late final JournalEntry _originalEntry;

  @override
  void initState() {
    super.initState();
    _originalEntry = widget.entry;
    _loadController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _loadController() {
    final delta = widget.entry.delta;
    if (delta is List && delta.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(delta);
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: !_isEditMode,
        );
      } catch (_) {
        _controller = null;
      }
    }
  }

  Future<void> _save() async {
    if (_controller == null) return;
    
    final deltaJson = _controller!.document.toDelta().toJson();
    final plain = _controller!.document.toPlainText().replaceAll('\r', '').trim();
    
    if (plain.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save empty entry.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final allEntries = await JournalStorageService.loadEntries(prefs: prefs);
    final updatedEntries = allEntries.map((e) {
      if (e.id == widget.entry.id) {
        return JournalEntry(
          id: e.id,
          createdAtMs: e.createdAtMs,
          title: e.title,
          text: plain,
          delta: deltaJson,
          goalTitle: e.goalTitle,
          tags: e.tags,
          imagePaths: e.imagePaths,
        );
      }
      return e;
    }).toList();

    await JournalStorageService.saveEntries(updatedEntries, prefs: prefs);
    
    if (!mounted) return;
    setState(() {
      _isEditMode = false;
      _controller?.readOnly = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry saved.')),
    );
  }

  void _cancel() {
    setState(() {
      _isEditMode = false;
      _loadController();
      _controller?.readOnly = true;
    });
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _loadController();
      _controller?.readOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final plain = _JournalNotesScreenState._entryPlainText(widget.entry);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_JournalNotesScreenState._fmtDateTime(widget.entry.createdAt)),
        actions: _isEditMode
            ? [
                TextButton(
                  onPressed: _cancel,
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: _enterEditMode,
                ),
              ],
      ),
      body: SafeArea(
        child: _controller != null
            ? Column(
                children: [
                  if (_isEditMode)
                    quill.QuillSimpleToolbar(
                      controller: _controller!,
                      config: quill.QuillSimpleToolbarConfig(
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
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                      child: quill.QuillEditor.basic(
                        controller: _controller!,
                        config: quill.QuillEditorConfig(
                          checkBoxReadOnly: !_isEditMode,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  if (widget.entry.imagePaths.isNotEmpty)
                    Container(
                      height: 120,
                      padding: const EdgeInsets.all(12),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.entry.imagePaths.length,
                        itemBuilder: (context, index) {
                          return FutureBuilder<File?>(
                            future: JournalImageStorageService.loadImage(widget.entry.imagePaths[index]),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      snapshot.data!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.broken_image,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              )
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(plain),
                    if (widget.entry.imagePaths.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.entry.imagePaths.length,
                          itemBuilder: (context, index) {
                            return FutureBuilder<File?>(
                              future: JournalImageStorageService.loadImage(widget.entry.imagePaths[index]),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Container(
                                    width: 200,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        snapshot.data!,
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                }
                                return Container(
                                  width: 200,
                                  height: 200,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
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

