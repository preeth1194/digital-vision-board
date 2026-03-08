import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/habit_action_step.dart';
import '../../models/habit_item.dart';
import '../../models/recipe.dart';
import '../../services/habit_storage_service.dart';
import '../../services/recipe_storage_service.dart';

// ── Canonical filter values ───────────────────────────────────────────────────

const _kCuisines = [
  'American', 'Brazilian', 'British', 'Caribbean', 'Chinese',
  'Ethiopian', 'French', 'Greek', 'Indian', 'Italian',
  'Japanese', 'Korean', 'Mediterranean', 'Mexican', 'Middle Eastern',
  'Moroccan', 'Spanish', 'Thai', 'Turkish', 'Vietnamese',
];

const _kCookingTypes = [
  'air fry', 'bake', 'boil', 'braise', 'fry', 'grill',
  'no-cook', 'poach', 'pressure cook', 'roast', 'sauté',
  'slow cook', 'smoke', 'steam', 'stir fry',
];

const _kDietTags = [
  'dairy-free', 'gluten-free', 'high-protein', 'keto',
  'low-carb', 'nut-free', 'paleo', 'vegan',
  'vegetarian', 'whole30',
];

// ── Main screen ───────────────────────────────────────────────────────────────

class RecipeBookScreen extends StatefulWidget {
  const RecipeBookScreen({super.key});

  @override
  State<RecipeBookScreen> createState() => _RecipeBookScreenState();
}

class _RecipeBookScreenState extends State<RecipeBookScreen> {
  final _searchCtrl = TextEditingController();
  final _ingredientCtrl = TextEditingController();

  final Set<String> _selectedCuisines = {};
  final Set<String> _selectedMethods = {};
  final Set<String> _selectedDiets = {};
  bool _matchAllIngredients = false;

  List<Recipe> _recipes = const [];
  bool _loading = true;

