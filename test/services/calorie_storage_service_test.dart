import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:digital_vision_board/models/calorie_entry.dart';
import 'package:digital_vision_board/services/calorie_storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('loadToday()', () {
    test('empty storage → calories=0, goal=2000, foodItems=[]', () async {
      final entry = await CalorieStorageService.loadToday();
      expect(entry.calories, 0);
      expect(entry.goal, 2000);
      expect(entry.foodItems, isEmpty);
    });

    test('returns today\'s entry from populated storage', () async {
      final todayKey = CalorieEntry.todayKey();
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.save(
        CalorieEntry(dateKey: todayKey, calories: 800, goal: 1800),
        prefs: prefs,
      );
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.calories, 800);
      expect(entry.goal, 1800);
    });

    test('ignores entries for other dates', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.save(
        const CalorieEntry(dateKey: '2020-01-01', calories: 9999),
        prefs: prefs,
      );
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.calories, 0);
      expect(entry.dateKey, CalorieEntry.todayKey());
    });
  });

  group('addCalories()', () {
    test('increments today\'s calories', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.addCalories(300, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.calories, 300);
    });

    test('accumulates multiple additions', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.addCalories(100, prefs: prefs);
      await CalorieStorageService.addCalories(200, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.calories, 300);
    });

    test('clamps result at goal×3', () async {
      final prefs = await SharedPreferences.getInstance();
      // Default goal is 2000; max = 6000
      await CalorieStorageService.addCalories(10000, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.calories, 6000);
    });

    test('persists to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.addCalories(500, prefs: prefs);
      // Load fresh from the same prefs instance
      final all = await CalorieStorageService.loadAll(prefs: prefs);
      final todayKey = CalorieEntry.todayKey();
      final today = all.firstWhere((e) => e.dateKey == todayKey);
      expect(today.calories, 500);
    });
  });

  group('addFoodItem()', () {
    const testItem = FoodLogItem(
      foodName: 'Banana',
      qty: 1.0,
      qtyUnit: 'serving',
      calories: 89,
      proteinG: 1.1,
      carbsG: 23.0,
      fatG: 0.3,
    );

    test('appends FoodLogItem to foodItems', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.addFoodItem(testItem, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.foodItems.length, 1);
      expect(entry.foodItems[0].foodName, 'Banana');
    });

    test('adds item.calories to entry.calories', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.addCalories(200, prefs: prefs);
      await CalorieStorageService.addFoodItem(testItem, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.calories, 289);
    });

    test('clamps total at goal×3', () async {
      final prefs = await SharedPreferences.getInstance();
      // Add 5950 first (just below 6000 default max)
      await CalorieStorageService.addCalories(5950, prefs: prefs);
      const bigItem = FoodLogItem(foodName: 'Big', calories: 500);
      await CalorieStorageService.addFoodItem(bigItem, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.calories, 6000);
    });

    test('persists updated entry', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.addFoodItem(testItem, prefs: prefs);
      // Re-load to confirm persistence
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.foodItems.isNotEmpty, isTrue);
    });
  });

  group('resetToday()', () {
    test('calories → 0, foodItems → []', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.addCalories(800, prefs: prefs);
      await CalorieStorageService.addFoodItem(
        const FoodLogItem(foodName: 'Test', calories: 100),
        prefs: prefs,
      );
      await CalorieStorageService.resetToday(prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.calories, 0);
      expect(entry.foodItems, isEmpty);
    });

    test('persists reset entry', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.addCalories(500, prefs: prefs);
      await CalorieStorageService.resetToday(prefs: prefs);
      final all = await CalorieStorageService.loadAll(prefs: prefs);
      final todayKey = CalorieEntry.todayKey();
      final today = all.firstWhere((e) => e.dateKey == todayKey);
      expect(today.calories, 0);
    });
  });

  group('updateGoal()', () {
    test('updates goal value', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.updateGoal(2500, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.goal, 2500);
    });

    test('clamps goal to minimum 500', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.updateGoal(100, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.goal, 500);
    });

    test('clamps goal to maximum 10000', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.updateGoal(99999, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.goal, 10000);
    });

    test('does not alter calories or foodItems', () async {
      final prefs = await SharedPreferences.getInstance();
      await CalorieStorageService.addCalories(400, prefs: prefs);
      await CalorieStorageService.addFoodItem(
        const FoodLogItem(foodName: 'Apple', calories: 80),
        prefs: prefs,
      );
      await CalorieStorageService.updateGoal(1800, prefs: prefs);
      final entry = await CalorieStorageService.loadToday(prefs: prefs);
      expect(entry.calories, 480);
      expect(entry.foodItems.length, 1);
    });
  });
}
