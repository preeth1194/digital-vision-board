import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/core_value.dart';
import '../models/wizard/wizard_core_value.dart';
import 'dv_auth_service.dart';

final class WizardDefaultsPayload {
  final List<WizardCoreValueDef> coreValues;
  final Map<String, List<String>> categoriesByCoreValueId;
  final String? updatedAt;

  const WizardDefaultsPayload({
    required this.coreValues,
    required this.categoriesByCoreValueId,
    required this.updatedAt,
  });
}

final class WizardCoreValueDef {
  final String id;
  final String label;
  const WizardCoreValueDef({required this.id, required this.label});
}

final class WizardDefaultsService {
  WizardDefaultsService._();

  static const _cacheJsonKey = 'dv_wizard_defaults_json_v1';
  static const _cacheUpdatedAtKey = 'dv_wizard_defaults_updated_at_v1';
  static const _cacheAtMsKey = 'dv_wizard_defaults_cached_at_ms_v1';

  static Uri _url(String path) => Uri.parse('${DvAuthService.backendBaseUrl()}$path');

  static WizardDefaultsPayload _fallback() {
    final coreValues = CoreValues.all.map((c) => WizardCoreValueDef(id: c.id, label: c.label)).toList();
    final cats = <String, List<String>>{
      for (final cv in CoreValues.all) cv.id: WizardCoreValueCatalog.defaultsFor(cv.id),
    };
    return WizardDefaultsPayload(coreValues: coreValues, categoriesByCoreValueId: cats, updatedAt: null);
  }

  static WizardDefaultsPayload? _parseDefaultsResponse(Map<String, dynamic> json) {
    final defaults = json['defaults'];
    if (defaults is! Map<String, dynamic>) return null;

    final coreValuesRaw = defaults['coreValues'];
    final coreValues = <WizardCoreValueDef>[];
    if (coreValuesRaw is List) {
      for (final entry in coreValuesRaw) {
        if (entry is! Map<String, dynamic>) continue;
        final id = (entry['id'] as String?)?.trim();
        final label = (entry['label'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;
        coreValues.add(WizardCoreValueDef(id: id, label: (label == null || label.isEmpty) ? id : label));
      }
    }

    final categoriesRaw = defaults['categoriesByCoreValueId'];
    final categoriesByCore = <String, List<String>>{};
    if (categoriesRaw is Map) {
      for (final e in categoriesRaw.entries) {
        final k = (e.key is String) ? (e.key as String).trim() : '';
        if (k.isEmpty) continue;
        final v = e.value;
        if (v is List) {
          categoriesByCore[k] = v.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      }
    }

    if (coreValues.isEmpty || categoriesByCore.isEmpty) return null;
    return WizardDefaultsPayload(
      coreValues: coreValues,
      categoriesByCoreValueId: categoriesByCore,
      updatedAt: (json['updatedAt'] as String?)?.trim(),
    );
  }

  static Future<void> prefetchDefaults({
    SharedPreferences? prefs,
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    try {
      final res = await http.get(_url('/wizard/defaults'), headers: {'accept': 'application/json'}).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return;
      final parsed = _parseDefaultsResponse(decoded);
      if (parsed == null) return;
      await p.setString(_cacheJsonKey, jsonEncode(decoded));
      await p.setString(_cacheUpdatedAtKey, parsed.updatedAt ?? '');
      await p.setInt(_cacheAtMsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // non-fatal
    }
  }

  static Future<WizardDefaultsPayload> getDefaults({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_cacheJsonKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final parsed = _parseDefaultsResponse(decoded);
          if (parsed != null) return parsed;
        }
      } catch (_) {}
    }
    return _fallback();
  }
}