  // Filter panel open/closed
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _ingredientCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final recipes = await RecipeStorageService.loadAll();
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _loading = false;
    });
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<Recipe> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    final ingredientTokens = _ingredientCtrl.text
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    return _recipes.where((r) {
      // Search
      if (query.isNotEmpty) {
        final haystack =
            '${r.title} ${r.cuisine} ${r.ingredients.join(' ')}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      // Ingredients
      if (ingredientTokens.isNotEmpty) {
        final ings = r.ingredients.map((e) => e.toLowerCase()).toList();
        bool has(String t) => ings.any((i) => i.contains(t));
        final ok = _matchAllIngredients
            ? ingredientTokens.every(has)
            : ingredientTokens.any(has);
        if (!ok) return false;
      }
      // Cuisine
      if (_selectedCuisines.isNotEmpty &&
          !_selectedCuisines.contains(r.cuisine)) {
        return false;
      }
      // Cooking method
      if (_selectedMethods.isNotEmpty) {
        final methods = r.cookingMethods.map((e) => e.toLowerCase()).toSet();
        if (!_selectedMethods.every(methods.contains)) return false;
      }
      // Diet
      if (_selectedDiets.isNotEmpty) {
        final tags = r.dietTags.map((e) => e.toLowerCase()).toSet();
        if (!_selectedDiets.every(tags.contains)) return false;
      }
      return true;
    }).toList();
  }

  int get _activeFilterCount =>
      _selectedCuisines.length +
      _selectedMethods.length +
      _selectedDiets.length +
      (_ingredientCtrl.text.trim().isNotEmpty ? 1 : 0);

  void _clearFilters() {
    setState(() {
      _selectedCuisines.clear();
      _selectedMethods.clear();
      _selectedDiets.clear();
      _ingredientCtrl.clear();
      _matchAllIngredients = false;
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _openEditor({Recipe? recipe}) async {
    final result = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(initial: recipe),
      ),
    );
    if (result == null) return;
    await RecipeStorageService.upsertRecipe(result);
    await _load();
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Delete "${recipe.title}"?'),
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
    if (confirmed == true) {
      await RecipeStorageService.deleteRecipe(recipe.id);
      await _load();
    }
  }

  Future<void> _createLinkedHabit(Recipe recipe) async {
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
      SnackBar(content: Text('Habit created for "${recipe.title}"')),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _loading ? const <Recipe>[] : _filtered;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Recipe Book'),
        actions: [
          // Filter toggle with badge
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: Icon(
                  _filtersExpanded
                      ? Icons.filter_list_off_rounded
                      : Icons.filter_list_rounded,
                ),
                tooltip: 'Filters',
                onPressed: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_activeFilterCount',
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onError,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New recipe',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: 'Search recipes, cuisines, ingredients…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _searchCtrl.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // ── Filter panel (collapsible) ──────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _filtersExpanded
                ? _FilterPanel(
                    ingredientCtrl: _ingredientCtrl,
                    matchAllIngredients: _matchAllIngredients,
                    selectedCuisines: _selectedCuisines,
                    selectedMethods: _selectedMethods,
                    selectedDiets: _selectedDiets,
                    activeFilterCount: _activeFilterCount,
                    onMatchAllChanged: (v) =>
                        setState(() => _matchAllIngredients = v),
                    onCuisineToggle: (v) => setState(
                      () => _selectedCuisines.contains(v)
                          ? _selectedCuisines.remove(v)
                          : _selectedCuisines.add(v),
                    ),
                    onMethodToggle: (v) => setState(
                      () => _selectedMethods.contains(v)
                          ? _selectedMethods.remove(v)
                          : _selectedMethods.add(v),
                    ),
                    onDietToggle: (v) => setState(
                      () => _selectedDiets.contains(v)
                          ? _selectedDiets.remove(v)
                          : _selectedDiets.add(v),
                    ),
                    onIngredientChanged: () => setState(() {}),
                    onClearAll: _clearFilters,
                  )
                : const SizedBox.shrink(),
          ),

          // ── Result count ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  _loading
                      ? 'Loading…'
                      : '${filtered.length} recipe${filtered.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                if (_activeFilterCount > 0) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearFilters,
                    child: Text(
                      'Clear filters',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Recipe grid ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _EmptyState(hasFilters: _activeFilterCount > 0 || _searchCtrl.text.isNotEmpty)
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _RecipeCard(
                          recipe: filtered[i],
                          onTap: () => _showDetail(filtered[i]),
                          onEdit: filtered[i].isCatalog
                              ? null
                              : () => _openEditor(recipe: filtered[i]),
                          onDelete: filtered[i].isCatalog
                              ? null
                              : () => _deleteRecipe(filtered[i]),
                          onFork: filtered[i].isCatalog
                              ? () => _forkRecipe(filtered[i])
                              : null,
                          onLinkedHabit: () => _createLinkedHabit(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showDetail(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RecipeDetailScreen(
          recipe: recipe,
          onEdit: recipe.isCatalog ? null : () => _openEditor(recipe: recipe),
          onFork: recipe.isCatalog ? () => _forkAndEdit(recipe) : null,
          onLinkedHabit: () => _createLinkedHabit(recipe),
        ),
      ),
    );
  }

  Future<void> _forkRecipe(Recipe recipe) async {
    // Fork a catalog recipe into the user's own copy and open the editor.
    await _forkAndEdit(recipe);
  }

  Future<void> _forkAndEdit(Recipe recipe) async {
    final forked = recipe.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isCatalog: false,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _openEditor(recipe: forked);
  }
}

// ── Filter panel ──────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final TextEditingController ingredientCtrl;
  final bool matchAllIngredients;
  final Set<String> selectedCuisines;
  final Set<String> selectedMethods;
  final Set<String> selectedDiets;
  final int activeFilterCount;
  final ValueChanged<bool> onMatchAllChanged;
  final ValueChanged<String> onCuisineToggle;
  final ValueChanged<String> onMethodToggle;
  final ValueChanged<String> onDietToggle;
  final VoidCallback onIngredientChanged;
  final VoidCallback onClearAll;

  const _FilterPanel({
    required this.ingredientCtrl,
    required this.matchAllIngredients,
    required this.selectedCuisines,
    required this.selectedMethods,
    required this.selectedDiets,
    required this.activeFilterCount,
    required this.onMatchAllChanged,
    required this.onCuisineToggle,
    required this.onMethodToggle,
    required this.onDietToggle,
    required this.onIngredientChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cuisine
          _SectionLabel(label: 'Cuisine', icon: Icons.public_rounded),
          const SizedBox(height: 6),
          _ChipRow(
            values: _kCuisines,
            selected: selectedCuisines,
            onToggle: onCuisineToggle,
          ),
          const SizedBox(height: 10),

          // Cooking Type
          _SectionLabel(
            label: 'Cooking Method',
            icon: Icons.outdoor_grill_rounded,
          ),
          const SizedBox(height: 6),
          _ChipRow(
            values: _kCookingTypes,
            selected: selectedMethods,
            onToggle: onMethodToggle,
          ),
          const SizedBox(height: 10),

          // Diet
          _SectionLabel(
            label: 'Diet',
            icon: Icons.eco_rounded,
          ),
          const SizedBox(height: 6),
          _ChipRow(
            values: _kDietTags,
            selected: selectedDiets,
            onToggle: onDietToggle,
          ),
          const SizedBox(height: 10),

          // Ingredient filter
          _SectionLabel(
            label: 'Ingredients',
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ingredientCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. chicken, garlic, lemon',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: (_) => onIngredientChanged(),
          ),
          Row(
            children: [
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: matchAllIngredients,
                  onChanged: onMatchAllChanged,
                ),
              ),
              Text(
                'Match ALL listed ingredients',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 13, color: cs.primary),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> values;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _ChipRow({
    required this.values,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final v in values)
          FilterChip(
            label: Text(v),
            selected: selected.contains(v),
            onSelected: (_) => onToggle(v),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

// ── Recipe card (grid item) ───────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onFork;
  final VoidCallback onLinkedHabit;

  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onFork,
    required this.onLinkedHabit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            _RecipeImage(imageUrl: recipe.imageUrl, height: 110),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cuisine tag
                    if (recipe.cuisine.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          recipe.cuisine,
                          style: textTheme.labelSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Title
                    Text(
                      recipe.title,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Time + servings row
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.people_outline_rounded,
                          size: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.servings}',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    // Diet chips (first 2)
                    if (recipe.dietTags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 3,
                          children: [
                            for (final tag in recipe.dietTags.take(2))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: cs.onTertiaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Action row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onFork != null)
                          _MiniIconBtn(
                            icon: Icons.fork_right_rounded,
                            tooltip: 'Fork & edit',
                            onTap: onFork!,
                          ),
                        if (onEdit != null)
                          _MiniIconBtn(
                            icon: Icons.edit_outlined,
                            tooltip: 'Edit',
                            onTap: onEdit!,
                          ),
                        if (onDelete != null)
                          _MiniIconBtn(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'Delete',
                            onTap: onDelete!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MiniIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 15,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ── Recipe image widget ───────────────────────────────────────────────────────

class _RecipeImage extends StatelessWidget {
  final String? imageUrl;
  final double height;

  const _RecipeImage({this.imageUrl, required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        height: height,
        color: cs.surfaceContainerHighest,
        child: Icon(
          Icons.restaurant_rounded,
          size: 36,
          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: height,
        color: cs.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: cs.surfaceContainerHighest,
        child: Icon(
          Icons.restaurant_rounded,
          size: 36,
          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({required this.hasFilters});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilters
                ? Icons.filter_list_off_rounded
                : Icons.menu_book_rounded,
            size: 56,
            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No recipes match your filters' : 'No recipes yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 6),
            Text(
              'Tap + to add your first recipe',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Recipe detail screen ──────────────────────────────────────────────────────

class _RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onEdit;
  final VoidCallback? onFork;
  final VoidCallback onLinkedHabit;

  const _RecipeDetailScreen({
    required this.recipe,
    this.onEdit,
    this.onFork,
    required this.onLinkedHabit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            actions: [
              if (onFork != null)
                IconButton(
                  icon: const Icon(Icons.fork_right_rounded),
                  tooltip: 'Fork & edit',
                  onPressed: () {
                    Navigator.pop(context);
                    onFork!();
                  },
                ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit!();
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: recipe.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: recipe.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: cs.surfaceContainerHighest,
                      ),
                    )
                  : Container(color: cs.surfaceContainerHighest),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (recipe.cuisine.isNotEmpty)
                        Chip(
                          label: Text(recipe.cuisine),
                          avatar: const Icon(Icons.public_rounded, size: 14),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (recipe.prepTimeMinutes + recipe.cookTimeMinutes > 0)
                        Chip(
                          label: Text(
                            '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min',
                          ),
                          avatar: const Icon(Icons.schedule_rounded, size: 14),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (recipe.servings > 1)
                        Chip(
                          label: Text('${recipe.servings} servings'),
                          avatar: const Icon(
                            Icons.people_outline_rounded,
                            size: 14,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      for (final tag in recipe.cookingMethods)
                        Chip(
                          label: Text(tag),
                          avatar: const Icon(
                            Icons.outdoor_grill_rounded,
                            size: 14,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      for (final tag in recipe.dietTags)
                        Chip(
                          label: Text(tag),
                          avatar: const Icon(Icons.eco_rounded, size: 14),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: cs.tertiaryContainer,
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Ingredients
                  _DetailSection(
                    icon: Icons.inventory_2_outlined,
                    title: 'Ingredients',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final ing in recipe.ingredients)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 5,
                                    right: 8,
                                  ),
                                  child: CircleAvatar(
                                    radius: 3,
                                    backgroundColor: cs.primary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    ing,
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Method
                  _DetailSection(
                    icon: Icons.format_list_numbered_rounded,
                    title: 'Method',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < recipe.methodSteps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.only(
                                    top: 1,
                                    right: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i + 1}',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    recipe.methodSteps[i],
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (recipe.notes != null &&
                      recipe.notes!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _DetailSection(
                      icon: Icons.notes_rounded,
                      title: 'Notes',
                      child: Text(
                        recipe.notes!,
                        style: textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Create habit button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onLinkedHabit();
                    },
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Create Linked Habit'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ── Recipe editor (unchanged logic, updated for new fields) ──────────────────

class RecipeEditorScreen extends StatefulWidget {
  final Recipe? initial;

  const RecipeEditorScreen({super.key, this.initial});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _cuisineCtrl;
  late final TextEditingController _ingredientsCtrl;
  late final TextEditingController _stepsCtrl;
  late final TextEditingController _methodsCtrl;
  late final TextEditingController _dietCtrl;
  late final TextEditingController _prepCtrl;
  late final TextEditingController _cookCtrl;
  late final TextEditingController _servingsCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _cuisineCtrl = TextEditingController(text: r?.cuisine ?? '');
    _ingredientsCtrl =
        TextEditingController(text: r?.ingredients.join(', ') ?? '');
    _stepsCtrl =
        TextEditingController(text: r?.methodSteps.join('\n') ?? '');
    _methodsCtrl =
        TextEditingController(text: r?.cookingMethods.join(', ') ?? '');
    _dietCtrl = TextEditingController(text: r?.dietTags.join(', ') ?? '');
    _prepCtrl =
        TextEditingController(text: (r?.prepTimeMinutes ?? 0).toString());
    _cookCtrl =
        TextEditingController(text: (r?.cookTimeMinutes ?? 0).toString());
    _servingsCtrl =
        TextEditingController(text: (r?.servings ?? 1).toString());
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _cuisineCtrl, _ingredientsCtrl, _stepsCtrl,
      _methodsCtrl, _dietCtrl, _prepCtrl, _cookCtrl, _servingsCtrl, _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _csv(String text) =>
      text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<String> _lines(String text) =>
      text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    Navigator.of(context).pop(
      Recipe(
        id: widget.initial?.id ?? now.toString(),
        title: title,
        cuisine: _cuisineCtrl.text.trim(),
        ingredients: _csv(_ingredientsCtrl.text),
        methodSteps: _lines(_stepsCtrl.text),
        cookingMethods: _csv(_methodsCtrl.text),
        dietTags: _csv(_dietCtrl.text),
        prepTimeMinutes: int.tryParse(_prepCtrl.text.trim()) ?? 0,
        cookTimeMinutes: int.tryParse(_cookCtrl.text.trim()) ?? 0,
        servings: int.tryParse(_servingsCtrl.text.trim()) ?? 1,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        imageUrl: widget.initial?.imageUrl,
        linkedHabitIds: widget.initial?.linkedHabitIds ?? const [],
        updatedAtMs: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'New Recipe' : 'Edit Recipe'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_titleCtrl, 'Title'),
          _field(_cuisineCtrl, 'Cuisine (e.g. Italian, Japanese)'),
          _field(_ingredientsCtrl, 'Ingredients (comma separated)'),
          _field(_methodsCtrl, 'Cooking methods (comma separated)'),
          _field(_dietCtrl, 'Diet tags (comma separated)'),
          Row(
            children: [
              Expanded(child: _field(_prepCtrl, 'Prep min', numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _field(_cookCtrl, 'Cook min', numeric: true)),
              const SizedBox(width: 12),
              Expanded(
                child: _field(_servingsCtrl, 'Servings', numeric: true),
              ),
            ],
          ),
          TextField(
            controller: _stepsCtrl,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Method steps (one per line)',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
