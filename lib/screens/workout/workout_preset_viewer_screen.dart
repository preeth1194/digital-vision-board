import 'package:flutter/material.dart';

import '../../models/action_step_template.dart';
import '../../models/habit_action_step.dart';

/// Full-screen workout plan viewer.
///
/// Shows the full program schedule grouped by workout day, with per-exercise
/// sets, reps, rest, and technique notes. Sourced from Muscle & Strength.
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

  @override
  void initState() {
    super.initState();
    _byDay = _groupByDay(widget.template.steps);
    _dayOrder = _byDay.keys.toList();
    // Expand first day by default.
    if (_dayOrder.isNotEmpty) _expanded.add(_dayOrder.first);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final template = widget.template;

    return Scaffold(
      backgroundColor: cs.surface,
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
                  const SizedBox(width: 6),
                  Text(
                    'PLAN PREVIEW',
                    style: textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 6),
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
            separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
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
                              const SizedBox(width: 10),
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
                            ? _ExerciseTable(exercises: exercises)
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
                        fontSize: 11,
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
          // Stats row
          Row(
            children: [
              _StatChip(label: 'Level', value: meta('level')),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Duration',
                value: '${meta('durationWeeks')} wks',
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Days/wk',
                value: meta('daysPerWeek'),
              ),
              const SizedBox(width: 8),
              _StatChip(label: 'Session', value: meta('timePerSession')),
            ],
          ),
          const SizedBox(height: 8),
          // Split
          Text(
            meta('split'),
            style: textTheme.bodySmall?.copyWith(
              color: cs.onInverseSurface.withValues(alpha: 0.65),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Equipment chips
          if (equipment.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final eq in equipment)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
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
          // Technique note
          if (techniqueNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              techniqueNote,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onInverseSurface.withValues(alpha: 0.5),
                fontSize: 10,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.onInverseSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: cs.onInverseSurface.withValues(alpha: 0.5),
                fontSize: 9,
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

  const _ExerciseTable({required this.exercises});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
            ],
          ),
        ),

        // Exercise rows
        for (int i = 0; i < exercises.length; i++) ...[
          _ExerciseRow(
            exercise: exercises[i],
            index: i,
            isEven: i.isEven,
          ),
        ],

        const SizedBox(height: 4),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final HabitActionStep exercise;
  final int index;
  final bool isEven;

  const _ExerciseRow({
    required this.exercise,
    required this.index,
    required this.isEven,
  });

  /// Extract rest from notes: "Rest: 90 sec — some note" → "90 sec"
  String _extractRest(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final match = RegExp(r'Rest:\s*([^—\n]+)').firstMatch(raw);
    return match?.group(1)?.trim() ?? '—';
  }

  /// Extract technique note (everything after the dash separator).
  String _extractNote(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dashIdx = raw.indexOf(' — ');
    if (dashIdx == -1) {
      // No dash — return everything if it doesn't start with "Rest:"
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise name + sub-details
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
                          fontSize: 9,
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
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
                        fontSize: 10,
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
                        fontSize: 10,
                        color: cs.tertiary,
                        fontStyle: FontStyle.italic,
                      ),
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
                fontSize: 11,
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
                fontSize: 10,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
