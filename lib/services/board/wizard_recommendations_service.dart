import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dv_auth_service.dart';

final class WizardRecommendedHabit {
  final String name;
  final String? frequency; // 'Daily' | 'Weekly' | null
  final Map<String, dynamic>? cbtEnhancements;

  const WizardRecommendedHabit({
    required this.name,
    required this.frequency,
    required this.cbtEnhancements,
  });

  static WizardRecommendedHabit? fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final freq = (json['frequency'] as String?)?.trim();
    final cbt = json['cbtEnhancements'];
    return WizardRecommendedHabit(
      name: name,
      frequency: (freq == null || freq.isEmpty) ? null : freq,
      cbtEnhancements: (cbt is Map<String, dynamic>) ? cbt : null,
    );
  }
}

final class WizardRecommendedGoal {
  final String name;
  final String whyImportant;
  final List<WizardRecommendedHabit> habits;

  const WizardRecommendedGoal({
    required this.name,
    required this.whyImportant,
    required this.habits,
  });

  static WizardRecommendedGoal? fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final why = (json['whyImportant'] as String?)?.trim() ?? '';
    final habitsRaw = json['habits'];
    final habits = (habitsRaw is List)
        ? habitsRaw.whereType<Map<String, dynamic>>().map(WizardRecommendedHabit.fromJson).whereType<WizardRecommendedHabit>().toList()
        : const <WizardRecommendedHabit>[];
    return WizardRecommendedGoal(name: name, whyImportant: why, habits: habits);
  }
}

final class WizardRecommendationsPayload {
  final String status; // hit | miss | generated
  final String coreValueId;
  final String categoryKey;
  final String categoryLabel;
  final List<WizardRecommendedGoal> goals;

  const WizardRecommendationsPayload({
    required this.status,
    required this.coreValueId,
    required this.categoryKey,
    required this.categoryLabel,
    required this.goals,
  });
}

final class WizardRecommendationsService {
  WizardRecommendationsService._();

  static Uri _url(String path) => Uri.parse('${DvAuthService.backendBaseUrl()}$path');

  static List<WizardRecommendedGoal> _parseGoals(dynamic recommendations) {
    final goalsRaw = (recommendations is Map<String, dynamic>) ? recommendations['goals'] : null;
    if (goalsRaw is! List) return const [];
    return goalsRaw
        .whereType<Map<String, dynamic>>()
        .map(WizardRecommendedGoal.fromJson)
        .whereType<WizardRecommendedGoal>()
        .toList();
  }

  static Future<WizardRecommendationsPayload?> get({
    required String coreValueId,
    required String category,
  }) async {
    final gender = await DvAuthService.getGender();
    final uri = _url('/wizard/recommendations').replace(
      queryParameters: {
        'coreValueId': coreValueId,
        'category': category,
        'gender': gender,
      },
    );
    final res = await http.get(uri, headers: {'accept': 'application/json'});
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    final status = (decoded['status'] as String?)?.trim() ?? '';
    final cv = (decoded['coreValueId'] as String?)?.trim() ?? coreValueId;
    final key = (decoded['categoryKey'] as String?)?.trim() ?? '';
    final label = (decoded['categoryLabel'] as String?)?.trim() ?? category;
    final goals = _parseGoals(decoded['recommendations']);
    return WizardRecommendationsPayload(status: status, coreValueId: cv, categoryKey: key, categoryLabel: label, goals: goals);
  }

  static Future<WizardRecommendationsPayload?> generate({
    required String coreValueId,
    required String category,
  }) async {
    final gender = await DvAuthService.getGender();
    final res = await http.post(
      _url('/wizard/recommendations/generate'),
      headers: {
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({'coreValueId': coreValueId, 'category': category, 'gender': gender}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    final status = (decoded['status'] as String?)?.trim() ?? '';
    final cv = (decoded['coreValueId'] as String?)?.trim() ?? coreValueId;
    final key = (decoded['categoryKey'] as String?)?.trim() ?? '';
    final label = (decoded['categoryLabel'] as String?)?.trim() ?? category;
    final goals = _parseGoals(decoded['recommendations']);
    return WizardRecommendationsPayload(status: status, coreValueId: cv, categoryKey: key, categoryLabel: label, goals: goals);
  }

  static Future<WizardRecommendationsPayload?> getOrGenerate({
    required String coreValueId,
    required String category,
  }) async {
    final existing = await get(coreValueId: coreValueId, category: category);
    if (existing == null) return null;
    if (existing.status == 'hit' && existing.goals.isNotEmpty) return existing;
    final gen = await generate(coreValueId: coreValueId, category: category);
    return gen;
  }
}

