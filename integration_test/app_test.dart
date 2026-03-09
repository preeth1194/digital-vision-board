// Integration test entry point.
//
// Run with:
//   flutter test integration_test/app_test.dart
//
// Requires a connected device or emulator.

import 'package:integration_test/integration_test.dart';

import 'features/calorie_tracker_test.dart' as calorie_tracker;
import 'features/recipe_book_test.dart' as recipe_book;
import 'features/workout_preset_test.dart' as workout_preset;
import 'features/default_badges_test.dart' as default_badges;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Run all feature test groups
  calorie_tracker.main();
  recipe_book.main();
  workout_preset.main();
  default_badges.main();
}
