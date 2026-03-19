import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit_action_step.dart';
import '../../models/habit_item.dart';
import '../../models/meal_prep_week.dart';
import '../../models/recipe.dart';
import '../../services/dv_auth_service.dart';
import '../../services/habit_storage_service.dart';
import '../../services/meal_prep_storage_service.dart';
import '../../services/recipe_storage_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../../utils/nutrition_calculator.dart';

class MealPrepWeekScreen extends StatefulWidget {
  final bool openPreviewOnLaunch;

  const MealPrepWeekScreen({
    super.key,
    this.openPreviewOnLaunch = false,
  });

  @override
  State<MealPrepWeekScreen> createState() => _MealPrepWeekScreenState();
}

class _MealPrepWeekScreenState extends State<MealPrepWeekScreen> {
  static const String _mealPrepTemplateId = 'meal_prep_auto_plan_v1';
  static const List<String> _days = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  static const List<String> _slots = <String>[
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];
  static const Map<String, String> _dayLabels = <String, String>{
    'monday': 'Mon',
    'tuesday': 'Tue',
    'wednesday': 'Wed',
    'thursday': 'Thu',
    'friday': 'Fri',
    'saturday': 'Sat',
    'sunday': 'Sun',
  };
  static const Map<String, int> _weekdayByDay = <String, int>{
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };
  static const Map<String, String> _plannerDayByDay = <String, String>{
    'monday': 'mon',
    'tuesday': 'tue',
    'wednesday': 'wed',
    'thursday': 'thu',
    'friday': 'fri',
    'saturday': 'sat',
    'sunday': 'sun',
  };
  static const Map<String, String> _slotLabels = <String, String>{
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  };
  static const List<String> _activityLevels = <String>[
    'sedentary',
    'light',
    'moderate',
    'very_active',
  ];
  static const List<String> _dietOptions = <String>[
    'balanced',
    'vegetarian',
    'vegan',
    'pescatarian',
  ];

  final TextEditingController _targetCaloriesCtrl = TextEditingController();
  final TextEditingController _guestHeightCtrl = TextEditingController();
  final TextEditingController _guestWeightCtrl = TextEditingController();
  final TextEditingController _guestAgeCtrl = TextEditingController();
  final TextEditingController _guestAllergiesCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _isEditingPlan = true;
  bool _isGuest = true;
  List<Recipe> _recipes = const [];
  MealPrepWeek? _selectedWeek;

  double? _profileWeightKg;
  double? _profileHeightCm;
  int? _profileAgeYears;
  String _profileGender = 'prefer_not_to_say';
  String _profileActivityLevel = 'moderate';
  String _profileDiet = 'balanced';
  List<String> _profileAllergies = const [];

  String _guestGender = 'prefer_not_to_say';
  String _guestActivityLevel = 'moderate';
  String _guestDiet = 'balanced';

  String? _targetCaloriesError;
  String? _guestHeightError;
  String? _guestWeightError;
  String? _guestAgeError;
  String? _guestAllergiesError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _targetCaloriesCtrl.dispose();
    _guestHeightCtrl.dispose();
    _guestWeightCtrl.dispose();
    _guestAgeCtrl.dispose();
    _guestAllergiesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = await DvAuthService.getDvToken();
    final isGuest = token == null;
    final weeks = await MealPrepStorageService.loadAll();
    final recipes = await RecipeStorageService.loadAll();
    final selected = weeks.isNotEmpty ? weeks.first : _createEmptyWeek();
    if (weeks.isEmpty) {
      await MealPrepStorageService.upsertWeek(selected);
    }

    final weightKg = await DvAuthService.getWeightKg();
    final heightCm = await DvAuthService.getHeightCm();
    final gender = await DvAuthService.getGender();
    final dob = await DvAuthService.getDateOfBirth();
    final activityLevel = await DvAuthService.getActivityLevel();
    final dietPreference = await DvAuthService.getDietPreference();
    final allergies = await DvAuthService.getAllergies();

