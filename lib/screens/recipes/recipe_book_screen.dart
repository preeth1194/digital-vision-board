import 'package:flutter/material.dart';

import '../../models/habit_action_step.dart';
import '../../models/habit_item.dart';
import '../../models/recipe.dart';
import '../../services/habit_storage_service.dart';
import '../../services/recipe_storage_service.dart';

class RecipeBookScreen extends StatefulWidget {
  const RecipeBookScreen({super.key});

  @override
  State<RecipeBookScreen> createState() => _RecipeBookScreenState();
}

class _RecipeBookScreenState extends State<RecipeBookScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _ingredientFilterController =
      TextEditingController();
  final Set<String> _selectedMethods = <String>{};
  final Set<String> _selectedDiets = <String>{};
  bool _matchAllIngredients = false;
  List<Recipe> _recipes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ingredientFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    final recipes = await RecipeStorageService.loadAll();
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _loading = false;
    });
  }

  List<Recipe> get _filteredRecipes {
    final query = _searchController.text.trim().toLowerCase();
    final ingredientTokens = _ingredientFilterController.text
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    bool matchesIngredients(Recipe recipe) {
      if (ingredientTokens.isEmpty) return true;
      final ingredients = recipe.ingredients
          .map((e) => e.toLowerCase())
          .toList();
      bool hasToken(String token) => ingredients.any((i) => i.contains(token));
      if (_matchAllIngredients) {
        return ingredientTokens.every(hasToken);
      }
      return ingredientTokens.any(hasToken);
    }

    bool matchesMethods(Recipe recipe) {
      if (_selectedMethods.isEmpty) return true;
      final methods = recipe.cookingMethods.map((e) => e.toLowerCase()).toSet();
      return _selectedMethods.every(methods.contains);
    }

    bool matchesDiets(Recipe recipe) {
      if (_selectedDiets.isEmpty) return true;
      final tags = recipe.dietTags.map((e) => e.toLowerCase()).toSet();
      return _selectedDiets.every(tags.contains);
    }

    bool matchesSearch(Recipe recipe) {
      if (query.isEmpty) return true;
      final title = recipe.title.toLowerCase();
      final ingredients = recipe.ingredients.join(' ').toLowerCase();
      return title.contains(query) || ingredients.contains(query);
    }

    return _recipes.where((recipe) {
      return matchesSearch(recipe) &&
          matchesIngredients(recipe) &&
          matchesMethods(recipe) &&
          matchesDiets(recipe);
    }).toList();
  }

  Set<String> get _allMethods {
    final values = <String>{};
    for (final recipe in _recipes) {
      values.addAll(recipe.cookingMethods.map((e) => e.toLowerCase()));
    }
    return values;
  }

  Set<String> get _allDietTags {
    final values = <String>{};
    for (final recipe in _recipes) {
      values.addAll(recipe.dietTags.map((e) => e.toLowerCase()));
    }
    return values;
  }

  Future<void> _openEditor({Recipe? recipe}) async {
    final result = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(builder: (_) => RecipeEditorScreen(initial: recipe)),
    );
    if (result == null) return;
    await RecipeStorageService.upsertRecipe(result);
    await _loadRecipes();
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    await RecipeStorageService.deleteRecipe(recipe.id);
    await _loadRecipes();
  }

  Future<void> _createLinkedHabitFromRecipe(Recipe recipe) async {
    final newHabit = HabitItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Cook: ${recipe.title}',
      category: 'Nutrition',
      frequency: 'Weekly',
      weeklyDays: const [7],
      actionSteps: [
        for (int i = 0; i < recipe.methodSteps.length; i++)
          HabitActionStep(
            id: 'recipe_step_${DateTime.now().millisecondsSinceEpoch}_$i',
            title: recipe.methodSteps[i],
            iconCodePoint: Icons.restaurant_menu.codePoint,
            order: i,
          ),
      ],
      completedDates: const [],
    );
    await HabitStorageService.addHabit(newHabit);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Linked habit created for ${recipe.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _filteredRecipes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Book'),
        actions: [
          IconButton(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            tooltip: 'New recipe',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search recipes',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ingredientFilterController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    hintText: 'Filter by ingredients (comma separated)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Match all listed ingredients'),
                  value: _matchAllIngredients,
                  onChanged: (v) => setState(() => _matchAllIngredients = v),
                ),
                const SizedBox(height: 6),
                _FilterChipsRow(
                  label: 'Cooking Methods',
                  allValues: _allMethods.toList()..sort(),
                  selected: _selectedMethods,
                  onToggle: (value) => setState(() {
                    if (_selectedMethods.contains(value)) {
                      _selectedMethods.remove(value);
                    } else {
                      _selectedMethods.add(value);
                    }
                  }),
                ),
                const SizedBox(height: 8),
                _FilterChipsRow(
                  label: 'Diet',
                  allValues: _allDietTags.toList()..sort(),
                  selected: _selectedDiets,
                  onToggle: (value) => setState(() {
                    if (_selectedDiets.contains(value)) {
                      _selectedDiets.remove(value);
                    } else {
                      _selectedDiets.add(value);
                    }
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  '${recipes.length} recipe(s)',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                if (recipes.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No recipes match current filters.'),
                    ),
                  ),
                for (final recipe in recipes)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ingredients: ${recipe.ingredients.take(4).join(', ')}'
                            '${recipe.ingredients.length > 4 ? '...' : ''}',
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final m in recipe.cookingMethods)
                                Chip(label: Text(m)),
                              for (final d in recipe.dietTags)
                                Chip(label: Text(d)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _openEditor(recipe: recipe),
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _createLinkedHabitFromRecipe(recipe),
                                child: const Text('Create Linked Habit'),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => _deleteRecipe(recipe),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  final String label;
  final List<String> allValues;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _FilterChipsRow({
    required this.label,
    required this.allValues,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (allValues.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final value in allValues)
              FilterChip(
                label: Text(value),
                selected: selected.contains(value),
                onSelected: (_) => onToggle(value),
              ),
          ],
        ),
      ],
    );
  }
}

