import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:digital_vision_board/data/recipe_seed_data.dart';
import 'package:digital_vision_board/models/recipe.dart';
import 'package:digital_vision_board/services/recipe_storage_service.dart';

Recipe _makeUserRecipe({
  String id = 'user_test_1',
  String title = 'My Recipe',
  int updatedAtMs = 1000,
}) {
  return Recipe(
    id: id,
    title: title,
    cuisine: 'Test',
    ingredients: ['Ingredient 1'],
    methodSteps: ['Step 1'],
    updatedAtMs: updatedAtMs,
    isCatalog: false,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('loadAll()', () {
    test('empty storage → returns only catalog recipes (10)', () async {
      final prefs = await SharedPreferences.getInstance();
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      expect(all.length, RecipeSeedData.catalog.length);
      expect(all.length, 10);
    });

    test('user recipes appear before catalog recipes', () async {
      final prefs = await SharedPreferences.getInstance();
      await RecipeStorageService.upsertRecipe(
        _makeUserRecipe(id: 'user_1', title: 'User Recipe'),
        prefs: prefs,
      );
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      expect(all.first.isCatalog, isFalse);
      expect(all.first.id, 'user_1');
    });

    test('user recipes sorted by updatedAtMs descending', () async {
      final prefs = await SharedPreferences.getInstance();
      // Upsert in order; upsertRecipe refreshes updatedAtMs so we rely on order
      await RecipeStorageService.upsertRecipe(
        _makeUserRecipe(id: 'user_a', title: 'Recipe A'),
        prefs: prefs,
      );
      await Future.delayed(const Duration(milliseconds: 5));
      await RecipeStorageService.upsertRecipe(
        _makeUserRecipe(id: 'user_b', title: 'Recipe B'),
        prefs: prefs,
      );
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      final userRecipes = all.where((r) => !r.isCatalog).toList();
      expect(userRecipes.length, 2);
      // Most recently updated (user_b) should be first
      expect(userRecipes[0].id, 'user_b');
      expect(userRecipes[1].id, 'user_a');
    });
  });

  group('upsertRecipe()', () {
    test('inserts new recipe with isCatalog=false', () async {
      final prefs = await SharedPreferences.getInstance();
      await RecipeStorageService.upsertRecipe(
        _makeUserRecipe(id: 'new_recipe'),
        prefs: prefs,
      );
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      final inserted = all.firstWhere((r) => r.id == 'new_recipe');
      expect(inserted.isCatalog, isFalse);
    });

    test('updates existing recipe by id', () async {
      final prefs = await SharedPreferences.getInstance();
      await RecipeStorageService.upsertRecipe(
        _makeUserRecipe(id: 'update_me', title: 'Original'),
        prefs: prefs,
      );
      await RecipeStorageService.upsertRecipe(
        _makeUserRecipe(id: 'update_me', title: 'Updated'),
        prefs: prefs,
      );
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      final userRecipes = all.where((r) => r.id == 'update_me').toList();
      expect(userRecipes.length, 1);
      expect(userRecipes[0].title, 'Updated');
    });

    test('refreshes updatedAtMs on upsert', () async {
      final prefs = await SharedPreferences.getInstance();
      final before = DateTime.now().millisecondsSinceEpoch;
      await RecipeStorageService.upsertRecipe(
        _makeUserRecipe(id: 'timestamp_test'),
        prefs: prefs,
      );
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      final inserted = all.firstWhere((r) => r.id == 'timestamp_test');
      expect(inserted.updatedAtMs, greaterThanOrEqualTo(before));
    });

    test('catalog recipes are never written to user storage', () async {
      final prefs = await SharedPreferences.getInstance();
      // Upsert a catalog-flagged recipe — service should force isCatalog=false
      await RecipeStorageService.upsertRecipe(
        Recipe(
          id: 'catalog_test',
          title: 'Catalog Test',
          updatedAtMs: 0,
          isCatalog: true,
        ),
        prefs: prefs,
      );
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      final found = all.firstWhere((r) => r.id == 'catalog_test');
      // upsertRecipe forces isCatalog: false
      expect(found.isCatalog, isFalse);
    });
  });

  group('deleteRecipe()', () {
    test('removes recipe by matching id', () async {
      final prefs = await SharedPreferences.getInstance();
      await RecipeStorageService.upsertRecipe(
        _makeUserRecipe(id: 'to_delete'),
        prefs: prefs,
      );
      await RecipeStorageService.deleteRecipe('to_delete', prefs: prefs);
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      expect(all.any((r) => r.id == 'to_delete'), isFalse);
    });

    test('no-op when id not found', () async {
      final prefs = await SharedPreferences.getInstance();
      await RecipeStorageService.upsertRecipe(
        _makeUserRecipe(id: 'keep_me'),
        prefs: prefs,
      );
      await RecipeStorageService.deleteRecipe('nonexistent_id', prefs: prefs);
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      expect(all.any((r) => r.id == 'keep_me'), isTrue);
    });

    test('catalog recipes unaffected (not in user storage)', () async {
      final prefs = await SharedPreferences.getInstance();
      final catalogId = RecipeSeedData.catalog.first.id;
      await RecipeStorageService.deleteRecipe(catalogId, prefs: prefs);
      final all = await RecipeStorageService.loadAll(prefs: prefs);
      // Catalog recipe should still be present
      expect(all.any((r) => r.id == catalogId), isTrue);
    });
  });
}
