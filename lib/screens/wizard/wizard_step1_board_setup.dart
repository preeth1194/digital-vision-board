import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/core_value.dart';
import '../../models/wizard/wizard_core_value.dart';
import '../../models/wizard/wizard_state.dart';
import '../../services/wizard_defaults_service.dart';
import '../../utils/app_typography.dart';

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

    // Start with local fallback defaults; async-load backend defaults from cache/network.
    final fallback = WizardDefaultsService.getDefaults(); // async
    // seed immediate fallback synchronously from in-app defaults
    _coreValues = CoreValues.all.map((c) => WizardCoreValueDef(id: c.id, label: c.label)).toList();
    _defaultCategoriesByCore = {
      for (final cv in CoreValues.all) cv.id: WizardCoreValueCatalog.defaultsFor(cv.id),
    };

    _categoriesByCore = {
      for (final id in _selectedCoreValueIds) id: [
        ...(_defaultCategoriesByCore[id] ?? WizardCoreValueCatalog.defaultsFor(id)),
        ...widget.initial.categoriesFor(id),
      ]..toSet().toList(),
    };

    // User-selected categories only (default: none selected).
    _selectedCategoriesByCore = {
      for (final id in _selectedCoreValueIds) id: <String>{},
    };

    // Lazy load backend defaults (does not block UI).
    unawaited(_loadDefaults(fallback));
  }

  Future<void> _loadDefaults(Future<WizardDefaultsPayload> fut) async {
    final loaded = await fut;
    if (!mounted) return;

    setState(() {
      _coreValues = loaded.coreValues;
      _defaultCategoriesByCore = loaded.categoriesByCoreValueId;

      // Merge in any new default categories for currently selected core values.
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
      // Best UX with "none selected by default": auto-select newly added category.
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
        // Never allow removing the major core value.
        if (id == _majorCoreValueId) return;
        _selectedCoreValueIds.remove(id);
        _categoriesByCore.remove(id);
        _selectedCategoriesByCore.remove(id);
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

  void _next() {
    final name = _nameC.text.trim();
    if (name.isEmpty) return;
    final major = CoreValues.byId(_majorCoreValueId).id;
    if (major.isEmpty) return;

    if (!_step1CategoriesValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 1 category for each selected core value.')),
      );
      return;
    }

    final ids = {..._selectedCoreValueIds, major}.toList();
    final selections = <WizardCoreValueSelection>[];
    for (final id in ids) {
      // Persist only user-selected categories (these drive later steps).
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _nameC.text.trim().isNotEmpty;
    final coreValueDefs = _coreValues.isNotEmpty
        ? _coreValues
        : CoreValues.all.map((c) => WizardCoreValueDef(id: c.id, label: c.label)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Name your board',
          style: AppTypography.heading3(context),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameC,
          decoration: const InputDecoration(
            hintText: 'e.g. My Dream Life 2026',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(
          'Major focus (core value)',
          style: AppTypography.heading2(context),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _majorCoreValueId,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final cv in coreValueDefs)
              DropdownMenuItem(
                value: cv.id,
                child: Text(cv.label),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            _setMajorCoreValue(v);
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Other core values to include',
          style: AppTypography.heading2(context),
        ),
        const SizedBox(height: 8),
        for (final cv in coreValueDefs)
          CheckboxListTile(
            value: _selectedCoreValueIds.contains(cv.id),
            onChanged: (v) => _toggleCoreValue(cv.id, v == true),
            title: Text(cv.label),
            secondary: Icon(CoreValues.byId(cv.id).icon),
          ),
        const SizedBox(height: 8),
        Text(
          'Categories (per core value)',
          style: AppTypography.heading2(context),
        ),
        const SizedBox(height: 4),
        Text(
          'Select the categories you want to use in the next steps.',
          style: AppTypography.secondary(context),
        ),
        const SizedBox(height: 8),
        for (final id in _selectedCoreValueIds) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          CoreValues.byId(id).label,
                          style: AppTypography.heading3(context),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _addCategory(id),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (((_categoriesByCore[id] ?? const <String>[])).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Selected: ${(_selectedCategoriesByCore[id] ?? const <String>{}).length}',
                            style: AppTypography.caption(context),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in (_categoriesByCore[id] ?? const <String>[]))
                        FilterChip(
                          label: Text(c),
                          selected: (_selectedCategoriesByCore[id] ?? const <String>{}).contains(c),
                          onSelected: (v) => _toggleCategory(id, c, v),
                        ),
                      if (((_categoriesByCore[id] ?? const <String>[])).isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'No categories yet. Add some.',
                                style: AppTypography.secondary(context),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        FilledButton(
          onPressed: canNext ? _next : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

