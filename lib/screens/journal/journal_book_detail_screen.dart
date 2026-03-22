import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/journal_book.dart';
import '../../models/journal_entry.dart';
import '../../services/journal_book_storage_service.dart';
import '../../services/journal_storage_service.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import 'journal_editor_screen.dart';
import 'models/journal_editor_models.dart';

/// Full-page screen displaying all entries for a single journal book.
final class JournalBookDetailScreen extends StatefulWidget {
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

class _JournalBookDetailScreenState extends State<JournalBookDetailScreen> {
  List<JournalEntry> _entries = const [];
  bool _loading = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    _prefs = prefs;

    final all = await JournalStorageService.loadEntries(prefs: prefs);
    if (!mounted) return;

    final isDefault =
        widget.book.id == JournalBookStorageService.defaultBookId;

    final filtered = all.where((e) {
      if (isDefault) {
        return e.bookId == null || e.bookId!.isEmpty;
      }
      return e.bookId == widget.book.id;
    }).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    setState(() {
      _entries = filtered;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  static Widget _pageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    return SlideTransition(position: slide, child: child);
  }

  Future<void> _openNewEntry() async {
    final result = await Navigator.of(context).push<JournalEditorResult>(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secAnim) => JournalEntryEditorScreen(
          goalTitles: widget.goalTitles,
          existingTags: const [],
          bookId: widget.book.id,
        ),
        transitionsBuilder: _pageTransition,
      ),
    );

    if (result != null) {
      await JournalStorageService.addEntry(
        text: result.plainText,
        title: result.title.trim().isEmpty ? null : result.title.trim(),
        delta: result.deltaJson,
        tags: result.tags,
        goalTitle: result.legacyGoalTitle,
        bookId: widget.book.id,
        prefs: _prefs,
      );
    }
    await _loadEntries();
  }

  Future<void> _openExistingEntry(JournalEntry entry) async {
    await Navigator.of(context).push<JournalEditorResult>(
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secAnim) => JournalEntryEditorScreen(
          goalTitles: widget.goalTitles,
          existingTags: entry.tags,
          existingEntry: entry,
          bookId: widget.book.id,
        ),
        transitionsBuilder: _pageTransition,
      ),
    );
    await _loadEntries();
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> _deleteEntry(JournalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusDialog),
        ),
        title: const Text('Delete Entry'),
        content: Text(
          'Are you sure you want to delete "${entry.title ?? 'this entry'}"? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await JournalStorageService.deleteEntry(entry.id, prefs: _prefs);
      await _loadEntries();
    }
  }

  // ---------------------------------------------------------------------------
  // Date formatting
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime dt) => DateFormat('d MMM yyyy').format(dt);

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookColor = Color(
      widget.book.coverColor ?? JournalBook.defaultCoverColor,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context, bookColor),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmptyState(context, isDark)
              : _buildList(context, bookColor),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewEntry,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        tooltip: 'New Entry',
        child: const Icon(Icons.add),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Color bookColor) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      ),
      titleSpacing: AppSpacing.sm,
      title: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: bookColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusBadge),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
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
          onPressed: _openNewEntry,
          child: Text(
            '+ Entry',
            style: AppTypography.secondary(context).copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No entries yet',
              style: AppTypography.heading3(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap "+ Entry" above or the button below to write your first entry.',
              style: AppTypography.secondary(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, Color bookColor) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      itemCount: _entries.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, i) => _buildEntryRow(ctx, _entries[i], bookColor),
    );
  }

  Widget _buildEntryRow(
    BuildContext context,
    JournalEntry entry,
    Color bookColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        ),
        child: Icon(Icons.delete_outline_rounded, color: colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        await _deleteEntry(entry);
        return false;
      },
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
        ),
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        child: InkWell(
          onTap: () => _openExistingEntry(entry),
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored left bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: bookColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppSpacing.radiusInput),
                      bottomLeft: Radius.circular(AppSpacing.radiusInput),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title?.isNotEmpty == true
                              ? entry.title!
                              : 'Untitled',
                          style: AppTypography.body(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _formatDate(entry.createdAt),
                          style: AppTypography.caption(context),
                        ),
                      ],
                    ),
                  ),
                ),
                // Chevron
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
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
