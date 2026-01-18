import '../core_value.dart';

final class WizardCoreValueCatalog {
  /// Default predefined categories per core value id.
  static const Map<String, List<String>> predefinedCategories = {
    CoreValues.growthMindset: [
      'Health',
      'Learning',
      'Mindfulness',
      'Confidence',
    ],
    CoreValues.careerAmbition: [
      'Skills',
      'Promotion',
      'Income',
      'Leadership',
    ],
    CoreValues.creativityExpression: [
      'Art',
      'Writing',
      'Music',
      'Content',
    ],
    CoreValues.lifestyleAdventure: [
      'Travel',
      'Fitness',
      'Experiences',
      'Home',
    ],
    CoreValues.connectionCommunity: [
      'Family',
      'Friends',
      'Community',
      'Relationships',
    ],
  };

  static List<String> defaultsFor(String coreValueId) {
    return List<String>.from(predefinedCategories[coreValueId] ?? const <String>[]);
  }
}

