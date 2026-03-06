import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/action_step_template.dart';
import 'dv_auth_service.dart';

class ActionTemplatesService {
  ActionTemplatesService._();

  static Uri _url(String path) =>
      Uri.parse('${DvAuthService.backendBaseUrl()}$path');

  static Future<Map<String, dynamic>> _getJson({
    required String path,
    required String dvToken,
  }) async {
    final res = await http.get(
      _url(path),
      headers: {'Authorization': 'Bearer $dvToken'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Request failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<http.Response> _getRaw({
    required String path,
    required String dvToken,
  }) {
    return http.get(_url(path), headers: {'Authorization': 'Bearer $dvToken'});
  }

  static Future<Map<String, dynamic>> _postJson({
    required String path,
    required String dvToken,
    required Map<String, dynamic> body,
  }) async {
    final res = await http.post(
      _url(path),
      headers: {
        'Authorization': 'Bearer $dvToken',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Request failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<ActionStepTemplate>> listApproved({
    required String dvToken,
    ActionTemplateCategory? category,
  }) async {
    final suffix = category == null
        ? ''
        : '?category=${Uri.encodeQueryComponent(_categoryToString(category))}';
    final res = await _getRaw(
      path: '/action-templates$suffix',
      dvToken: dvToken,
    );
    if (res.statusCode == 404) {
      // Backward compatibility: backend may not have action template endpoints yet.
      return const <ActionStepTemplate>[];
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Request failed (${res.statusCode}): ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = json['templates'];
    final list = (raw is List)
        ? raw.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    return list.map(ActionStepTemplate.fromJson).toList();
  }

  static Future<ActionStepTemplate> submitTemplateDraft({
    required String dvToken,
    required String name,
    required ActionTemplateCategory category,
    required List<Map<String, dynamic>> steps,
    required Map<String, dynamic> metadata,
  }) async {
    final json = await _postJson(
      path: '/action-templates/submit',
      dvToken: dvToken,
      body: {
        'name': name,
        'category': _categoryToString(category),
        'steps': steps,
        'metadata': metadata,
      },
    );
    final raw = json['template'];
    if (raw is! Map<String, dynamic>) {
      throw Exception('Malformed template payload');
    }
    return ActionStepTemplate.fromJson(raw);
  }

  static String _categoryToString(ActionTemplateCategory category) {
    switch (category) {
      case ActionTemplateCategory.skincare:
        return 'skincare';
      case ActionTemplateCategory.workout:
        return 'workout';
      case ActionTemplateCategory.mealPrep:
        return 'meal_prep';
      case ActionTemplateCategory.recipe:
        return 'recipe';
    }
  }
}
