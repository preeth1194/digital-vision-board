import 'package:flutter/material.dart';

import '../../models/action_step_template.dart';
import '../../models/habit_action_step.dart';
import '../../models/personal_record.dart';
import '../../screens/subscription_screen.dart';
import '../../services/personal_record_service.dart';
import '../../services/subscription_service.dart';
import 'personal_records_screen.dart';

/// Full-screen workout plan viewer with personal-record tracking.
///
/// Premium users can log weight + reps per exercise. The best lift
/// (personal record) is shown inline on each exercise row and the full
/// history is accessible via the FAB.
class WorkoutPresetViewerScreen extends StatefulWidget {
  final ActionStepTemplate template;

  const WorkoutPresetViewerScreen({super.key, required this.template});

  @override
  State<WorkoutPresetViewerScreen> createState() =>
      _WorkoutPresetViewerScreenState();
}

class _WorkoutPresetViewerScreenState
    extends State<WorkoutPresetViewerScreen> {
  late final Map<String, List<HabitActionStep>> _byDay;
  late final List<String> _dayOrder;
  final Set<String> _expanded = {};

  /// exerciseKey → current personal best (reloaded after each log).
  Map<String, PersonalRecord> _bests = {};

  @override
  void initState() {
    super.initState();
    _byDay = _groupByDay(widget.template.steps);
    _dayOrder = _byDay.keys.toList();
    if (_dayOrder.isNotEmpty) _expanded.add(_dayOrder.first);
    _loadBests();
  }

  Future<void> _loadBests() async {
    final bests = await PersonalRecordService.getAllBests();
    if (mounted) setState(() => _bests = bests);
  }

  Map<String, List<HabitActionStep>> _groupByDay(
    List<HabitActionStep> steps,
  ) {
    final result = <String, List<HabitActionStep>>{};
    for (final step in steps) {
      final key = (step.plannerDay ?? '').trim();
      final bucket = key.isEmpty ? 'General' : key;
      result.putIfAbsent(bucket, () => []).add(step);
    }
    return result;
  }

  String _meta(String key, {String fallback = '—'}) {
    final v = widget.template.metadata[key];
    if (v == null) return fallback;
    return v.toString();
  }

  List<String> _metaList(String key) {
    final v = widget.template.metadata[key];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  Future<void> _openLogSheet(HabitActionStep exercise) async {
    final isSubscribed = SubscriptionService.isSubscribed.value;
    if (!isSubscribed) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const SubscriptionScreen(),
        ),
      );
      return;
    }

    final key = PersonalRecord.normalizeKey(exercise.title);
    final current = _bests[key];

    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogPRSheet(exercise: exercise, currentBest: current),
    );

    if (saved == true) await _loadBests();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final template = widget.template;

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: SubscriptionService.isSubscribed,
        builder: (context, isSubscribed, _) {
          return FloatingActionButton.extended(
            onPressed: isSubscribed
                ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PersonalRecordsScreen(
                          exerciseKeys: widget.template.steps
                              .map((s) => PersonalRecord.normalizeKey(s.title))
                              .toSet(),
                          programName: template.name,
                        ),
                      ),
                    )
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    ),
            icon: isSubscribed
                ? const Icon(Icons.emoji_events_outlined)
                : const Icon(Icons.lock_outline_rounded),
            label: Text(isSubscribed ? 'My PRs' : 'Unlock PRs'),
            backgroundColor: isSubscribed ? cs.primaryContainer : cs.surfaceContainerHighest,
            foregroundColor: isSubscribed ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          );
        },
      ),
      body: CustomScrollView(
        slivers: [
          // ── Programme header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: cs.inverseSurface,
            foregroundColor: cs.onInverseSurface,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProgramHeader(
                template: template,
                meta: _meta,
                metaList: _metaList,
              ),
            ),
            title: Text(
              template.name,
              style: textTheme.titleMedium?.copyWith(
                color: cs.onInverseSurface,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Plan preview label ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PLAN PREVIEW',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '·  ${_dayOrder.length} workout${_dayOrder.length == 1 ? '' : 's'}  ·  '
                    '${widget.template.steps.length} exercises',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Workout day accordion ─────────────────────────────────────────
          SliverList.separated(
            itemCount: _dayOrder.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final day = _dayOrder[index];
              final exercises = _byDay[day]!;
              final isOpen = _expanded.contains(day);
              final totalSets = exercises.fold<int>(
                0,
                (acc, ex) =>
                    acc +
                    (int.tryParse(
                          (ex.stepLabel ?? '').split('×').first.trim(),
                        ) ??
                        0),
              );

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header row
                      InkWell(
                        onTap: () => setState(() {
                          if (isOpen) {
                            _expanded.remove(day);
                          } else {
                            _expanded.add(day);
                          }
                        }),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      day,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${exercises.length} exercises'
                                      '${totalSets > 0 ? '  ·  $totalSets total sets' : ''}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedRotation(
                                turns: isOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Exercise table
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: isOpen
                            ? _ExerciseTable(
                                exercises: exercises,
                                bests: _bests,
                                onLogTap: _openLogSheet,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Source attribution ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Source: muscleandstrength.com',
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Programme header widget ───────────────────────────────────────────────────

class _ProgramHeader extends StatelessWidget {
  final ActionStepTemplate template;
  final String Function(String key, {String fallback}) meta;
  final List<String> Function(String key) metaList;

  const _ProgramHeader({
    required this.template,
    required this.meta,
    required this.metaList,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final equipment = metaList('equipment');
    final techniqueNote = meta('note', fallback: '');

    return Container(
      color: cs.inverseSurface,
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatChip(label: 'Level', value: meta('level')),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Duration',
                value: '${meta('durationWeeks')} wks',
              ),
              const SizedBox(width: 8),
              _StatChip(label: 'Days/wk', value: meta('daysPerWeek')),
              const SizedBox(width: 8),
              _StatChip(label: 'Session', value: meta('timePerSession')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            meta('split'),
            style: textTheme.bodySmall?.copyWith(
              color: cs.onInverseSurface.withValues(alpha: 0.65),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (equipment.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final eq in equipment)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: cs.onInverseSurface.withValues(alpha: 0.25),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          eq,
                          style: textTheme.labelSmall?.copyWith(
                            color: cs.onInverseSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (techniqueNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              techniqueNote,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onInverseSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: cs.onInverseSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: cs.onInverseSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: textTheme.labelMedium?.copyWith(
                color: cs.onInverseSurface,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exercise table ────────────────────────────────────────────────────────────

class _ExerciseTable extends StatelessWidget {
  final List<HabitActionStep> exercises;
  final Map<String, PersonalRecord> bests;
  final void Function(HabitActionStep) onLogTap;

  const _ExerciseTable({
    required this.exercises,
    required this.bests,
    required this.onLogTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'Exercise',
                  style: textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  'Sets × Reps',
                  style: textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  'Rest',
                  style: textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Log column header
              const SizedBox(width: 36),
            ],
          ),
        ),

        for (int i = 0; i < exercises.length; i++)
          _ExerciseRow(
            exercise: exercises[i],
            index: i,
            isEven: i.isEven,
            best: bests[PersonalRecord.normalizeKey(exercises[i].title)],
            onLogTap: () => onLogTap(exercises[i]),
          ),

        const SizedBox(height: 4),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final HabitActionStep exercise;
  final int index;
  final bool isEven;
  final PersonalRecord? best;
  final VoidCallback onLogTap;

  const _ExerciseRow({
    required this.exercise,
    required this.index,
    required this.isEven,
    required this.best,
    required this.onLogTap,
  });

  String _extractRest(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final match = RegExp(r'Rest:\s*([^—\n]+)').firstMatch(raw);
    return match?.group(1)?.trim() ?? '—';
  }

  String _extractNote(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dashIdx = raw.indexOf(' — ');
    if (dashIdx == -1) {
      if (raw.startsWith('Rest:')) return '';
      return raw;
    }
    return raw.substring(dashIdx + 3).trim();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final note = _extractNote(exercise.notes);
    final rest = _extractRest(exercise.notes);
    final muscle = exercise.productType ?? '';
    final equipment = exercise.productName ?? '';

    return Container(
      color: isEven
          ? Colors.transparent
          : cs.surfaceContainerHighest.withValues(alpha: 0.2),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise name + sub-details + PR badge
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: cs.primary.withValues(alpha: 0.12),
                      child: Text(
                        '${index + 1}',
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exercise.title,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (muscle.isNotEmpty || equipment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 1),
                    child: Text(
                      [muscle, equipment]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 2),
                    child: Text(
                      note,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: cs.tertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                // Current PR badge
                if (best != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 11,
                          color: cs.tertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'PR  ${best!.summary}',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            color: cs.tertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Sets × Reps
          SizedBox(
            width: 64,
            child: Text(
              exercise.stepLabel ?? '—',
              style: textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Rest
          SizedBox(
            width: 52,
            child: Text(
              rest,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Log button
          SizedBox(
            width: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: onLogTap,
              tooltip: 'Log lift',
              icon: Icon(
                best != null
                    ? Icons.add_circle_rounded
                    : Icons.add_circle_outline_rounded,
                size: 20,
                color: best != null ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Log PR bottom sheet ───────────────────────────────────────────────────────

class _LogPRSheet extends StatefulWidget {
  final HabitActionStep exercise;
  final PersonalRecord? currentBest;

  const _LogPRSheet({required this.exercise, this.currentBest});

  @override
  State<_LogPRSheet> createState() => _LogPRSheetState();
}

class _LogPRSheetState extends State<_LogPRSheet> {
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();
  String _unit = 'kg';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current PR values as a starting point.
    if (widget.currentBest != null) {
      final pr = widget.currentBest!;
      _unit = pr.unit;
      _weightCtrl.text = pr.weight == pr.weight.truncateToDouble()
          ? pr.weight.toInt().toString()
          : pr.weight.toStringAsFixed(1);
      _repsCtrl.text = pr.reps.toString();
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weightRaw = double.tryParse(_weightCtrl.text.trim());
    final repsRaw = int.tryParse(_repsCtrl.text.trim());
    if (weightRaw == null || weightRaw <= 0) {
      _showError('Enter a valid weight.');
      return;
    }
    if (repsRaw == null || repsRaw <= 0) {
      _showError('Enter a valid rep count.');
      return;
    }

    setState(() => _saving = true);
    final record = PersonalRecord(
      exerciseKey: PersonalRecord.normalizeKey(widget.exercise.title),
      exerciseName: widget.exercise.title,
      weight: weightRaw,
      unit: _unit,
      reps: repsRaw,
      achievedAt: DateTime.now(),
    );
    final isNewPR = await PersonalRecordService.saveRecord(record);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true); // true = data changed

    // Celebratory snack if it's a new personal best.
    if (isNewPR) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'New Personal Record!  ${record.summary}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged  ${record.summary}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Icon(Icons.fitness_center_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.exercise.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Muscle / equipment sub-label
            if ((widget.exercise.productType ?? '').isNotEmpty ||
                (widget.exercise.productName ?? '').isNotEmpty)
              Text(
                [
                  widget.exercise.productType ?? '',
                  widget.exercise.productName ?? '',
                ].where((s) => s.isNotEmpty).join(' · '),
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),

            const SizedBox(height: 16),

            // Current PR row
            if (widget.currentBest != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 16,
                      color: cs.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current PR',
                      style: textTheme.labelMedium?.copyWith(
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.currentBest!.summary,
                      style: textTheme.labelLarge?.copyWith(
                        color: cs.tertiary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Weight + unit row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Weight',
                      hintText: '0.0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    autofocus: widget.currentBest == null,
                  ),
                ),
                const SizedBox(width: 12),
                // Unit toggle
                ToggleButtons(
                  isSelected: [_unit == 'kg', _unit == 'lb'],
                  onPressed: (i) =>
                      setState(() => _unit = i == 0 ? 'kg' : 'lb'),
                  borderRadius: BorderRadius.circular(12),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('kg'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('lb'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Reps
            TextField(
              controller: _repsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Reps',
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Lift'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
