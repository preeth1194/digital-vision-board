import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/core_value.dart';
import '../../models/habit_item.dart';
import '../../models/goal_metadata.dart';
import '../../models/wizard/wizard_core_value_catalog.dart';
import '../../models/wizard/wizard_goal.dart';
import '../../models/wizard/wizard_state.dart';
import '../../services/wizard_defaults_service.dart';
import '../../widgets/dialogs/add_habit_dialog.dart';

class WizardStep1BoardSetup extends StatefulWidget {
  final CreateBoardWizardState initial;
  final ValueChanged<CreateBoardWizardState> onNext;

  const WizardStep1BoardSetup({
    super.key,
    required this.initial,
    required this.onNext,
  });

  @override
  State<WizardStep1BoardSetup> createState() => _WizardStep1BoardSetupState();
}

class _WizardStep1BoardSetupState extends State<WizardStep1BoardSetup> {
  late final TextEditingController _nameC;
  late String _majorCoreValueId;
  late final Set<String> _selectedCoreValueIds;
  late Map<String, List<String>> _categoriesByCore;
  late Map<String, Set<String>> _selectedCategoriesByCore;
  List<WizardCoreValueDef> _coreValues = const [];
  Map<String, List<String>> _defaultCategoriesByCore = const {};

  // Goals state (merged from step 2)
  List<WizardGoalDraft> _goals = [];
  List<String> _reviewedGoalIds = [];

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.initial.boardName);
    _majorCoreValueId = widget.initial.majorCoreValueId;
    _selectedCoreValueIds = {
      for (final cv in widget.initial.coreValues) cv.coreValueId,
    };
    if (_selectedCoreValueIds.isEmpty) _selectedCoreValueIds.add(_majorCoreValueId);
    _selectedCoreValueIds.add(_majorCoreValueId);

    final fallback = WizardDefaultsService.getDefaults();
    _coreValues = CoreValues.all.map((c) => WizardCoreValueDef(id: c.id, label: c.label)).toList();
    _defaultCategoriesByCore = {
      for (final cv in CoreValues.all) cv.id: WizardCoreValueCatalog.defaultsFor(cv.id),
    };

    _categoriesByCore = {
      for (final id in _selectedCoreValueIds)
        id: [
          ...(_defaultCategoriesByCore[id] ?? WizardCoreValueCatalog.defaultsFor(id)),
          ...widget.initial.categoriesFor(id),
        ]..toSet().toList(),
    };

    _selectedCategoriesByCore = {
      for (final id in _selectedCoreValueIds) id: <String>{},
    };

    _goals = List<WizardGoalDraft>.from(widget.initial.goals);
    _reviewedGoalIds = List<String>.from(widget.initial.reviewedGoalIds);

    unawaited(_loadDefaults(fallback));
  }

  Future<void> _loadDefaults(Future<WizardDefaultsPayload> fut) async {
    final loaded = await fut;
    if (!mounted) return;
    setState(() {
      _coreValues = loaded.coreValues;
      _defaultCategoriesByCore = loaded.categoriesByCoreValueId;
      for (final id in _selectedCoreValueIds) {
        final existing = _categoriesByCore[id] ?? <String>[];
        final merged = {
          ...existing,
          ...(_defaultCategoriesByCore[id] ?? const <String>[]),
        }.toList()
          ..sort();
        _categoriesByCore[id] = merged;
      }
    });
  }

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  // ─── Board setup helpers ───────────────────────────────────────

  Future<void> _addCategory(String coreValueId) async {
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Add category'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              hintText: 'Category name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    final next = (v ?? '').trim();
    if (next.isEmpty) return;
    setState(() {
      final existing = _categoriesByCore[coreValueId] ?? <String>[];
      final merged = {...existing, next}.toList()..sort();
      _categoriesByCore[coreValueId] = merged;
      _selectedCategoriesByCore[coreValueId] = {
        ...(_selectedCategoriesByCore[coreValueId] ?? <String>{}),
        next,
      };
    });
  }

  void _toggleCoreValue(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedCoreValueIds.add(id);
        _categoriesByCore[id] = {
          ...(_categoriesByCore[id] ?? const <String>[]),
          ...(_defaultCategoriesByCore[id] ?? WizardCoreValueCatalog.defaultsFor(id)),
        }.toList()
          ..sort();
        _selectedCategoriesByCore[id] = _selectedCategoriesByCore[id] ?? <String>{};
      } else {
        if (id == _majorCoreValueId) return;
        _selectedCoreValueIds.remove(id);
        _categoriesByCore.remove(id);
        _selectedCategoriesByCore.remove(id);
        _goals.removeWhere((g) => g.coreValueId == id);
      }
    });
  }

  void _setMajorCoreValue(String id) {
    setState(() {
      _majorCoreValueId = id;
      _selectedCoreValueIds.add(id);
      _categoriesByCore[id] = {
        ...(_categoriesByCore[id] ?? const <String>[]),
        ...(_defaultCategoriesByCore[id] ?? WizardCoreValueCatalog.defaultsFor(id)),
      }.toList()
        ..sort();
      _selectedCategoriesByCore[id] = _selectedCategoriesByCore[id] ?? <String>{};
    });
  }

  void _toggleCategory(String coreValueId, String category, bool selected) {
    setState(() {
      final current = _selectedCategoriesByCore[coreValueId] ?? <String>{};
      final next = <String>{...current};
      if (selected) {
        next.add(category);
      } else {
        next.remove(category);
      }
      _selectedCategoriesByCore[coreValueId] = next;
    });
  }

  bool _step1CategoriesValid() {
    for (final id in _selectedCoreValueIds) {
      final selected = _selectedCategoriesByCore[id] ?? <String>{};
      if (selected.isEmpty) return false;
    }
    return true;
  }

  // ─── Goals helpers (merged from step 2) ────────────────────────

  List<String> _categoriesForCore(String coreValueId) {
    return (_selectedCategoriesByCore[coreValueId] ?? <String>{}).toList()..sort();
  }

  List<WizardGoalDraft> _goalsForCore(String coreValueId) {
    return _goals.where((g) => g.coreValueId == coreValueId).toList();
  }

  void _markGoalReviewed(String goalId) {
    final id = goalId.trim();
    if (id.isEmpty) return;
    if (_reviewedGoalIds.contains(id)) return;
    setState(() => _reviewedGoalIds = [..._reviewedGoalIds, id]);
  }

  Future<String?> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
      initialDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return null;
    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  Future<void> _addOrEditGoal(String coreValueId, {WizardGoalDraft? existing, WizardGoalDraft? prefill}) async {
    final isEdit = existing != null;
    final seed = existing ?? prefill;
    if (existing != null) _markGoalReviewed(existing.id);
    final nameC = TextEditingController(text: seed?.name ?? '');
    final whyC = TextEditingController(text: seed?.whyImportant ?? '');
    String category = (seed?.category ?? '');
    final categories = _categoriesForCore(coreValueId);
    if (category.trim().isEmpty && categories.isNotEmpty) category = categories.first;
    String? deadline = seed?.deadline;
    bool wantsActionPlan = seed?.wantsActionPlan ?? false;
    List<_WizardTodoDraft> todoItems = _WizardTodoDraft.fromSeed(seed);

    final res = await showModalBottomSheet<WizardGoalDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEdit ? 'Edit goal' : 'Add goal',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameC,
                        decoration: const InputDecoration(
                          labelText: 'Goal name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category.isEmpty ? null : category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final c in categories) DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setLocal(() => category = v ?? category),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: whyC,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Why is this important to you?',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event_outlined),
                        label: Text(deadline == null ? 'Add deadline (optional)' : 'Deadline: $deadline'),
                        onPressed: () async {
                          final d = await _pickDeadline();
                          setLocal(() => deadline = d);
                        },
                      ),
                      if (deadline != null)
                        TextButton(
                          onPressed: () => setLocal(() => deadline = null),
                          child: const Text('Clear deadline'),
                        ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: wantsActionPlan,
                        onChanged: (v) => setLocal(() => wantsActionPlan = v),
                        title: const Text('Create todo list'),
                        subtitle: const Text(
                          'Add an ordered list of items, then optionally turn each into a habit and/or task.',
                        ),
                      ),
                      if (wantsActionPlan) ...[
                        const SizedBox(height: 8),
                        _WizardTodoListEditor(
                          todos: todoItems,
                          onChanged: (next) => setLocal(() => todoItems = next),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () {
                          final nm = nameC.text.trim();
                          final wi = whyC.text.trim();
                          if (nm.isEmpty) return;
                          final cat = category.trim();
                          if (cat.isEmpty) return;
                          final habits =
                              wantsActionPlan ? _WizardTodoDraft.habitsFrom(todoItems) : const <HabitItem>[];
                          final todoPersisted =
                              wantsActionPlan ? _WizardTodoDraft.todoItemsFrom(todoItems) : const <GoalTodoItem>[];
                          Navigator.of(ctx).pop(
                            WizardGoalDraft(
                              id: existing?.id ?? 'goal_${DateTime.now().millisecondsSinceEpoch}',
                              coreValueId: coreValueId,
                              name: nm,
                              category: cat,
                              whyImportant: wi,
                              deadline: deadline,
                              wantsActionPlan: wantsActionPlan,
                              habits: habits,
                              tasks: const [],
                              todoItems: todoPersisted,
                            ),
                          );
                        },
                        child: Text(isEdit ? 'Save goal' : 'Add goal'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (res == null) return;
    final nextGoals = List<WizardGoalDraft>.from(_goals);
    nextGoals.removeWhere((g) => g.id == res.id);
    nextGoals.add(res);
    nextGoals.sort((a, b) => a.id.compareTo(b.id));
    setState(() => _goals = nextGoals);
    _markGoalReviewed(res.id);
  }

  void _removeGoal(WizardGoalDraft g) {
    setState(() => _goals = _goals.where((x) => x.id != g.id).toList());
  }

  // ─── Combined validation & submit ──────────────────────────────

  void _next() {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a board name.')),
      );
      return;
    }
    final major = CoreValues.byId(_majorCoreValueId).id;
    if (major.isEmpty) return;

    if (!_step1CategoriesValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 1 category for each selected core value.')),
      );
      return;
    }

    // Validate goals for every selected core value
    for (final cvId in _selectedCoreValueIds) {
      final goals = _goalsForCore(cvId);
      if (goals.isEmpty) {
        final label = CoreValues.byId(cvId).label;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Add at least 1 goal for "$label".')),
        );
        return;
      }
      final reviewed = _reviewedGoalIds.toSet();
      final unreviewed = goals.where((g) => !reviewed.contains(g.id)).toList();
      if (unreviewed.isNotEmpty) {
        final names = unreviewed.map((g) => g.name.trim()).where((s) => s.isNotEmpty).take(3).toList();
        final suffix = (unreviewed.length > 3) ? '…' : '';
        final hint = names.isEmpty ? '' : ' (${names.join(', ')}$suffix)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review each goal (tap to open) before continuing. Remaining: ${unreviewed.length}$hint'),
          ),
        );
        return;
      }
    }

    final ids = {..._selectedCoreValueIds, major}.toList();
    final selections = <WizardCoreValueSelection>[];
    for (final id in ids) {
      final cats = (_selectedCategoriesByCore[id] ?? <String>{})
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      selections.add(WizardCoreValueSelection(coreValueId: id, categories: cats));
    }

    widget.onNext(
      widget.initial.copyWith(
        boardName: name,
        majorCoreValueId: major,
        coreValues: selections,
        goals: _goals,
        reviewedGoalIds: _reviewedGoalIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _nameC.text.trim().isNotEmpty;
    final coreValueDefs = _coreValues.isNotEmpty
        ? _coreValues
        : CoreValues.all.map((c) => WizardCoreValueDef(id: c.id, label: c.label)).toList();
    final muted = CupertinoColors.secondaryLabel.resolveFrom(context);
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      children: [
        // ── Board name ──
        CupertinoListSection.insetGrouped(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            CupertinoListTile(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: TextField(
                controller: _nameC,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Board name',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),

        // ── Major focus ──
        CupertinoListSection.insetGrouped(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          footer: Text(
            'Primary core value — this will be the main theme of your board',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          children: [
            CupertinoListTile(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: DropdownButton<String>(
                value: _majorCoreValueId,
                underline: const SizedBox.shrink(),
                isDense: true,
                isExpanded: true,
                icon: Icon(CupertinoIcons.chevron_down, size: 16, color: muted),
                items: [
                  for (final cv in coreValueDefs)
                    DropdownMenuItem(
                      value: cv.id,
                      child: Row(
                        children: [
                          Icon(CoreValues.byId(cv.id).icon, size: 20),
                          const SizedBox(width: 10),
                          Text(cv.label),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _setMajorCoreValue(v);
                },
              ),
            ),
          ],
        ),

        // ── Core values — one card per value ──
        for (final cv in coreValueDefs)
          _buildCoreValueCard(cv.id, cv.label, muted, primary),

        // ── Next button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: FilledButton(
            onPressed: canNext ? _next : null,
            child: const Text('Next'),
          ),
        ),
      ],
    );
  }

  // ─── Per-core-value expandable card ─────────────────────────────

  Widget _buildCoreValueCard(
    String cvId,
    String label,
    Color muted,
    Color primary,
  ) {
    final core = CoreValues.byId(cvId);
    final isSelected = _selectedCoreValueIds.contains(cvId);
    final cats = _categoriesByCore[cvId] ?? const <String>[];
    final selectedCats = _selectedCategoriesByCore[cvId] ?? const <String>{};
    final goals = _goalsForCore(cvId)..sort((a, b) => a.name.compareTo(b.name));
    final showGoals = isSelected && selectedCats.isNotEmpty;

    return CupertinoListSection.insetGrouped(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Header row: icon + name + switch
        CupertinoListTile(
          leading: Icon(core.icon, size: 24),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: CupertinoSwitch(
            value: isSelected,
            onChanged: (v) => _toggleCoreValue(cvId, v),
          ),
        ),

        // Expanded content when selected
        if (isSelected) ...[
          // ─ Categories ─
          CupertinoListTile(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Categories', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _addCategory(cvId),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.add, size: 14, color: primary),
                          const SizedBox(width: 2),
                          Text('Add', style: TextStyle(fontSize: 13, color: primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (cats.isEmpty)
                  Text(
                    'Tap + Add to create categories',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: muted),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in cats)
                        FilterChip(
                          label: Text(c, style: const TextStyle(fontSize: 13)),
                          selected: selectedCats.contains(c),
                          onSelected: (v) => _toggleCategory(cvId, c, v),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // ─ Goals (only when at least one category selected) ─
          if (showGoals) ...[
            CupertinoListTile(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              title: Row(
                children: [
                  Text('Goals', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _addOrEditGoal(cvId),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.add, size: 14, color: primary),
                        const SizedBox(width: 2),
                        Text('Add goal', style: TextStyle(fontSize: 13, color: primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (goals.isEmpty)
              CupertinoListTile(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                title: Text(
                  'No goals yet — tap + Add goal',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: muted),
                ),
              ),
            for (final g in goals)
              CupertinoListTile(
                padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
                leading: Icon(
                  _reviewedGoalIds.contains(g.id)
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  size: 20,
                  color: _reviewedGoalIds.contains(g.id) ? primary : muted,
                ),
                title: Text(g.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(g.category, style: TextStyle(fontSize: 12, color: muted)),
                trailing: CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minSize: 0,
                  onPressed: () => _removeGoal(g),
                  child: Icon(CupertinoIcons.trash, size: 16, color: muted),
                ),
                onTap: () => _addOrEditGoal(cvId, existing: g),
              ),
          ],
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Private helper classes
// ═══════════════════════════════════════════════════════════════════

final class _WizardTodoDraft {
  final String id;
  final String text;
  final HabitItem? habit;

  const _WizardTodoDraft({
    required this.id,
    required this.text,
    required this.habit,
  });

  static const Object _unset = Object();

  _WizardTodoDraft copyWith({
    String? id,
    String? text,
    Object? habit = _unset,
  }) {
    return _WizardTodoDraft(
      id: id ?? this.id,
      text: text ?? this.text,
      habit: identical(habit, _unset) ? this.habit : habit as HabitItem?,
    );
  }

  static List<_WizardTodoDraft> fromSeed(WizardGoalDraft? seed) {
    if (seed == null) return const <_WizardTodoDraft>[];
    final habits = seed.habits;
    final byHabitId = <String, HabitItem>{for (final h in habits) h.id: h};
    final persisted = seed.todoItems;
    if (persisted.isNotEmpty) {
      return <_WizardTodoDraft>[
        for (final t in persisted)
          _WizardTodoDraft(id: t.id, text: t.text, habit: (t.habitId == null) ? null : byHabitId[t.habitId]),
      ];
    }
    return <_WizardTodoDraft>[
      for (final h in habits) _WizardTodoDraft(id: 'todo_${h.id}', text: h.name, habit: h),
    ];
  }

  static List<HabitItem> habitsFrom(List<_WizardTodoDraft> todos) {
    return todos.map((t) => t.habit).whereType<HabitItem>().toList();
  }

  static List<GoalTodoItem> todoItemsFrom(List<_WizardTodoDraft> todos) {
    final out = <GoalTodoItem>[];
    for (final src in todos) {
      final text = src.text.trim();
      if (text.isEmpty) continue;
      out.add(GoalTodoItem(
        id: src.id,
        text: text,
        isCompleted: false,
        completedAtMs: null,
        habitId: src.habit?.id,
        taskId: null,
      ));
    }
    return out;
  }
}

class _WizardTodoListEditor extends StatefulWidget {
  final List<_WizardTodoDraft> todos;
  final ValueChanged<List<_WizardTodoDraft>> onChanged;

  const _WizardTodoListEditor({required this.todos, required this.onChanged});

  @override
  State<_WizardTodoListEditor> createState() => _WizardTodoListEditorState();
}

class _WizardTodoListEditorState extends State<_WizardTodoListEditor> {
  final TextEditingController _bulkAddC = TextEditingController();

  @override
  void dispose() {
    _bulkAddC.dispose();
    super.dispose();
  }

  void _addItems() {
    final raw = _bulkAddC.text;
    final lines = raw.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (lines.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = <_WizardTodoDraft>[
      ...widget.todos,
      for (int i = 0; i < lines.length; i++)
        _WizardTodoDraft(id: 'todo_${now}_$i', text: lines[i], habit: null),
    ];
    widget.onChanged(next);
    _bulkAddC.clear();
    FocusScope.of(context).unfocus();
  }

  static HabitItem _applyHabitRequest(HabitItem base, HabitCreateRequest req) {
    return base.copyWith(
      name: req.name,
      category: req.category,
      frequency: req.frequency,
      weeklyDays: req.weeklyDays,
      deadline: req.deadline,
      afterHabitId: req.afterHabitId,
      timeOfDay: req.timeOfDay,
      reminderMinutes: req.reminderMinutes,
      reminderEnabled: req.reminderEnabled,
      chaining: req.chaining,
      cbtEnhancements: req.cbtEnhancements,
      timeBound: req.timeBound,
      locationBound: req.locationBound,
      trackingSpec: req.trackingSpec,
      iconIndex: req.iconIndex,
      actionSteps: req.actionSteps,
      startTimeMinutes: req.startTimeMinutes,
    );
  }

  Future<void> _configureHabit(int index) async {
    final item = widget.todos[index];
    final existing = item.habit;
    final otherHabits =
        widget.todos.where((t) => t.id != item.id).map((t) => t.habit).whereType<HabitItem>().toList();

    final HabitCreateRequest? req = (existing == null)
        ? await showAddHabitDialog(context,
            existingHabits: otherHabits, initialName: item.text.trim().isEmpty ? null : item.text.trim())
        : await showEditHabitDialog(context, habit: existing, existingHabits: otherHabits);

    if (req == null) return;
    final HabitItem nextHabit = _applyHabitRequest(
      existing ??
          HabitItem(
            id: 'habit_${DateTime.now().millisecondsSinceEpoch}',
            name: req.name,
            completedDates: const [],
          ),
      req,
    );
    final next = [...widget.todos];
    next[index] = item.copyWith(text: nextHabit.name, habit: nextHabit);
    widget.onChanged(next);
  }

  void _removeHabit(int index) {
    final next = [...widget.todos];
    next[index] = next[index].copyWith(habit: null);
    widget.onChanged(next);
  }

  void _removeRow(int index) {
    final next = [...widget.todos]..removeAt(index);
    widget.onChanged(next);
  }

  void _moveRow(int index, int delta) {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= widget.todos.length) return;
    final next = [...widget.todos];
    final item = next.removeAt(index);
    next.insert(nextIndex, item);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Todo list', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _bulkAddC,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Add todo items (one per line)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _addItems,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.todos.isEmpty)
              const Text('No todo items added.')
            else
              for (int i = 0; i < widget.todos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _TodoRow(
                    key: ValueKey(widget.todos[i].id),
                    index: i,
                    total: widget.todos.length,
                    item: widget.todos[i],
                    onMoveUp: () => _moveRow(i, -1),
                    onMoveDown: () => _moveRow(i, 1),
                    onTextChanged: (txt) {
                      final next = [...widget.todos];
                      final updated = next[i].copyWith(text: txt);
                      next[i] = updated.copyWith(habit: updated.habit?.copyWith(name: txt));
                      widget.onChanged(next);
                    },
                    onConfigureHabit: () => _configureHabit(i),
                    onRemoveHabit: () => _removeHabit(i),
                    onDelete: () => _removeRow(i),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  final int index;
  final int total;
  final _WizardTodoDraft item;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onConfigureHabit;
  final VoidCallback onRemoveHabit;
  final VoidCallback onDelete;

  const _TodoRow({
    super.key,
    required this.index,
    required this.total,
    required this.item,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onTextChanged,
    required this.onConfigureHabit,
    required this.onRemoveHabit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            IconButton(
              tooltip: 'Move up',
              onPressed: index == 0 ? null : onMoveUp,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed: index == (total - 1) ? null : onMoveDown,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: item.text,
                decoration: InputDecoration(
                  labelText: 'Item ${index + 1}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onTextChanged,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InputChip(
                    selected: item.habit != null,
                    label: Text((item.habit == null) ? 'Habit' : 'Habit ✓'),
                    onPressed: onConfigureHabit,
                    onDeleted: (item.habit == null) ? null : onRemoveHabit,
                    deleteIcon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Delete item',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
