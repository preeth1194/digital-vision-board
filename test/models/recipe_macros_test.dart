import 'package:flutter_test/flutter_test.dart';

import 'package:digital_vision_board/models/recipe.dart';

void main() {
  group('RecipeMacros', () {
    test('isEmpty → true when all fields zero', () {
      const m = RecipeMacros();
      expect(m.isEmpty, isTrue);
    });

    test('isEmpty → false when calories non-zero', () {
      const m = RecipeMacros(calories: 100);
      expect(m.isEmpty, isFalse);
    });

    test('isEmpty → false when proteinG non-zero', () {
      const m = RecipeMacros(proteinG: 10);
      expect(m.isEmpty, isFalse);
    });

    test('isEmpty → false when carbsG non-zero', () {
      const m = RecipeMacros(carbsG: 5);
      expect(m.isEmpty, isFalse);
    });

    test('isEmpty → false when fatG non-zero', () {
      const m = RecipeMacros(fatG: 3);
      expect(m.isEmpty, isFalse);
    });

    test('copyWith overrides selected fields; others unchanged', () {
      const original = RecipeMacros(
        calories: 500,
        proteinG: 30,
        carbsG: 60,
        fatG: 15,
        fiberG: 8,
        sodiumMg: 400,
        sugarG: 10,
      );
      final copy = original.copyWith(calories: 600, proteinG: 35);
      expect(copy.calories, 600);
      expect(copy.proteinG, 35);
      expect(copy.carbsG, 60);
      expect(copy.fatG, 15);
      expect(copy.fiberG, 8);
      expect(copy.sodiumMg, 400);
      expect(copy.sugarG, 10);
    });

    test('copyWith with no arguments returns identical values', () {
      const original = RecipeMacros(calories: 300, proteinG: 20);
      final copy = original.copyWith();
      expect(copy.calories, original.calories);
      expect(copy.proteinG, original.proteinG);
    });

    test('toJson serialises all 7 fields', () {
      const m = RecipeMacros(
        calories: 400,
        proteinG: 25,
        carbsG: 50,
        fatG: 12,
        fiberG: 6,
        sodiumMg: 300,
        sugarG: 8,
      );
      final json = m.toJson();
      expect(json['calories'], 400.0);
      expect(json['proteinG'], 25.0);
      expect(json['carbsG'], 50.0);
      expect(json['fatG'], 12.0);
      expect(json['fiberG'], 6.0);
      expect(json['sodiumMg'], 300.0);
      expect(json['sugarG'], 8.0);
    });

    test('fromJson deserialises all fields', () {
      final json = {
        'calories': 400,
        'proteinG': 25,
        'carbsG': 50,
        'fatG': 12,
        'fiberG': 6,
        'sodiumMg': 300,
        'sugarG': 8,
      };
      final m = RecipeMacros.fromJson(json);
      expect(m.calories, 400.0);
      expect(m.proteinG, 25.0);
      expect(m.carbsG, 50.0);
      expect(m.fatG, 12.0);
      expect(m.fiberG, 6.0);
      expect(m.sodiumMg, 300.0);
      expect(m.sugarG, 8.0);
    });

    test('fromJson missing fields default to 0', () {
      final m = RecipeMacros.fromJson({});
      expect(m.calories, 0.0);
      expect(m.proteinG, 0.0);
      expect(m.carbsG, 0.0);
      expect(m.fatG, 0.0);
      expect(m.fiberG, 0.0);
      expect(m.sodiumMg, 0.0);
      expect(m.sugarG, 0.0);
    });

    test('roundtrip toJson→fromJson preserves values', () {
      const original = RecipeMacros(
        calories: 350,
        proteinG: 22,
        carbsG: 45,
        fatG: 10,
        fiberG: 5,
        sodiumMg: 250,
        sugarG: 7,
      );
      final roundtripped = RecipeMacros.fromJson(original.toJson());
      expect(roundtripped.calories, original.calories);
      expect(roundtripped.proteinG, original.proteinG);
      expect(roundtripped.carbsG, original.carbsG);
      expect(roundtripped.fatG, original.fatG);
      expect(roundtripped.fiberG, original.fiberG);
      expect(roundtripped.sodiumMg, original.sodiumMg);
      expect(roundtripped.sugarG, original.sugarG);
    });
  });

  group('Recipe macros integration', () {
    Recipe _baseRecipe() => Recipe(
          id: 'test_1',
          title: 'Test Recipe',
          updatedAtMs: 0,
        );

    test('fromJson with no macros key → recipe.macros == null', () {
      final json = {
        'id': 'r1',
        'title': 'No Macros',
        'updatedAtMs': 0,
      };
      final recipe = Recipe.fromJson(json);
      expect(recipe.macros, isNull);
    });

    test('fromJson with valid macros map → RecipeMacros instance', () {
      final json = {
        'id': 'r2',
        'title': 'With Macros',
        'updatedAtMs': 0,
        'macros': {'calories': 500, 'proteinG': 30, 'carbsG': 60, 'fatG': 15},
      };
      final recipe = Recipe.fromJson(json);
      expect(recipe.macros, isNotNull);
      expect(recipe.macros!.calories, 500.0);
      expect(recipe.macros!.proteinG, 30.0);
    });

    test('toJson includes macros when macros != null', () {
      final recipe = _baseRecipe().copyWith(
        macros: const RecipeMacros(calories: 300, proteinG: 20),
      );
      final json = recipe.toJson();
      expect(json['macros'], isNotNull);
      expect((json['macros'] as Map)['calories'], 300.0);
    });

    test('toJson has macros key as null when macros == null', () {
      final recipe = _baseRecipe();
      final json = recipe.toJson();
      // key exists but value is null
      expect(json.containsKey('macros'), isTrue);
      expect(json['macros'], isNull);
    });

    test('copyWith(macros:…) replaces macros', () {
      final recipe = _baseRecipe().copyWith(
        macros: const RecipeMacros(calories: 100),
      );
      final updated = recipe.copyWith(macros: const RecipeMacros(calories: 999));
      expect(updated.macros!.calories, 999.0);
    });

    test('copyWith(clearMacros: true) nullifies macros', () {
      final recipe = _baseRecipe().copyWith(
        macros: const RecipeMacros(calories: 100),
      );
      final cleared = recipe.copyWith(clearMacros: true);
      expect(cleared.macros, isNull);
    });
  });
}
