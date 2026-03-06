import 'recipe.dart';

class RecipeBook {
  final String id;
  final String title;
  final List<String> recipeIds;

  const RecipeBook({
    required this.id,
    required this.title,
    required this.recipeIds,
  });

  RecipeBook copyWith({String? id, String? title, List<String>? recipeIds}) {
    return RecipeBook(
      id: id ?? this.id,
      title: title ?? this.title,
      recipeIds: recipeIds ?? this.recipeIds,
    );
  }

  List<Recipe> recipesFrom(List<Recipe> all) {
    final byId = {for (final r in all) r.id: r};
    final out = <Recipe>[];
    for (final id in recipeIds) {
      final r = byId[id];
      if (r != null) out.add(r);
    }
    return out;
  }
}
