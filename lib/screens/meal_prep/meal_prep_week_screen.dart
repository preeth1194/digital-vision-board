import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/meal_prep_week.dart';
import '../../models/recipe.dart';
import '../../services/habit_storage_service.dart';
import '../../services/meal_prep_storage_service.dart';
import '../../services/recipe_storage_service.dart';

class MealPrepWeekScreen extends StatefulWidget {
  const MealPrepWeekScreen({super.key});

  @override
  State<MealPrepWeekScreen> createState() => _MealPrepWeekScreenState();
}

class _MealPrepWeekScreenState extends State<MealPrepWeekScreen> {
  bool _loading = true;
  List<Recipe> _recipes = const [];
  List<HabitItem> _habits = const [];
  MealPrepWeek? _selectedWeek;
  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final weeks = await MealPrepStorageService.loadAll();
    final recipes = await RecipeStorageService.loadAll();
    final habits = await HabitStorageService.loadAll();
    final selected = weeks.isNotEmpty ? weeks.first : _createEmptyWeek();
    if (weeks.isEmpty) {
      await MealPrepStorageService.upsertWeek(selected);
    }
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _habits = habits;
      _selectedWeek = selected;
      _loading = false;
    });
  }

  MealPrepWeek _createEmptyWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final iso =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    return MealPrepWeek(
      id: 'week_${DateTime.now().millisecondsSinceEpoch}',
      weekStartDateIso: iso,
      recipeIdsByDay: const {},
      linkedHabitIds: const [],
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _saveSelected(MealPrepWeek next) async {
    await MealPrepStorageService.upsertWeek(next);
    await _load();
  }

  String _recipeName(String id) {
    final recipe = _recipes
        .where((r) => r.id == id)
        .cast<Recipe?>()
        .firstWhere((_) => true, orElse: () => null);
    return recipe?.title ?? 'Unknown recipe';
  }

  Future<void> _assignRecipe(String day, String recipeId) async {
    final week = _selectedWeek;
    if (week == null) return;
    final next = <String, List<String>>{};
    for (final entry in week.recipeIdsByDay.entries) {
      next[entry.key] = List<String>.from(entry.value);
    }
    final dayList = List<String>.from(next[day] ?? const <String>[]);
    dayList.add(recipeId);
    next[day] = dayList;
    await _saveSelected(week.copyWith(recipeIdsByDay: next));
  }

  Future<void> _removeRecipe(String day, String recipeId) async {
    final week = _selectedWeek;
    if (week == null) return;
    final next = <String, List<String>>{};
    for (final entry in week.recipeIdsByDay.entries) {
      next[entry.key] = List<String>.from(entry.value);
    }
    final dayList = List<String>.from(next[day] ?? const <String>[])
      ..remove(recipeId);
    next[day] = dayList;
    await _saveSelected(week.copyWith(recipeIdsByDay: next));
  }

  Future<void> _linkHabit(String habitId) async {
    final week = _selectedWeek;
    if (week == null) return;
    final next = week.linkedHabitIds.toSet()..add(habitId);
    await _saveSelected(week.copyWith(linkedHabitIds: next.toList()));
  }

  Future<void> _createLinkedMealPrepHabit() async {
    final habit = HabitItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Weekly Meal Prep',
      category: 'Nutrition',
      frequency: 'Weekly',
      weeklyDays: const [7],
      completedDates: const [],
    );
    await HabitStorageService.addHabit(habit);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Created Weekly Meal Prep habit')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final week = _selectedWeek;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Meal Prep'),
        actions: [
          IconButton(
            tooltip: 'Create linked habit',
            onPressed: _createLinkedMealPrepHabit,
            icon: const Icon(Icons.link),
          ),
        ],
      ),
      body: _loading || week == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Week of ${week.weekStartDateIso}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Link existing habit',
                  ),
                  items: _habits
                      .map(
                        (h) => DropdownMenuItem<String>(
                          value: h.id,
                          child: Text(h.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _linkHabit(value);
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: week.linkedHabitIds
                      .map(
                        (id) => Chip(
                          label: Text(
                            _habits
                                .firstWhere(
                                  (h) => h.id == id,
                                  orElse: () => HabitItem(
                                    id: id,
                                    name: id,
                                    completedDates: const [],
                                  ),
                                )
                                .name,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                for (final day in _days)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(day[0].toUpperCase() + day.substring(1)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Add recipe',
                              isDense: true,
                            ),
                            items: _recipes
                                .map(
                                  (r) => DropdownMenuItem<String>(
                                    value: r.id,
                                    child: Text(r.title),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              _assignRecipe(day, value);
                            },
                          ),
                          const SizedBox(height: 8),
                          for (final recipeId
                              in (week.recipeIdsByDay[day] ?? const <String>[]))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(_recipeName(recipeId)),
                              trailing: IconButton(
                                onPressed: () => _removeRecipe(day, recipeId),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
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
