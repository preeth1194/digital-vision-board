import 'package:flutter_test/flutter_test.dart';

import 'package:digital_vision_board/models/calorie_entry.dart';

void main() {
  group('FoodLogItem', () {
    test('hasMacros false when protein/carbs/fat all null', () {
      const item = FoodLogItem(foodName: 'Apple', calories: 80);
      expect(item.hasMacros, isFalse);
    });

    test('hasMacros true when proteinG set', () {
      const item = FoodLogItem(foodName: 'Egg', calories: 70, proteinG: 6);
      expect(item.hasMacros, isTrue);
    });

    test('hasMacros true when carbsG set', () {
      const item = FoodLogItem(foodName: 'Rice', calories: 200, carbsG: 45);
      expect(item.hasMacros, isTrue);
    });

    test('hasMacros true when fatG set', () {
      const item = FoodLogItem(foodName: 'Butter', calories: 100, fatG: 11);
      expect(item.hasMacros, isTrue);
    });

    test('toJson omits null macro fields', () {
      const item = FoodLogItem(foodName: 'Apple', calories: 80);
      final json = item.toJson();
      expect(json.containsKey('proteinG'), isFalse);
      expect(json.containsKey('carbsG'), isFalse);
      expect(json.containsKey('fatG'), isFalse);
      expect(json.containsKey('fiberG'), isFalse);
      expect(json.containsKey('sodiumMg'), isFalse);
      expect(json.containsKey('sugarG'), isFalse);
    });

    test('toJson includes macro fields when present', () {
      const item = FoodLogItem(
        foodName: 'Chicken',
        calories: 165,
        proteinG: 31,
        carbsG: 0,
        fatG: 3.6,
      );
      final json = item.toJson();
      expect(json['proteinG'], 31.0);
      expect(json['carbsG'], 0.0);
      expect(json['fatG'], 3.6);
    });

    test('fromJson defaults: qty=1.0, qtyUnit=serving, calories=0', () {
      final item = FoodLogItem.fromJson({'foodName': 'Test'});
      expect(item.qty, 1.0);
      expect(item.qtyUnit, 'serving');
      expect(item.calories, 0);
    });

    test('fromJson with all fields', () {
      final json = {
        'foodName': 'Salmon',
        'qty': 2.0,
        'qtyUnit': 'g',
        'calories': 400,
        'proteinG': 40.0,
        'carbsG': 0.0,
        'fatG': 24.0,
        'fiberG': 0.0,
        'sodiumMg': 100.0,
        'sugarG': 0.0,
      };
      final item = FoodLogItem.fromJson(json);
      expect(item.foodName, 'Salmon');
      expect(item.qty, 2.0);
      expect(item.qtyUnit, 'g');
      expect(item.calories, 400);
      expect(item.proteinG, 40.0);
    });

    test('roundtrip preserves all values', () {
      const original = FoodLogItem(
        foodName: 'Oats',
        qty: 0.5,
        qtyUnit: 'cup',
        calories: 150,
        proteinG: 5,
        carbsG: 27,
        fatG: 2.5,
        fiberG: 4,
        sodiumMg: 5,
        sugarG: 1,
      );
      final roundtripped = FoodLogItem.fromJson(original.toJson());
      expect(roundtripped.foodName, original.foodName);
      expect(roundtripped.qty, original.qty);
      expect(roundtripped.qtyUnit, original.qtyUnit);
      expect(roundtripped.calories, original.calories);
      expect(roundtripped.proteinG, original.proteinG);
      expect(roundtripped.carbsG, original.carbsG);
      expect(roundtripped.fatG, original.fatG);
      expect(roundtripped.fiberG, original.fiberG);
      expect(roundtripped.sodiumMg, original.sodiumMg);
      expect(roundtripped.sugarG, original.sugarG);
    });
  });

  group('CalorieEntry', () {
    test("todayKey() format matches 'yyyy-MM-dd' regex", () {
      final key = CalorieEntry.todayKey();
      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      expect(regex.hasMatch(key), isTrue);
    });

    test('totalProteinG sums proteinG across items (nulls treated as 0)', () {
      final entry = CalorieEntry(
        dateKey: '2024-01-01',
        calories: 0,
        foodItems: [
          const FoodLogItem(foodName: 'A', calories: 100, proteinG: 10),
          const FoodLogItem(foodName: 'B', calories: 50),
          const FoodLogItem(foodName: 'C', calories: 80, proteinG: 5),
        ],
      );
      expect(entry.totalProteinG, 15.0);
    });

    test('totalCarbsG sums carbsG across items', () {
      final entry = CalorieEntry(
        dateKey: '2024-01-01',
        calories: 0,
        foodItems: [
          const FoodLogItem(foodName: 'A', calories: 100, carbsG: 20),
          const FoodLogItem(foodName: 'B', calories: 50, carbsG: 10),
        ],
      );
      expect(entry.totalCarbsG, 30.0);
    });

    test('totalFatG sums fatG across items', () {
      final entry = CalorieEntry(
        dateKey: '2024-01-01',
        calories: 0,
        foodItems: [
          const FoodLogItem(foodName: 'A', calories: 100, fatG: 5),
          const FoodLogItem(foodName: 'B', calories: 50, fatG: 3),
        ],
      );
      expect(entry.totalFatG, 8.0);
    });

    test('hasMacroData false when foodItems empty', () {
      const entry = CalorieEntry(dateKey: '2024-01-01', calories: 0);
      expect(entry.hasMacroData, isFalse);
    });

    test('hasMacroData false when no item has macros', () {
      final entry = CalorieEntry(
        dateKey: '2024-01-01',
        calories: 0,
        foodItems: [
          const FoodLogItem(foodName: 'A', calories: 100),
          const FoodLogItem(foodName: 'B', calories: 50),
        ],
      );
      expect(entry.hasMacroData, isFalse);
    });

    test('hasMacroData true when at least one item has macros', () {
      final entry = CalorieEntry(
        dateKey: '2024-01-01',
        calories: 0,
        foodItems: [
          const FoodLogItem(foodName: 'A', calories: 100),
          const FoodLogItem(foodName: 'B', calories: 50, proteinG: 5),
        ],
      );
      expect(entry.hasMacroData, isTrue);
    });

    test('copyWith replaces calories independently', () {
      const entry = CalorieEntry(
        dateKey: '2024-01-01',
        calories: 500,
        goal: 2000,
      );
      final updated = entry.copyWith(calories: 800);
      expect(updated.calories, 800);
      expect(updated.goal, 2000);
      expect(updated.dateKey, '2024-01-01');
    });

    test('copyWith replaces goal independently', () {
      const entry = CalorieEntry(
        dateKey: '2024-01-01',
        calories: 500,
        goal: 2000,
      );
      final updated = entry.copyWith(goal: 2500);
      expect(updated.goal, 2500);
      expect(updated.calories, 500);
    });

    test('copyWith replaces foodItems independently', () {
      final entry = CalorieEntry(
        dateKey: '2024-01-01',
        calories: 500,
        foodItems: [const FoodLogItem(foodName: 'A', calories: 100)],
      );
      final updated = entry.copyWith(foodItems: []);
      expect(updated.foodItems, isEmpty);
      expect(updated.calories, 500);
    });

    test('roundtrip toJson→fromJson with foodItems list', () {
      final entry = CalorieEntry(
        dateKey: '2024-03-15',
        calories: 1200,
        goal: 2000,
        foodItems: [
          const FoodLogItem(
            foodName: 'Chicken',
            qty: 1.5,
            qtyUnit: 'serving',
            calories: 247,
            proteinG: 46,
            carbsG: 0,
            fatG: 5,
          ),
        ],
      );
      final roundtripped = CalorieEntry.fromJson(entry.toJson());
      expect(roundtripped.dateKey, entry.dateKey);
      expect(roundtripped.calories, entry.calories);
      expect(roundtripped.goal, entry.goal);
      expect(roundtripped.foodItems.length, 1);
      expect(roundtripped.foodItems[0].foodName, 'Chicken');
      expect(roundtripped.foodItems[0].proteinG, 46.0);
    });

    test('fromJson with no foodItems key → empty list default', () {
      final json = {
        'dateKey': '2024-01-01',
        'calories': 300,
        'goal': 2000,
      };
      final entry = CalorieEntry.fromJson(json);
      expect(entry.foodItems, isEmpty);
    });
  });
}
