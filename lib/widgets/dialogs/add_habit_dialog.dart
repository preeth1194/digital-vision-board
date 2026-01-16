import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/cbt_enhancements.dart';

final class HabitCreateRequest {
  final String name;
  final String? frequency; // null | 'Daily' | 'Weekly'
  final List<int> weeklyDays; // 1=Mon..7=Sun
  final String? deadline; // YYYY-MM-DD
  final String? afterHabitId;
  final String? timeOfDay; // free-form, e.g. "07:00 AM"
  final int? reminderMinutes;
  final bool reminderEnabled;
  final HabitChaining? chaining;
  final CbtEnhancements? cbtEnhancements;

  const HabitCreateRequest({
    required this.name,
    required this.frequency,
    required this.weeklyDays,
    required this.deadline,
    required this.afterHabitId,
    required this.timeOfDay,
    required this.reminderMinutes,
    required this.reminderEnabled,
    required this.chaining,
    required this.cbtEnhancements,
  });
}

Future<HabitCreateRequest?> showAddHabitDialog(
  BuildContext context, {
  String? initialName,
  String? suggestedGoalDeadline,
  required List<HabitItem> existingHabits,
}) async {
  return showDialog<HabitCreateRequest?>(
    context: context,
    builder: (ctx) => _AddHabitDialog(
      initialName: initialName,
      initialHabit: null,
      suggestedGoalDeadline: suggestedGoalDeadline,
      existingHabits: existingHabits,
    ),
  );
}

Future<HabitCreateRequest?> showEditHabitDialog(
  BuildContext context, {
  required HabitItem habit,
  String? suggestedGoalDeadline,
  required List<HabitItem> existingHabits,
}) async {
  return showDialog<HabitCreateRequest?>(
    context: context,
    builder: (ctx) => _AddHabitDialog(
      initialName: null,
      initialHabit: habit,
      suggestedGoalDeadline: suggestedGoalDeadline,
      existingHabits: existingHabits,
    ),
  );
}

class _AddHabitDialog extends StatefulWidget {
  final String? initialName;
  final HabitItem? initialHabit;
  final String? suggestedGoalDeadline;
  final List<HabitItem> existingHabits;

  const _AddHabitDialog({
    required this.initialName,
    required this.initialHabit,
    required this.suggestedGoalDeadline,
    required this.existingHabits,
  });

  @override
  State<_AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<_AddHabitDialog> {
  final _name = TextEditingController();
  final _timeOfDay = TextEditingController();
  int? _reminderMinutes;
  bool _reminderEnabled = false;
  String? _frequency; // null | Daily | Weekly
  final Set<int> _weeklyDays = <int>{};
  String? _deadline; // YYYY-MM-DD
  bool _useGoalDeadline = false;
  String? _afterHabitId;
  // Don't hold onto the Autocomplete controller across builds; it can be disposed
  // by the Autocomplete internals. Keep a plain string snapshot instead.
  String _anchorHabitText = '';
  String? _anchorHabitInitialText;
  String _relationship = 'Immediately';

  // CBT
  final _microVersion = TextEditingController();
  final _predictedObstacle = TextEditingController();
  final _ifThenPlan = TextEditingController();
  final _reward = TextEditingController();
  double _confidence = 8;

  static const _weekdays = <int, String>{
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  };

  @override
  void initState() {
    super.initState();
    final initialHabit = widget.initialHabit;
    if (initialHabit != null) {
      _name.text = initialHabit.name.trim();
      _timeOfDay.text = (initialHabit.timeOfDay ?? '').trim();
      _reminderMinutes = initialHabit.reminderMinutes;
      _reminderEnabled = initialHabit.reminderEnabled;
      _frequency = (initialHabit.frequency ?? '').trim().isEmpty ? null : initialHabit.frequency;
      _weeklyDays.addAll(initialHabit.weeklyDays);
      _deadline = (initialHabit.deadline ?? '').trim().isEmpty ? null : initialHabit.deadline;
      _afterHabitId = initialHabit.afterHabitId;
      _relationship = (initialHabit.chaining?.relationship ?? '').trim().isEmpty
          ? 'Immediately'
          : initialHabit.chaining!.relationship!.trim();
      _anchorHabitInitialText = (initialHabit.chaining?.anchorHabit ?? '').trim().isEmpty
          ? null
          : initialHabit.chaining!.anchorHabit!.trim();
      _anchorHabitText = _anchorHabitInitialText ?? '';

      final cbt = initialHabit.cbtEnhancements;
      if (cbt != null) {
        _microVersion.text = (cbt.microVersion ?? '').trim();
        _predictedObstacle.text = (cbt.predictedObstacle ?? '').trim();
        _ifThenPlan.text = (cbt.ifThenPlan ?? '').trim();
        _reward.text = (cbt.reward ?? '').trim();
        final cs = cbt.confidenceScore;
        if (cs != null) _confidence = cs.clamp(0, 10).toDouble();
      }
    } else {
      _name.text = (widget.initialName ?? '').trim();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _timeOfDay.dispose();
    _microVersion.dispose();
    _predictedObstacle.dispose();
    _ifThenPlan.dispose();
    _reward.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _deadline = _toIsoDate(picked);
      _useGoalDeadline = false;
    });
  }

