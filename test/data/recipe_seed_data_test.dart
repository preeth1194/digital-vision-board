import 'package:flutter_test/flutter_test.dart';

import 'package:digital_vision_board/data/recipe_seed_data.dart';

void main() {
  group('RecipeSeedData.catalog', () {
    test('contains exactly 10 recipes', () {
      expect(RecipeSeedData.catalog.length, 10);
    });

    test('all isCatalog == true', () {
      for (final recipe in RecipeSeedData.catalog) {
        expect(recipe.isCatalog, isTrue,
            reason: 'Recipe "${recipe.id}" has isCatalog=false');
      }
    });

    test('all ids are unique', () {
      final ids = RecipeSeedData.catalog.map((r) => r.id).toList();
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, ids.length,
          reason: 'Duplicate IDs found: ${ids.where((id) => ids.where((i) => i == id).length > 1).toSet()}');
    });

    test('all have non-empty id, title, cuisine', () {
      for (final recipe in RecipeSeedData.catalog) {
        expect(recipe.id.isNotEmpty, isTrue,
            reason: 'A recipe has an empty id');
        expect(recipe.title.isNotEmpty, isTrue,
            reason: 'Recipe "${recipe.id}" has an empty title');
        expect(recipe.cuisine.isNotEmpty, isTrue,
            reason: 'Recipe "${recipe.id}" has an empty cuisine');
      }
    });

    test('all have ≥1 ingredient', () {
      for (final recipe in RecipeSeedData.catalog) {
        expect(recipe.ingredients.isNotEmpty, isTrue,
            reason: 'Recipe "${recipe.id}" has no ingredients');
      }
    });

    test('all have ≥1 method step', () {
      for (final recipe in RecipeSeedData.catalog) {
        expect(recipe.methodSteps.isNotEmpty, isTrue,
            reason: 'Recipe "${recipe.id}" has no method steps');
      }
    });

    test('all have macros != null', () {
      for (final recipe in RecipeSeedData.catalog) {
        expect(recipe.macros, isNotNull,
            reason: 'Recipe "${recipe.id}" has null macros');
      }
    });

    test('all have macros.calories > 0', () {
      for (final recipe in RecipeSeedData.catalog) {
        expect(recipe.macros!.calories, greaterThan(0),
            reason: 'Recipe "${recipe.id}" has 0 calories');
      }
    });

    test('all have macros.proteinG > 0', () {
      for (final recipe in RecipeSeedData.catalog) {
        expect(recipe.macros!.proteinG, greaterThan(0),
            reason: 'Recipe "${recipe.id}" has 0 protein');
      }
    });
  });
}
