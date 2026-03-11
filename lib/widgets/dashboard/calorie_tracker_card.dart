import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/calorie_entry.dart';
import '../../models/recipe.dart';
import '../../services/calorie_storage_service.dart';
import '../../services/recipe_storage_service.dart';
import '../../utils/app_typography.dart';
import 'glass_card.dart';

/// Dashboard card for tracking daily calorie intake.
///
/// Shows today's calories vs. goal with quick-add presets (+100, +200, +500)
/// and a food-entry bottom sheet. When adding a food item the user can:
///  - Type a food name (auto-suggests matching recipes)
///  - Enter quantity (servings, g, ml, cup)
///  - Add macros/nutrient breakdown (protein, carbs, fat)
/// Users can tap the goal label to edit it.
class CalorieTrackerCard extends StatefulWidget {
  const CalorieTrackerCard({super.key});

  @override
  State<CalorieTrackerCard> createState() => _CalorieTrackerCardState();
}

class _CalorieTrackerCardState extends State<CalorieTrackerCard> {
  CalorieEntry? _entry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = await CalorieStorageService.loadToday();
    if (mounted) setState(() => _entry = entry);
  }

  Future<void> _add(int amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    final updated = await CalorieStorageService.addCalories(amount);
    if (mounted) setState(() {
      _entry = updated;
      _saving = false;
    });
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Today'),
        content: const Text('Clear all calories logged today?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final updated = await CalorieStorageService.resetToday();
      if (mounted) setState(() => _entry = updated);
    }
  }

  Future<void> _showCustomEntry() async {
    // Load all recipes for autocomplete (catalog + user recipes)
    final allRecipes = await RecipeStorageService.loadAll();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodEntrySheet(
        allRecipes: allRecipes,
        onSubmit: (item) async {
          final updated = await CalorieStorageService.addFoodItem(item);
          if (mounted) setState(() => _entry = updated);
        },
      ),
    );
  }

  void _showGoalEditor() {
    final current = _entry?.goal ?? 2000;
    final ctrl = TextEditingController(text: current.toString());

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily Calorie Goal'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Goal (kcal)',
            suffixText: 'kcal',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v >= 500) {
                Navigator.pop(ctx);
                final updated = await CalorieStorageService.updateGoal(v);
                if (mounted) setState(() => _entry = updated);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entry = _entry;
    final calories = entry?.calories ?? 0;
    final goal = entry?.goal ?? 2000;
    final progress = goal > 0 ? (calories / goal).clamp(0.0, 1.0) : 0.0;
    final isOver = calories > goal;
    final isDone = calories >= goal && !isOver;

    const accent = Color(0xFFFF7043);        // deep-orange-400
    const accentDone = Color(0xFF43A047);    // green-600 (goal met)
    const accentOver = Color(0xFFE53935);    // red-600 (over limit)

    final barColor = isOver ? accentOver : (isDone ? accentDone : accent);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: barColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Calories',
                    style: AppTypography.heading3(context).copyWith(
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Goal chip + reset button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _showGoalEditor,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_formatKcal(goal)} goal',
                            style: AppTypography.caption(context).copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.edit_outlined,
                            size: 11,
                            color:
                                cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                    if (calories > 0) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _reset,
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Count display ────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatKcal(calories),
                        style: AppTypography.heading3(context).copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: barColor,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Text(
                          '/ ${_formatKcal(goal)}',
                          style: AppTypography.caption(context).copyWith(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOver
                        ? '${_formatKcal(calories - goal)} kcal over'
                        : isDone
                            ? 'Goal reached! 🎯'
                            : '${_formatKcal(goal - calories)} kcal remaining',
                    style: AppTypography.caption(context).copyWith(
                      color: isOver
                          ? accentOver
                          : isDone
                              ? accentDone
                              : cs.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // ── Macro summary (when food items with macros are logged) ───
            if (entry != null && entry.hasMacroData) ...[
              const SizedBox(height: 10),
              _MacroSummaryRow(entry: entry),
            ],

            const SizedBox(height: 10),

            // ── Progress bar ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),

            const SizedBox(height: 14),

            // ── Quick-add row ────────────────────────────────────────────
            Row(
              children: [
                for (final amount in [100, 200, 500]) ...[
                  if (amount != 100) const SizedBox(width: 6),
                  Expanded(
                    child: _QuickAddButton(
                      label: '+$amount',
                      bgColor: accent.withValues(alpha: 0.12),
                      textColor: accent,
                      enabled: !_saving,
                      onTap: () => _add(amount),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                // Food log entry button
                _QuickAddButton(
                  label: '+ Food',
                  bgColor: cs.surfaceContainerHighest,
                  textColor: cs.onSurfaceVariant,
                  enabled: !_saving,
                  onTap: _showCustomEntry,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatKcal(int v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.truncateToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return '$v';
  }
}

// ── Macro summary row ─────────────────────────────────────────────────────────

class _MacroSummaryRow extends StatelessWidget {
  final CalorieEntry entry;

  const _MacroSummaryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        _MacroChip(
          label: 'P',
          value: '${entry.totalProteinG.toStringAsFixed(0)}g',
          color: const Color(0xFF42A5F5),
        ),
        const SizedBox(width: 6),
        _MacroChip(
          label: 'C',
          value: '${entry.totalCarbsG.toStringAsFixed(0)}g',
          color: const Color(0xFFFF7043),
        ),
        const SizedBox(width: 6),
        _MacroChip(
          label: 'F',
          value: '${entry.totalFatG.toStringAsFixed(0)}g',
          color: const Color(0xFFEF5350),
        ),
        const Spacer(),
        Text(
          '${entry.foodItems.length} item${entry.foodItems.length == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Food entry bottom sheet ───────────────────────────────────────────────────

class _FoodEntrySheet extends StatefulWidget {
  final List<Recipe> allRecipes;
  final Future<void> Function(FoodLogItem item) onSubmit;

  const _FoodEntrySheet({
    required this.allRecipes,
    required this.onSubmit,
  });

  @override
  State<_FoodEntrySheet> createState() => _FoodEntrySheetState();
}

class _FoodEntrySheetState extends State<_FoodEntrySheet> {
  final _foodCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String _qtyUnit = 'serving';

  // Optional macro breakdown
  bool _showMacros = false;
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();

  // Recipe autocomplete state
  Recipe? _matchedRecipe;
  List<Recipe> _suggestions = [];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _foodCtrl.addListener(_onFoodChanged);
  }

  @override
  void dispose() {
    _foodCtrl.removeListener(_onFoodChanged);
    _foodCtrl.dispose();
    _calCtrl.dispose();
    _qtyCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fiberCtrl.dispose();
    super.dispose();
  }

  void _onFoodChanged() {
    final query = _foodCtrl.text.trim().toLowerCase();
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _matchedRecipe = null;
      });
      return;
    }

    final matches = widget.allRecipes
        .where((r) => r.title.toLowerCase().contains(query))
        .take(5)
        .toList();

    setState(() {
      _suggestions = matches;
      // Clear matched recipe if text changed away from it
      if (_matchedRecipe != null &&
          _matchedRecipe!.title.toLowerCase() != query) {
        _matchedRecipe = null;
      }
    });
  }

  void _applyRecipe(Recipe recipe) {
    _foodCtrl.removeListener(_onFoodChanged);
    _foodCtrl.text = recipe.title;
    _foodCtrl.addListener(_onFoodChanged);

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
    setState(() {
      _matchedRecipe = recipe;
      _suggestions = [];
    });

    _fillMacrosFromRecipe(recipe, qty);
  }

  void _fillMacrosFromRecipe(Recipe recipe, double qty) {
    final m = recipe.macros;
    if (m == null || m.isEmpty) return;

    setState(() => _showMacros = true);
    _calCtrl.text = (m.calories * qty).round().toString();
    _proteinCtrl.text =
        m.proteinG > 0 ? (m.proteinG * qty).toStringAsFixed(1) : '';
    _carbsCtrl.text =
        m.carbsG > 0 ? (m.carbsG * qty).toStringAsFixed(1) : '';
    _fatCtrl.text =
        m.fatG > 0 ? (m.fatG * qty).toStringAsFixed(1) : '';
    _fiberCtrl.text =
        m.fiberG > 0 ? (m.fiberG * qty).toStringAsFixed(1) : '';
  }

  void _onQtyChanged(String value) {
    final qty = double.tryParse(value) ?? 1.0;
    if (_matchedRecipe != null) {
      _fillMacrosFromRecipe(_matchedRecipe!, qty);
    }
  }

  Future<void> _submit() async {
    final foodName = _foodCtrl.text.trim();
    final calories = int.tryParse(_calCtrl.text.trim()) ?? 0;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;

    if (foodName.isEmpty && calories <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a food name or calorie count.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final item = FoodLogItem(
      foodName: foodName.isEmpty ? 'Food' : foodName,
      qty: qty,
      qtyUnit: _qtyUnit,
      calories: calories,
      proteinG: _showMacros
          ? double.tryParse(_proteinCtrl.text.trim())
          : null,
      carbsG: _showMacros
          ? double.tryParse(_carbsCtrl.text.trim())
          : null,
      fatG: _showMacros
          ? double.tryParse(_fatCtrl.text.trim())
          : null,
      fiberG: _showMacros
          ? double.tryParse(_fiberCtrl.text.trim())
          : null,
    );

    setState(() => _submitting = true);
    Navigator.of(context).pop();
    await widget.onSubmit(item);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
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
                  Icon(
                    Icons.restaurant_outlined,
                    color: const Color(0xFFFF7043),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Log Food',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Food name with recipe autocomplete
              TextField(
                controller: _foodCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Food name',
                  hintText: 'e.g. Chicken Rice Bowl',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _matchedRecipe != null
                      ? Icon(Icons.check_circle_rounded,
                          color: cs.primary, size: 20)
                      : null,
                ),
              ),

              // Recipe suggestion list
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final recipe in _suggestions)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _applyRecipe(recipe),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.menu_book_outlined,
                                    size: 16, color: cs.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    recipe.title,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                if (recipe.macros != null &&
                                    !recipe.macros!.isEmpty)
                                  Text(
                                    '${recipe.macros!.calories.toInt()} kcal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                if (recipe.isCatalog)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Qty + unit + calories
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: _onQtyChanged,
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        hintText: '1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _qtyUnit,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'serving', child: Text('serving')),
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'cup', child: Text('cup')),
                        DropdownMenuItem(
                            value: 'piece', child: Text('piece')),
                        DropdownMenuItem(value: 'tbsp', child: Text('tbsp')),
                        DropdownMenuItem(value: 'tsp', child: Text('tsp')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _qtyUnit = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _calCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: InputDecoration(
                        labelText: 'Calories',
                        hintText: '350',
                        suffixText: 'kcal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Toggle macro breakdown
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    setState(() => _showMacros = !_showMacros),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showMacros
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showMacros
                            ? 'Hide macro breakdown'
                            : 'Add macro breakdown (optional)',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Macro input fields (expandable)
              if (_showMacros) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MacroField(
                        controller: _proteinCtrl,
                        label: 'Protein',
                        color: const Color(0xFF42A5F5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MacroField(
                        controller: _carbsCtrl,
                        label: 'Carbs',
                        color: const Color(0xFFFF7043),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MacroField(
                        controller: _fatCtrl,
                        label: 'Fat',
                        color: const Color(0xFFEF5350),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MacroField(
                        controller: _fiberCtrl,
                        label: 'Fiber',
                        color: const Color(0xFF66BB6A),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add to Log'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Macro text field ──────────────────────────────────────────────────────────

class _MacroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;

  const _MacroField({
    required this.controller,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontSize: 12),
        suffixText: 'g',
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        ),
      ),
    );
  }
}

// ── Quick add button ──────────────────────────────────────────────────────────

class _QuickAddButton extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final bool enabled;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
