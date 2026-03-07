import 'package:flutter/material.dart';

import '../../models/personal_record.dart';
import '../../services/personal_record_service.dart';

/// Displays personal bests for all exercises in a given workout program,
/// plus a scrollable history of every logged entry.
class PersonalRecordsScreen extends StatefulWidget {
  /// Normalized exercise keys to filter records for this program.
  /// If empty, all records are shown.
  final Set<String> exerciseKeys;
  final String programName;

  const PersonalRecordsScreen({
    super.key,
    required this.exerciseKeys,
    required this.programName,
  });

  @override
  State<PersonalRecordsScreen> createState() => _PersonalRecordsScreenState();
}

class _PersonalRecordsScreenState extends State<PersonalRecordsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, PersonalRecord> _bests = {};
  List<PersonalRecord> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final allBests = await PersonalRecordService.getAllBests();
    final allHistory = await PersonalRecordService.getHistory();

    final filteredBests = widget.exerciseKeys.isEmpty
        ? allBests
        : Map.fromEntries(
            allBests.entries.where((e) => widget.exerciseKeys.contains(e.key)),
          );

    final filteredHistory = widget.exerciseKeys.isEmpty
        ? allHistory
        : allHistory
            .where((r) => widget.exerciseKeys.contains(r.exerciseKey))
            .toList();

    if (mounted) {
      setState(() {
        _bests = filteredBests;
        _history = filteredHistory;
        _loading = false;
      });
    }
  }

  Future<void> _deleteExercise(String exerciseKey) async {
    await PersonalRecordService.deleteExercise(exerciseKey);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Personal Records'),
            Text(
              widget.programName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Bests'),
            Tab(icon: Icon(Icons.history_rounded), text: 'History'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _BestsTab(
                  bests: _bests,
                  onDelete: _deleteExercise,
                ),
                _HistoryTab(history: _history),
              ],
            ),
    );
  }
}

// ── Bests tab ─────────────────────────────────────────────────────────────────

class _BestsTab extends StatelessWidget {
  final Map<String, PersonalRecord> bests;
  final Future<void> Function(String exerciseKey) onDelete;

  const _BestsTab({required this.bests, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (bests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No records yet',
              style: textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the  +  on any exercise to log your first lift.',
              style: textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort by exercise name for consistent ordering.
    final sorted = bests.entries.toList()
      ..sort((a, b) => a.value.exerciseName.compareTo(b.value.exerciseName));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final pr = sorted[i].value;
        return _PRCard(pr: pr, onDelete: () => onDelete(pr.exerciseKey));
      },
    );
  }
}

class _PRCard extends StatelessWidget {
  final PersonalRecord pr;
  final VoidCallback onDelete;

  const _PRCard({required this.pr, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: cs.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pr.exerciseName,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pr.summary,
                    style: textTheme.titleSmall?.copyWith(
                      color: cs.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _formatDate(pr.achievedAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              tooltip: 'Clear records for this exercise',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Records'),
                    content: Text(
                      'Delete all logged lifts for "${pr.exerciseName}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── History tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<PersonalRecord> history;

  const _HistoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (history.isEmpty) {
      return Center(
        child: Text(
          'No history yet.',
          style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final pr = history[i];
        // Show date header when it changes.
        final showHeader = i == 0 ||
            !_sameDay(history[i - 1].achievedAt, pr.achievedAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  _formatDate(pr.achievedAt),
                  style: textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ListTile(
              dense: true,
              leading: Icon(
                Icons.fitness_center_outlined,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              title: Text(
                pr.exerciseName,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Text(
                pr.summary,
                style: textTheme.labelMedium?.copyWith(
                  color: cs.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