    final age = _ageFromDobIso(dob);
    final maintenanceFromWeek = selected.maintenanceCalories;
    final target = selected.targetCalories ?? maintenanceFromWeek;
    _targetCaloriesCtrl.text = target?.toString() ?? '';
    _guestWeightCtrl.text = weightKg?.toStringAsFixed(1) ?? '';
    _guestHeightCtrl.text = heightCm?.toStringAsFixed(0) ?? '';
    _guestAgeCtrl.text = age?.toString() ?? '';
    _guestGender = gender;
    _guestActivityLevel = activityLevel;
    _guestDiet = dietPreference ?? 'balanced';
    _guestAllergiesCtrl.text = allergies.join(', ');
    final hasMissingRequired = isGuest
        ? _guestHeightCtrl.text.trim().isEmpty ||
            _guestWeightCtrl.text.trim().isEmpty ||
            _guestAgeCtrl.text.trim().isEmpty
        : (weightKg == null || heightCm == null || age == null);
    final hasPlannedMeals = _hasAnyPlannedMeals(selected);

    if (!mounted) return;
    setState(() {
      _isGuest = isGuest;
      _recipes = recipes;
      _selectedWeek = selected;
      _profileWeightKg = weightKg;
      _profileHeightCm = heightCm;
      _profileAgeYears = age;
      _profileGender = gender;
      _profileActivityLevel = activityLevel;
      _profileDiet = dietPreference ?? 'balanced';
      _profileAllergies = allergies;
      final canOpenPreview = !hasMissingRequired && hasPlannedMeals;
      _isEditingPlan = widget.openPreviewOnLaunch
          ? !canOpenPreview
          : (hasMissingRequired || !hasPlannedMeals);
      _loading = false;
    });
  }

  int? _ageFromDobIso(String? dobIso) {
    final value = (dobIso ?? '').trim();
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    final now = DateTime.now();
    var age = now.year - parsed.year;
    final hasBirthdayPassed =
        now.month > parsed.month ||
        (now.month == parsed.month && now.day >= parsed.day);
    if (!hasBirthdayPassed) age -= 1;
    return age > 0 ? age : null;
  }

  String _dobIsoFromAge(int ageYears) {
    final now = DateTime.now();
    final dob = DateTime(now.year - ageYears, now.month, now.day);
    return '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
  }

  Future<void> _persistProfileInputs(_NutritionInput input) async {
    await DvAuthService.setWeightKg(input.weightKg);
    await DvAuthService.setHeightCm(input.heightCm);
    await DvAuthService.setDateOfBirth(_dobIsoFromAge(input.ageYears));
    await DvAuthService.setGender(input.gender);
    await DvAuthService.setActivityLevel(input.activityLevel);
    await DvAuthService.setDietPreference(input.dietPreference);
    await DvAuthService.setAllergies(input.allergies);
  }

  void _applyProfileStateFromInput(_NutritionInput input) {
    _profileWeightKg = input.weightKg;
    _profileHeightCm = input.heightCm;
    _profileAgeYears = input.ageYears;
    _profileGender = input.gender;
    _profileActivityLevel = input.activityLevel;
    _profileDiet = input.dietPreference;
    _profileAllergies = input.allergies;
  }

  MealPrepWeek _createEmptyWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final iso =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    return MealPrepWeek(
      id: 'week_${DateTime.now().millisecondsSinceEpoch}',
      weekStartDateIso: iso,
      recipeIdByDayAndSlot: const {},
      recipeIdsByDay: const {},
      linkedHabitIds: const [],
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool _hasAnyPlannedMeals(MealPrepWeek week) {
    for (final day in _days) {
      final slots = week.recipeIdByDayAndSlot[day];
      if (slots == null || slots.isEmpty) continue;
      if (slots.values.any((id) => id.trim().isNotEmpty)) return true;
    }
    return false;
  }

  int? _parseInt(String raw) => int.tryParse(raw.trim());
  double? _parseDecimal(String raw) => double.tryParse(raw.trim());

  List<String> _normalizeAllergyTokens(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String? _validateTargetCalories(String raw, {required bool required}) {
    final value = raw.trim();
    if (value.isEmpty) {
      return required ? 'Target calories is required.' : null;
    }
    final parsed = _parseInt(value);
    if (parsed == null) return 'Enter target calories as a number.';
    if (parsed < 1000 || parsed > 6000) {
      return 'Target calories must be between 1000 and 6000.';
    }
    return null;
  }

  String? _validateHeightCm(String raw, {required bool required}) {
    final value = raw.trim();
    if (value.isEmpty) {
      return required ? 'Height is required.' : null;
    }
    final parsed = _parseDecimal(value);
    if (parsed == null) return 'Enter height as a number.';
    if (parsed < 100 || parsed > 250) {
      return 'Height must be between 100 and 250 cm.';
    }
    return null;
  }

  String? _validateWeightKg(String raw, {required bool required}) {
    final value = raw.trim();
    if (value.isEmpty) {
      return required ? 'Weight is required.' : null;
    }
    final parsed = _parseDecimal(value);
    if (parsed == null) return 'Enter weight as a number.';
    if (parsed < 25 || parsed > 300) {
      return 'Weight must be between 25 and 300 kg.';
    }
    return null;
  }

  String? _validateAge(String raw, {required bool required}) {
    final value = raw.trim();
    if (value.isEmpty) {
      return required ? 'Age is required.' : null;
    }
    final parsed = _parseInt(value);
    if (parsed == null) return 'Enter age as a whole number.';
    if (parsed < 10 || parsed > 100) {
      return 'Age must be between 10 and 100.';
    }
    return null;
  }

  String? _validateAllergies(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final normalized = _normalizeAllergyTokens(trimmed);
    if (normalized.isEmpty) {
      return 'Enter at least one allergy name.';
    }
    return null;
  }

  bool _validateInputsForAction() {
    final targetError = _validateTargetCalories(
      _targetCaloriesCtrl.text,
      required: true,
    );
    String? heightError;
    String? weightError;
    String? ageError;
    String? allergiesError;
    if (_showInlineGuestForm) {
      heightError = _validateHeightCm(_guestHeightCtrl.text, required: true);
      weightError = _validateWeightKg(_guestWeightCtrl.text, required: true);
      ageError = _validateAge(_guestAgeCtrl.text, required: true);
      allergiesError = _validateAllergies(_guestAllergiesCtrl.text);
    }

    if (!mounted) {
      return targetError == null &&
          heightError == null &&
          weightError == null &&
          ageError == null &&
          allergiesError == null;
    }

    setState(() {
      _targetCaloriesError = targetError;
      _guestHeightError = heightError;
      _guestWeightError = weightError;
      _guestAgeError = ageError;
      _guestAllergiesError = allergiesError;
    });

    return targetError == null &&
        heightError == null &&
        weightError == null &&
        ageError == null &&
        allergiesError == null;
  }

  bool get _showInlineGuestForm {
    if (_isGuest) return true;
    return _profileWeightKg == null ||
        _profileHeightCm == null ||
        _profileAgeYears == null;
  }

  _NutritionInput? _activeInput() {
    if (_showInlineGuestForm) {
      final height = _parseDecimal(_guestHeightCtrl.text);
      final weight = _parseDecimal(_guestWeightCtrl.text);
      final age = _parseInt(_guestAgeCtrl.text);
      if (height == null || weight == null || age == null) return null;
      return _NutritionInput(
        heightCm: height,
        weightKg: weight,
        ageYears: age,
        gender: _guestGender,
        activityLevel: _guestActivityLevel,
        dietPreference: _guestDiet,
        allergies: _normalizeAllergyTokens(_guestAllergiesCtrl.text),
      );
    }
    if (_profileHeightCm == null || _profileWeightKg == null || _profileAgeYears == null) {
      return null;
    }
    return _NutritionInput(
      heightCm: _profileHeightCm!,
      weightKg: _profileWeightKg!,
      ageYears: _profileAgeYears!,
      gender: _profileGender,
      activityLevel: _profileActivityLevel,
      dietPreference: _profileDiet,
      allergies: _profileAllergies,
    );
  }

  _NutritionMetrics? _metricsFromInput(_NutritionInput? input) {
    if (input == null) return null;
    final bmi = NutritionCalculator.bmi(
      weightKg: input.weightKg,
      heightCm: input.heightCm,
    );
    final bmr = NutritionCalculator.bmrMifflinStJeor(
      weightKg: input.weightKg,
      heightCm: input.heightCm,
      ageYears: input.ageYears,
      gender: input.gender,
    );
    final maintenance = NutritionCalculator.maintenanceCalories(
      bmr: bmr,
      activityLevel: input.activityLevel,
    );
    if (bmi <= 0 || bmr <= 0 || maintenance <= 0) return null;
    var target = _parseInt(_targetCaloriesCtrl.text);
    target ??= maintenance.round();
    return _NutritionMetrics(
      bmi: bmi,
      bmr: bmr.round(),
      maintenanceCalories: maintenance.round(),
      targetCalories: target.clamp(1000, 6000),
    );
  }

  List<Recipe> _filteredRecipesForInput(_NutritionInput input) {
    bool matchesDiet(Recipe recipe) {
      final diet = input.dietPreference;
      final tags = recipe.dietTags.map((e) => e.toLowerCase()).toSet();
      if (diet == 'vegan') return tags.contains('vegan');
      if (diet == 'vegetarian') {
        return tags.contains('vegetarian') || tags.contains('vegan');
      }
      if (diet == 'pescatarian') {
        if (tags.contains('pescatarian')) return true;
        final text =
            '${recipe.title} ${recipe.ingredients.join(' ')} ${recipe.notes ?? ''}'
                .toLowerCase();
        return text.contains('fish') ||
            text.contains('salmon') ||
            text.contains('tuna') ||
            text.contains('shrimp') ||
            text.contains('prawn');
      }
      return true;
    }

    bool matchesAllergies(Recipe recipe) {
      if (input.allergies.isEmpty) return true;
      final haystack =
          '${recipe.title} ${recipe.ingredients.join(' ')} ${recipe.notes ?? ''} ${recipe.dietTags.join(' ')}'
              .toLowerCase();
      for (final allergy in input.allergies) {
        if (allergy.isEmpty) continue;
        if (haystack.contains(allergy)) return false;
      }
      return true;
    }

    return _recipes
        .where((r) => matchesDiet(r) && matchesAllergies(r))
        .toList(growable: false);
  }

  int _fallbackCaloriesForSlot(String slot) {
    switch (slot) {
      case 'breakfast':
        return 400;
      case 'lunch':
        return 550;
      case 'dinner':
        return 650;
      case 'snack':
      default:
        return 200;
    }
  }

  int _slotCompatibilityPenalty(Recipe recipe, String slot) {
    final title = recipe.title.toLowerCase();
    if (slot == 'breakfast' && (title.contains('oat') || title.contains('egg'))) {
      return 0;
    }
    if (slot == 'snack' && title.contains('salad')) return 60;
    if (slot == 'dinner' && title.contains('oat')) return 220;
    return 0;
  }

  String? _pickRecipeForSlot({
    required String slot,
    required int targetCalories,
    required List<Recipe> candidates,
    required Set<String> dayUsedRecipeIds,
    String? currentRecipeId,
  }) {
    if (candidates.isEmpty) return currentRecipeId;
    final ranked = List<Recipe>.from(candidates)
      ..sort((a, b) {
        final aCalories = (a.macros?.calories ?? 0) > 0
            ? a.macros!.calories.round()
            : _fallbackCaloriesForSlot(slot);
        final bCalories = (b.macros?.calories ?? 0) > 0
            ? b.macros!.calories.round()
            : _fallbackCaloriesForSlot(slot);
        final aScore = (aCalories - targetCalories).abs() +
            (dayUsedRecipeIds.contains(a.id) ? 240 : 0) +
            _slotCompatibilityPenalty(a, slot);
        final bScore = (bCalories - targetCalories).abs() +
            (dayUsedRecipeIds.contains(b.id) ? 240 : 0) +
            _slotCompatibilityPenalty(b, slot);
        return aScore.compareTo(bScore);
      });
    if (currentRecipeId != null && currentRecipeId.isNotEmpty) {
      final current = ranked.where((r) => r.id == currentRecipeId).toList();
      if (current.isNotEmpty) {
        final currRecipe = current.first;
        final calories = (currRecipe.macros?.calories ?? 0) > 0
            ? currRecipe.macros!.calories.round()
            : _fallbackCaloriesForSlot(slot);
        final diff = (calories - targetCalories).abs();
        if (targetCalories > 0 && diff <= (targetCalories * 0.15).round()) {
          return currRecipe.id;
        }
      }
    }
    return ranked.first.id;
  }

  Map<String, Map<String, String>> _deepCopyPlanMap(
    Map<String, Map<String, String>> source,
  ) {
    final next = <String, Map<String, String>>{};
    for (final day in _days) {
      final current = source[day] ?? const <String, String>{};
      next[day] = Map<String, String>.from(current);
    }
    return next;
  }

  Future<void> _persistWeek(MealPrepWeek next) async {
    await MealPrepStorageService.upsertWeek(next);
    if (!mounted) return;
    setState(() {
      _selectedWeek = next;
    });
  }

  Recipe? _recipeById(String id) {
    for (final recipe in _recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  Future<void> _saveTargetCalories() async {
    final week = _selectedWeek;
    if (week == null) return;
    final targetError = _validateTargetCalories(
      _targetCaloriesCtrl.text,
      required: true,
    );
    if (mounted) {
      setState(() => _targetCaloriesError = targetError);
    }
    if (targetError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(targetError)),
      );
      return;
    }
    final parsed = _parseInt(_targetCaloriesCtrl.text)!;
    await _persistWeek(week.copyWith(targetCalories: parsed));
  }

  Future<void> _assignRecipeForSlot(
    String day,
    String slot,
    String? recipeId,
  ) async {
    final week = _selectedWeek;
    if (week == null) return;
    final nextMap = _deepCopyPlanMap(week.recipeIdByDayAndSlot);
    final daySlots = nextMap.putIfAbsent(day, () => <String, String>{});
    if (recipeId == null || recipeId.isEmpty) {
      daySlots.remove(slot);
    } else {
      daySlots[slot] = recipeId;
    }
    await _persistWeek(
      week.copyWith(
        recipeIdByDayAndSlot: nextMap,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _autoGenerateMealPlan() async {
    final week = _selectedWeek;
    if (week == null) return;
    if (!_validateInputsForAction()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fix highlighted inputs to continue.')),
      );
      return;
    }
    final input = _activeInput();
    final metrics = _metricsFromInput(input);
    if (input == null || metrics == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add valid profile details first.')),
      );
      return;
    }
    final candidates = _filteredRecipesForInput(input);
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recipes match your filters right now.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _persistProfileInputs(input);
      final budgets = NutritionCalculator.slotBudgets(
        targetCalories: metrics.targetCalories,
      );
      final nextMap = _deepCopyPlanMap(week.recipeIdByDayAndSlot);
      for (final day in _days) {
        final dayUsed = <String>{};
        for (final slot in _slots) {
          final picked = _pickRecipeForSlot(
            slot: slot,
            targetCalories: budgets[slot] ?? 0,
            candidates: candidates,
            dayUsedRecipeIds: dayUsed,
            currentRecipeId: nextMap[day]?[slot],
          );
          if (picked != null && picked.isNotEmpty) {
            nextMap.putIfAbsent(day, () => <String, String>{})[slot] = picked;
            dayUsed.add(picked);
          }
        }
      }
      final next = week.copyWith(
        recipeIdByDayAndSlot: nextMap,
        bmiX10: (metrics.bmi * 10).round(),
        bmr: metrics.bmr,
        maintenanceCalories: metrics.maintenanceCalories,
        targetCalories: metrics.targetCalories,
        activityLevel: input.activityLevel,
        dietPreference: input.dietPreference,
        allergies: input.allergies,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _persistWeek(next);
      if (!mounted) return;
      setState(() => _applyProfileStateFromInput(input));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal plan generated and profile inputs saved.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerateDay(String day) async {
    final week = _selectedWeek;
    if (week == null) return;
    if (!_validateInputsForAction()) return;
    final input = _activeInput();
    final metrics = _metricsFromInput(input);
    if (input == null || metrics == null) return;
    final candidates = _filteredRecipesForInput(input);
    if (candidates.isEmpty) return;

    setState(() => _busy = true);
    try {
      final budgets = NutritionCalculator.slotBudgets(
        targetCalories: metrics.targetCalories,
      );
      final nextMap = _deepCopyPlanMap(week.recipeIdByDayAndSlot);
      final dayUsed = <String>{};
      for (final slot in _slots) {
        final picked = _pickRecipeForSlot(
          slot: slot,
          targetCalories: budgets[slot] ?? 0,
          candidates: candidates,
          dayUsedRecipeIds: dayUsed,
          currentRecipeId: nextMap[day]?[slot],
        );
        if (picked != null && picked.isNotEmpty) {
          nextMap.putIfAbsent(day, () => <String, String>{})[slot] = picked;
          dayUsed.add(picked);
        }
      }
      await _persistWeek(
        week.copyWith(
          recipeIdByDayAndSlot: nextMap,
          generatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerateSlot(String day, String slot) async {
    final week = _selectedWeek;
    if (week == null) return;
    if (!_validateInputsForAction()) return;
    final input = _activeInput();
    final metrics = _metricsFromInput(input);
    if (input == null || metrics == null) return;
    final candidates = _filteredRecipesForInput(input);
    if (candidates.isEmpty) return;
    final budgets = NutritionCalculator.slotBudgets(
      targetCalories: metrics.targetCalories,
    );
    final nextMap = _deepCopyPlanMap(week.recipeIdByDayAndSlot);
    final dayUsed = Set<String>.from(nextMap[day]?.values ?? const <String>[]);
    dayUsed.remove(nextMap[day]?[slot]);
    final picked = _pickRecipeForSlot(
      slot: slot,
      targetCalories: budgets[slot] ?? 0,
      candidates: candidates,
      dayUsedRecipeIds: dayUsed,
      currentRecipeId: nextMap[day]?[slot],
    );
    if (picked == null || picked.isEmpty) return;
    nextMap.putIfAbsent(day, () => <String, String>{})[slot] = picked;
    await _persistWeek(
      week.copyWith(
        recipeIdByDayAndSlot: nextMap,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _savePlanAndOpenPreview() async {
    final week = _selectedWeek;
    if (!_validateInputsForAction()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fix highlighted inputs before saving.')),
      );
      return;
    }
    final input = _activeInput();
    final metrics = _metricsFromInput(input);
    if (week == null || input == null || metrics == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete profile inputs before saving.')),
      );
      return;
    }
    if (!_hasAnyPlannedMeals(week)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one planned meal first.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _persistProfileInputs(input);

      final next = week.copyWith(
        bmiX10: (metrics.bmi * 10).round(),
        bmr: metrics.bmr,
        maintenanceCalories: metrics.maintenanceCalories,
        targetCalories: metrics.targetCalories,
        activityLevel: input.activityLevel,
        dietPreference: input.dietPreference,
        allergies: input.allergies,
        generatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await _persistWeek(next);
      if (!mounted) return;
      setState(() {
        _applyProfileStateFromInput(input);
        _isEditingPlan = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal plan and profile inputs saved. Review and create habits.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createHabitsFromPreview() async {
    final week = _selectedWeek;
    if (week == null) return;
    if (week.generatedAtMs == null || week.generatedAtMs! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save your meal plan before creating habits.')),
      );
      return;
    }
    if (!_hasAnyPlannedMeals(week)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved meals to create habits from.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _syncMealHabits(week);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Created/updated 4 meal habits.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncMealHabits(MealPrepWeek week) async {
    final allHabits = await HabitStorageService.loadAll();
    for (final slot in _slots) {
      final name = _slotLabels[slot] ?? slot;
      final steps = <HabitActionStep>[];
      final weekdays = <int>{};
      for (final day in _days) {
        final recipeId = week.recipeIdByDayAndSlot[day]?[slot];
        if (recipeId == null || recipeId.isEmpty) continue;
        final recipe = _recipeById(recipeId);
        if (recipe == null) continue;
        final weekday = _weekdayByDay[day];
        if (weekday != null) weekdays.add(weekday);
        final plannerDay = _plannerDayByDay[day];
        final calories = (recipe.macros?.calories ?? 0) > 0
            ? recipe.macros!.calories.round()
            : _fallbackCaloriesForSlot(slot);
        steps.add(
          HabitActionStep(
            id: 'meal-$slot-$day-$recipeId',
            title: recipe.title,
            iconCodePoint: Icons.restaurant_menu.codePoint,
            order: steps.length,
            stepLabel: '$calories kcal',
            productType: name,
            plannerDay: plannerDay,
          ),
        );
      }

      final existing = allHabits.where((h) {
        return (h.templateId ?? '').trim() == _mealPrepTemplateId &&
            h.name.toLowerCase() == name.toLowerCase();
      }).toList();
      final stableId = existing.isNotEmpty
          ? existing.first.id
          : 'meal-habit-$slot-${DateTime.now().millisecondsSinceEpoch}';

      final nextHabit = HabitItem(
        id: stableId,
        name: name,
        category: 'Nutrition',
        frequency: 'Weekly',
        weeklyDays: weekdays.isEmpty
            ? const <int>[
                DateTime.monday,
                DateTime.tuesday,
                DateTime.wednesday,
                DateTime.thursday,
                DateTime.friday,
                DateTime.saturday,
                DateTime.sunday,
              ]
            : (weekdays.toList()..sort()),
        completedDates: existing.isNotEmpty ? existing.first.completedDates : const [],
        actionSteps: steps,
        templateId: _mealPrepTemplateId,
        templateVersion: 1,
      );
      await HabitStorageService.updateHabit(nextHabit);
      developer.log(
        'Meal habit synced',
        name: 'meal_prep.sync',
        error: {
          'habitName': name,
          'steps': steps.length,
          'weeklyDays': nextHabit.weeklyDays,
        },
      );
    }
  }

  Widget _summaryCard(
    BuildContext context, {
    required _NutritionMetrics? metrics,
    required bool isDark,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: AppColors.cloudDecoration(isDark: isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nutrition Summary', style: AppTypography.heading3(context)),
          const SizedBox(height: 12),
          _metricRow(
            context,
            label: 'BMI',
            value: metrics == null ? '--' : metrics.bmi.toStringAsFixed(1),
          ),
          const SizedBox(height: 6),
          _metricRow(
            context,
            label: 'BMR',
            value: metrics == null ? '--' : '${metrics.bmr} kcal',
          ),
          const SizedBox(height: 6),
          _metricRow(
            context,
            label: 'Maintenance',
            value: metrics == null ? '--' : '${metrics.maintenanceCalories} kcal',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetCaloriesCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: 'Target Calories',
              errorText: _targetCaloriesError,
              suffixIcon: IconButton(
                tooltip: 'Save target calories',
                onPressed: _busy ? null : _saveTargetCalories,
                icon: const Icon(Icons.check_circle_outline),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _targetCaloriesError = _validateTargetCalories(
                  value,
                  required: true,
                );
              });
            },
            onSubmitted: (_) => _saveTargetCalories(),
          ),
          const SizedBox(height: 4),
          Text(
            'Default target uses maintenance calories. You can adjust it for gain/loss.',
            style: AppTypography.caption(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value, style: AppTypography.body(context)),
      ],
    );
  }

  Widget _guestMiniForm(BuildContext context, {required bool isDark}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: AppColors.cloudDecoration(isDark: isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile Inputs', style: AppTypography.heading3(context)),
          const SizedBox(height: 8),
          Text(
            'We use these values to calculate maintenance calories.',
            style: AppTypography.caption(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _guestHeightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Height',
                    hintText: '170',
                    suffixText: 'cm',
                    errorText: _guestHeightError,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _guestHeightError = _validateHeightCm(
                        value,
                        required: _showInlineGuestForm,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _guestWeightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Weight',
                    hintText: '70',
                    suffixText: 'kg',
                    errorText: _guestWeightError,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _guestWeightError = _validateWeightKg(
                        value,
                        required: _showInlineGuestForm,
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _guestAgeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Age',
                    errorText: _guestAgeError,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _guestAgeError = _validateAge(
                        value,
                        required: _showInlineGuestForm,
                      );
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 320;
              final children = [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _guestGender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(
                      value: 'prefer_not_to_say',
                      child: Text('Prefer not to say'),
                    ),
                  ],
                  selectedItemBuilder: (context) => const [
                    Text('Male', overflow: TextOverflow.ellipsis, maxLines: 1),
                    Text('Female', overflow: TextOverflow.ellipsis, maxLines: 1),
                    Text('Prefer not', overflow: TextOverflow.ellipsis, maxLines: 1),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _guestGender = v);
                  },
                ),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _guestActivityLevel,
                  decoration: const InputDecoration(labelText: 'Activity'),
                  items: _activityLevels
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            _formatLabel(e),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: (context) => _activityLevels
                      .map(
                        (e) => Text(
                          _formatLabel(e),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _guestActivityLevel = v);
                  },
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    children[0],
                    const SizedBox(height: 8),
                    children[1],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 8),
                  Expanded(child: children[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _guestDiet,
                  decoration: const InputDecoration(labelText: 'Diet'),
                  items: _dietOptions
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(_formatLabel(e)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _guestDiet = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _guestAllergiesCtrl,
                  maxLength: 120,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  decoration: InputDecoration(
                    labelText: 'Allergies (comma separated)',
                    counterText: '',
                    errorText: _guestAllergiesError,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _guestAllergiesError = _validateAllergies(value);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLabel(String value) {
    switch (value) {
      case 'very_active':
        return 'Very Active';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        if (value.isEmpty) return value;
        return value[0].toUpperCase() + value.substring(1).replaceAll('_', ' ');
    }
  }

  Widget _weeklyGrid(
    BuildContext context,
    MealPrepWeek week, {
    required bool isDark,
    required bool editable,
  }) {
    final cs = Theme.of(context).colorScheme;
    const dayWidth = 180.0;
    const firstColWidth = 108.0;
    return Container(
      decoration: AppColors.cloudDecoration(isDark: isDark),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Weekly Plan', style: AppTypography.heading3(context)),
              ),
              IconButton(
                tooltip: 'Regenerate all',
                onPressed: (!editable || _busy) ? null : _autoGenerateMealPlan,
                icon: const Icon(Icons.auto_fix_high_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: firstColWidth + (dayWidth * _days.length),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: firstColWidth,
                        child: Text(
                          'Meal',
                          style: AppTypography.caption(context).copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      for (final day in _days)
                        SizedBox(
                          width: dayWidth,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dayLabels[day] ?? day,
                                  style: AppTypography.caption(context).copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Regenerate day',
                                visualDensity: VisualDensity.compact,
                                onPressed: (!editable || _busy)
                                    ? null
                                    : () => _regenerateDay(day),
                                icon: const Icon(Icons.refresh, size: 18),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final slot in _slots)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: firstColWidth,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _slotLabels[slot] ?? slot,
                                style: AppTypography.bodySmall(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          for (final day in _days)
                            SizedBox(
                              width: dayWidth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      DropdownButtonFormField<String>(
                                        key: ValueKey<String>(
                                          '$day-$slot-${week.recipeIdByDayAndSlot[day]?[slot] ?? ''}',
                                        ),
                                        isExpanded: true,
                                        initialValue: week.recipeIdByDayAndSlot[day]?[slot],
                                        hint: const Text('Select recipe'),
                                        items: _recipes
                                            .map(
                                              (r) => DropdownMenuItem<String>(
                                                value: r.id,
                                                child: Text(
                                                  r.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (_busy || !editable)
                                            ? null
                                            : (value) => _assignRecipeForSlot(day, slot, value),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: (_busy || !editable)
                                                  ? null
                                                  : () => _assignRecipeForSlot(day, slot, null),
                                              child: const Text('Clear'),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Regenerate slot',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: (_busy || !editable)
                                                ? null
                                                : () => _regenerateSlot(day, slot),
                                            icon: const Icon(Icons.shuffle, size: 18),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
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

  Widget _dayWisePreview(
    BuildContext context,
    MealPrepWeek week, {
    required bool isDark,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: AppColors.cloudDecoration(isDark: isDark),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Meal Plan Preview', style: AppTypography.heading3(context)),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _isEditingPlan = true);
                      },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final day in _days)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayLabels[day] ?? day,
                      style: AppTypography.body(context).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final slot in _slots)
                      Builder(
                        builder: (_) {
                          final recipeId = week.recipeIdByDayAndSlot[day]?[slot];
                          final recipe =
                              recipeId == null ? null : _recipeById(recipeId);
                          final calories = (recipe?.macros?.calories ?? 0) > 0
                              ? '${recipe!.macros!.calories.round()} kcal'
                              : '--';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    _slotLabels[slot] ?? slot,
                                    style: AppTypography.caption(context).copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    recipe?.title ?? 'Not planned',
                                    style: AppTypography.bodySmall(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  calories,
                                  style: AppTypography.caption(context).copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final week = _selectedWeek;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final input = _activeInput();
    final metrics = _metricsFromInput(input);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Meal Prep'),
      ),
      body: _loading || week == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: AppColors.skyDecoration(isDark: isDark),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Week of ${week.weekStartDateIso}',
                    style: AppTypography.heading2(context),
                  ),
                  const SizedBox(height: 12),
                  _summaryCard(context, metrics: metrics, isDark: isDark),
                  const SizedBox(height: 12),
                  if (_showInlineGuestForm) ...[
                    _guestMiniForm(context, isDark: isDark),
                    const SizedBox(height: 12),
                  ],
                  if (_isEditingPlan) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _autoGenerateMealPlan,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(
                          _busy ? 'Generating...' : 'Auto Generate Meal Plan',
                          style: AppTypography.button(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _savePlanAndOpenPreview,
                        child: Text('Save Plan', style: AppTypography.button(context)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _weeklyGrid(context, week, isDark: isDark, editable: true),
                  ] else ...[
                    _dayWisePreview(context, week, isDark: isDark),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _createHabitsFromPreview,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text('Create Habits', style: AppTypography.button(context)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _weeklyGrid(context, week, isDark: isDark, editable: false),
                  ],
                ],
              ),
            ),
    );
  }
}

class _NutritionInput {
  final double heightCm;
  final double weightKg;
  final int ageYears;
  final String gender;
  final String activityLevel;
  final String dietPreference;
  final List<String> allergies;

  const _NutritionInput({
    required this.heightCm,
    required this.weightKg,
    required this.ageYears,
    required this.gender,
    required this.activityLevel,
    required this.dietPreference,
    required this.allergies,
  });
}

class _NutritionMetrics {
  final double bmi;
  final int bmr;
  final int maintenanceCalories;
  final int targetCalories;

  const _NutritionMetrics({
    required this.bmi,
    required this.bmr,
    required this.maintenanceCalories,
    required this.targetCalories,
  });
}
