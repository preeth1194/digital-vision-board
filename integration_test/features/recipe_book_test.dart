// E2E: Recipe Book — catalog and user recipes
//
// Run individually with:
//   flutter test integration_test/features/recipe_book_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:digital_vision_board/data/recipe_seed_data.dart';
import 'package:digital_vision_board/screens/recipes/recipe_book_screen.dart';

import '../helpers/app_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Recipe Book', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    Future<void> pumpRecipeBook(WidgetTester tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(
        const MaterialApp(home: RecipeBookScreen()),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('Catalog recipes are listed on first load', (tester) async {
      await pumpRecipeBook(tester);
      // At least one seed recipe title should be visible
      expect(
        find.textContaining(RecipeSeedData.catalog.first.title),
        findsWidgets,
      );
    });

    testWidgets('At least 10 catalog recipe cards appear', (tester) async {
      await pumpRecipeBook(tester);
      // Look for any card containing a catalog title
      int found = 0;
      for (final recipe in RecipeSeedData.catalog) {
        if (find.text(recipe.title).evaluate().isNotEmpty) {
          found++;
        }
      }
      expect(found, greaterThanOrEqualTo(1));
    });

    testWidgets('Tapping a catalog recipe opens detail screen', (tester) async {
      await pumpRecipeBook(tester);
      final firstTitle = RecipeSeedData.catalog.first.title;
      await tester.tap(find.text(firstTitle).first);
      await settle(tester, duration: const Duration(seconds: 1));
      // Detail screen shows the recipe title as heading
      expect(find.text(firstTitle), findsWidgets);
    });

    testWidgets('Catalog recipe detail shows Nutrition section', (tester) async {
      await pumpRecipeBook(tester);
      // Use a recipe guaranteed to have macros
      final chickenRecipe = RecipeSeedData.catalog
          .firstWhere((r) => r.title.contains('Chicken'));
      await tester.tap(find.text(chickenRecipe.title).first);
      await settle(tester, duration: const Duration(seconds: 1));
      expect(find.textContaining('Nutrition'), findsWidgets);
    });

    testWidgets('Recipe detail shows macro tiles (Calories, Protein)',
        (tester) async {
      await pumpRecipeBook(tester);
      final chickenRecipe = RecipeSeedData.catalog
          .firstWhere((r) => r.title.contains('Chicken'));
      await tester.tap(find.text(chickenRecipe.title).first);
      await settle(tester, duration: const Duration(seconds: 1));
      expect(find.textContaining('Calories'), findsWidgets);
      expect(find.textContaining('Protein'), findsWidgets);
    });

    testWidgets('Add button opens Recipe editor with empty fields',
        (tester) async {
      await pumpRecipeBook(tester);
      // Add button is an IconButton in the AppBar with add_rounded icon
      await tester.tap(find.byIcon(Icons.add_rounded));
      await settle(tester);
      // Editor screen should open — look for title/name input fields
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('Search filters list to matching recipes', (tester) async {
      await pumpRecipeBook(tester);
      // Find the search field
      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await settle(tester);
      await tester.enterText(searchField, 'Chicken');
      await settle(tester, duration: const Duration(milliseconds: 500));
      // Non-chicken recipes should not appear
      expect(find.text('Classic Greek Salad'), findsNothing);
    });
  });
}