  static String _toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static String _formatTime(BuildContext context, TimeOfDay tod) {
    // Localized formatting (12/24h based on device settings).
    return MaterialLocalizations.of(context).formatTimeOfDay(tod);
  }

  static int _toMinutes(TimeOfDay tod) => (tod.hour * 60) + tod.minute;

  Future<void> _pickTimeOfDay() async {
    final initial = _reminderMinutes != null
        ? TimeOfDay(hour: _reminderMinutes! ~/ 60, minute: _reminderMinutes! % 60)
        : TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    if (!mounted) return;
    final label = _formatTime(context, picked);
    final minutes = _toMinutes(picked);

    setState(() {
      _timeOfDay.text = label;
      _reminderMinutes = minutes;
    });

    final enable = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Set reminder?'),
            content: Text('Set an alarm/reminder at $label for this habit?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not now')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Enable')),
            ],
          ),
        ) ??
        false;
    if (!mounted) return;
    setState(() => _reminderEnabled = enable);
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    String? freqNorm = (_frequency ?? '').trim();
    freqNorm = freqNorm.isEmpty ? null : freqNorm;
    List<int> weeklyDays = (_frequency == 'Weekly') ? (_weeklyDays.toList()..sort()) : const <int>[];

    // Weekly + all days == Daily
    if (freqNorm == 'Weekly' && _weeklyDays.length >= 7) {
      freqNorm = 'Daily';
      weeklyDays = const <int>[];
    }

    final selectedAnchorName = widget.existingHabits
        .where((h) => h.id == _afterHabitId)
        .map((h) => h.name)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    final anchorText = _anchorHabitText.trim().isNotEmpty
        ? _anchorHabitText.trim()
        : (selectedAnchorName?.trim().isNotEmpty == true ? selectedAnchorName!.trim() : null);
    final relationship = _relationship.trim().isEmpty ? null : _relationship.trim();
    final chaining = (anchorText == null && relationship == null)
        ? null
        : HabitChaining(anchorHabit: anchorText, relationship: relationship);

    final cbt = CbtEnhancements(
      microVersion: _microVersion.text.trim().isEmpty ? null : _microVersion.text.trim(),
      predictedObstacle: _predictedObstacle.text.trim().isEmpty ? null : _predictedObstacle.text.trim(),
      ifThenPlan: _ifThenPlan.text.trim().isEmpty ? null : _ifThenPlan.text.trim(),
      confidenceScore: _confidence.round(),
      reward: _reward.text.trim().isEmpty ? null : _reward.text.trim(),
    );
    final hasCbt = (cbt.microVersion ?? '').isNotEmpty ||
        (cbt.predictedObstacle ?? '').isNotEmpty ||
        (cbt.ifThenPlan ?? '').isNotEmpty ||
        (cbt.reward ?? '').isNotEmpty;

    Navigator.of(context).pop(
      HabitCreateRequest(
        name: name,
        frequency: freqNorm,
        weeklyDays: weeklyDays,
        deadline: _deadline?.trim().isEmpty == true ? null : _deadline,
        afterHabitId: _afterHabitId,
        timeOfDay: _timeOfDay.text.trim().isEmpty ? null : _timeOfDay.text.trim(),
        reminderMinutes: _reminderMinutes,
        reminderEnabled: _reminderEnabled,
        chaining: chaining,
        cbtEnhancements: hasCbt ? cbt : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 600;
    final insetBottom = MediaQuery.viewInsetsOf(context).bottom;
    final goalDeadline = (widget.suggestedGoalDeadline ?? '').trim();
    final canUseGoalDeadline = goalDeadline.isNotEmpty;
    final anchorSuggestions = widget.existingHabits
        .map((h) => h.name.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final dialogContent = DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initialHabit == null ? 'Add habit' : 'Edit habit',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'CBT plan'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                    // Tab 1: What
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _name,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _timeOfDay,
                            readOnly: true,
                            onTap: _pickTimeOfDay,
                            decoration: InputDecoration(
                              labelText: 'Time (optional)',
                              hintText: 'Pick a time',
                              border: const OutlineInputBorder(),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if ((_timeOfDay.text).trim().isNotEmpty)
                                    IconButton(
                                      tooltip: 'Clear time',
                                      onPressed: () => setState(() {
                                        _timeOfDay.text = '';
                                        _reminderMinutes = null;
                                        _reminderEnabled = false;
                                      }),
                                      icon: const Icon(Icons.clear),
                                    ),
                                  IconButton(
                                    tooltip: 'Pick time',
                                    onPressed: _pickTimeOfDay,
                                    icon: const Icon(Icons.access_time),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if ((_timeOfDay.text).trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable reminder'),
                              subtitle: const Text('Send a notification at the selected time'),
                              value: _reminderEnabled,
                              onChanged: (v) => setState(() => _reminderEnabled = v),
                            ),
                          ],
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: _frequency,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Frequency (optional)')),
                              DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                              DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _frequency = v;
                                if (_frequency != 'Weekly') _weeklyDays.clear();
                                if (_frequency == 'Weekly' && _weeklyDays.isEmpty) {
                                  _weeklyDays.add(DateTime.now().weekday);
                                }
                                if (_frequency == 'Weekly' && _weeklyDays.length >= 7) {
                                  _frequency = 'Daily';
                                  _weeklyDays.clear();
                                }
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_frequency == 'Weekly') ...[
                            const SizedBox(height: 10),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Weekly days', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _weekdays.entries.map((e) {
                                final selected = _weeklyDays.contains(e.key);
                                return FilterChip(
                                  label: Text(e.value),
                                  selected: selected,
                                  onSelected: (v) {
                                    setState(() {
                                      if (v) {
                                        _weeklyDays.add(e.key);
                                      } else {
                                        _weeklyDays.remove(e.key);
                                      }
                                      // Weekly + all days collapses to Daily.
                                      if (_weeklyDays.length >= 7) {
                                        _frequency = 'Daily';
                                        _weeklyDays.clear();
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: _afterHabitId,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Anchor habit (optional)')),
                              ...widget.existingHabits.map(
                                (h) => DropdownMenuItem(value: h.id, child: Text(h.name)),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() {
                                _afterHabitId = v;
                                final selected = widget.existingHabits.where((h) => h.id == v).toList();
                                if (selected.isNotEmpty) {
                                  _anchorHabitText = selected.first.name;
                                }
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Chaining: pick anchor habit',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue t) {
                              final q = t.text.trim().toLowerCase();
                              if (anchorSuggestions.isEmpty) return const Iterable<String>.empty();
                              if (q.isEmpty) return anchorSuggestions;
                              return anchorSuggestions.where((s) => s.toLowerCase().contains(q));
                            },
                            onSelected: (v) {
                              _anchorHabitText = v;
                            },
                            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                              if ((_anchorHabitInitialText ?? '').trim().isNotEmpty &&
                                  textController.text.trim().isEmpty &&
                                  _anchorHabitText.trim().isEmpty) {
                                _anchorHabitText = _anchorHabitInitialText!;
                                textController.text = _anchorHabitText;
                              } else if (_anchorHabitText.trim().isNotEmpty &&
                                  textController.text != _anchorHabitText) {
                                // Keep the field in sync with our snapshot when changed externally.
                                textController.text = _anchorHabitText;
                              }
                              return TextField(
                                controller: textController,
                                focusNode: focusNode,
                                onChanged: (v) => _anchorHabitText = v,
                                decoration: const InputDecoration(
                                  labelText: 'Chaining: anchor habit (type or pick)',
                                  border: OutlineInputBorder(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _relationship,
                            items: const [
                              DropdownMenuItem(value: 'Immediately', child: Text('Immediately')),
                              DropdownMenuItem(value: 'After', child: Text('After')),
                              DropdownMenuItem(value: 'Before', child: Text('Before')),
                            ],
                            onChanged: (v) => setState(() => _relationship = v ?? 'Immediately'),
                            decoration: const InputDecoration(
                              labelText: 'Chaining relationship',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickDeadline,
                                  icon: const Icon(Icons.event_outlined),
                                  label: Text(_deadline == null ? 'Due date (optional)' : 'Due $_deadline'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Clear due date',
                                onPressed: _deadline == null
                                    ? null
                                    : () => setState(() {
                                          _deadline = null;
                                          _useGoalDeadline = false;
                                        }),
                                icon: const Icon(Icons.clear),
                              ),
                            ],
                          ),
                          if (canUseGoalDeadline) ...[
                            const SizedBox(height: 6),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('Use goal deadline ($goalDeadline)'),
                              value: _useGoalDeadline,
                              onChanged: (v) {
                                setState(() {
                                  _useGoalDeadline = v;
                                  _deadline = v ? goalDeadline : _deadline;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Tab 2: CBT
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _microVersion,
                            decoration: const InputDecoration(
                              labelText: 'Micro version',
                              hintText: 'e.g., Do just 5 minutes',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _predictedObstacle,
                            decoration: const InputDecoration(
                              labelText: 'Predicted obstacle',
                              hintText: 'e.g., Waking up late',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _ifThenPlan,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'If-Then plan',
                              hintText: 'If X happens, then I will do Y…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Confidence: ${_confidence.round()}/10',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Slider(
                            value: _confidence,
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: _confidence.round().toString(),
                            onChanged: (v) => setState(() => _confidence = v),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _reward,
                            decoration: const InputDecoration(
                              labelText: 'Reward',
                              hintText: 'e.g., Listen to a favorite song',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(widget.initialHabit == null ? 'Add' : 'Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            // Don't apply extra bottom padding here; Scaffold already resizes for the keyboard.
            child: dialogContent,
          ),
        ),
      );
    }

    final height = (size.height * 0.85).clamp(520.0, 760.0);
    return Dialog(
      child: AnimatedPadding(
        padding: EdgeInsets.only(bottom: insetBottom),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: SizedBox(
          width: 560,
          height: height,
          child: dialogContent,
        ),
      ),
    );
  }
}

