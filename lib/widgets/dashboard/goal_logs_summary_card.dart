import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/journal_entry.dart';
import '../../utils/app_typography.dart';
import '../../screens/journal/journal_notes_screen.dart';
import '../../services/journal_book_storage_service.dart';
import '../../services/journal_storage_service.dart';

class GoalLogsSummaryCard extends StatefulWidget {
  const GoalLogsSummaryCard({super.key});

  @override
  State<GoalLogsSummaryCard> createState() => _GoalLogsSummaryCardState();
}

class _GoalLogsSummaryCardState extends State<GoalLogsSummaryCard>
    with WidgetsBindingObserver {
  JournalEntry? _recentEntry;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void activate() {
    super.activate();
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await JournalStorageService.loadEntriesByBook(
      JournalBookStorageService.goalLogsBookId,
      prefs: prefs,
    );
    if (mounted) {
      setState(() {
        _recentEntry = entries.isNotEmpty ? entries.first : null;
        _loaded = true;
      });
    }
  }

  void _openGoalLogs() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: JournalNotesScreen(embedded: false),
        ),
      ),
    );
    _load();
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String _previewText(JournalEntry entry) {
    final text = entry.text.trim();
    if (text.isEmpty) return '';
    final firstLine = text.split('\n').first.trim();
    return firstLine.length > 60 ? '${firstLine.substring(0, 60)}...' : firstLine;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openGoalLogs,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Goal Logs',
                      style: AppTypography.heading3(context).copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.6),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_loaded)
                      SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          backgroundColor:
                              colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                        ),
                      )
                    else if (_recentEntry != null) ...[
                      Text(
                        _recentEntry!.title ?? 'Goal Log',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.heading3(context).copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _previewText(_recentEntry!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(context).copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _relativeTime(_recentEntry!.createdAt),
                        style: AppTypography.caption(context).copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.menu_book_outlined,
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.5),
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No goal logs yet',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