class RecipeEditorScreen extends StatefulWidget {
  final Recipe? initial;

  const RecipeEditorScreen({super.key, this.initial});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _ingredientsController;
  late final TextEditingController _stepsController;
  late final TextEditingController _methodsController;
  late final TextEditingController _dietController;
  late final TextEditingController _prepController;
  late final TextEditingController _cookController;
  late final TextEditingController _servingsController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _ingredientsController = TextEditingController(
      text: initial?.ingredients.join(', ') ?? '',
    );
    _stepsController = TextEditingController(
      text: initial?.methodSteps.join('\n') ?? '',
    );
    _methodsController = TextEditingController(
      text: initial?.cookingMethods.join(', ') ?? '',
    );
    _dietController = TextEditingController(
      text: initial?.dietTags.join(', ') ?? '',
    );
    _prepController = TextEditingController(
      text: (initial?.prepTimeMinutes ?? 0).toString(),
    );
    _cookController = TextEditingController(
      text: (initial?.cookTimeMinutes ?? 0).toString(),
    );
    _servingsController = TextEditingController(
      text: (initial?.servings ?? 1).toString(),
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _methodsController.dispose();
    _dietController.dispose();
    _prepController.dispose();
    _cookController.dispose();
    _servingsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> _splitCsv(String text) =>
      text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<String> _splitLines(String text) =>
      text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final recipe = Recipe(
      id: widget.initial?.id ?? now.toString(),
      title: title,
      ingredients: _splitCsv(_ingredientsController.text),
      methodSteps: _splitLines(_stepsController.text),
      cookingMethods: _splitCsv(_methodsController.text),
      dietTags: _splitCsv(_dietController.text),
      prepTimeMinutes: int.tryParse(_prepController.text.trim()) ?? 0,
      cookTimeMinutes: int.tryParse(_cookController.text.trim()) ?? 0,
      servings: int.tryParse(_servingsController.text.trim()) ?? 1,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      linkedHabitIds: widget.initial?.linkedHabitIds ?? const [],
      updatedAtMs: now,
    );
    Navigator.of(context).pop(recipe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'New Recipe' : 'Edit Recipe'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _ingredientsController,
            decoration: const InputDecoration(
              labelText: 'Ingredients (comma separated)',
            ),
          ),
          TextField(
            controller: _methodsController,
            decoration: const InputDecoration(
              labelText: 'Cooking methods (comma separated)',
            ),
          ),
          TextField(
            controller: _dietController,
            decoration: const InputDecoration(
              labelText: 'Diet tags (comma separated)',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prepController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prep min'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cookController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cook min'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _servingsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Servings'),
                ),
              ),
            ],
          ),
          TextField(
            controller: _stepsController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Method steps (one per line)',
            ),
          ),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ],
      ),
    );
  }
}
