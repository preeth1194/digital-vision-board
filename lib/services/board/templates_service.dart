import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/board_template.dart';
import 'dv_auth_service.dart';

final class TemplatesService {
  TemplatesService._();

  static Uri _url(String path) => Uri.parse('${DvAuthService.backendBaseUrl()}$path');

  static Future<Map<String, dynamic>> _getJson({
    required String path,
    required String dvToken,
  }) async {
    final res = await http.get(_url(path), headers: {'Authorization': 'Bearer $dvToken'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Request failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
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

  static Future<Map<String, dynamic>> _putJson({
    required String path,
    required String dvToken,
    required Map<String, dynamic> body,
  }) async {
    final res = await http.put(
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

  static Future<void> _delete({
    required String path,
    required String dvToken,
  }) async {
    final res = await http.delete(_url(path), headers: {'Authorization': 'Bearer $dvToken'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Request failed (${res.statusCode}): ${res.body}');
    }
  }

  static String absolutizeMaybe(String pathOrUrl) {
    final lower = pathOrUrl.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return pathOrUrl;
    if (pathOrUrl.startsWith('/')) return '${DvAuthService.backendBaseUrl()}$pathOrUrl';
    return pathOrUrl;
  }

  static Future<List<BoardTemplateSummary>> listTemplates({required String dvToken}) async {
    final json = await _getJson(path: '/templates', dvToken: dvToken);
    final raw = json['templates'];
    final list = (raw is List) ? raw.whereType<Map<String, dynamic>>().toList() : const <Map<String, dynamic>>[];
    return list.map(BoardTemplateSummary.fromJson).toList();
  }

  static Future<BoardTemplate> getTemplate(String id, {required String dvToken}) async {
    final json = await _getJson(path: '/templates/$id', dvToken: dvToken);
    final t = json['template'];
    if (t is! Map<String, dynamic>) throw Exception('Malformed template payload');
    return BoardTemplate.fromJson(t);
  }

  // --- Admin APIs ---

  static Future<List<BoardTemplateSummary>> adminListTemplates({required String dvToken}) async {
    final json = await _getJson(path: '/admin/templates', dvToken: dvToken);
    final raw = json['templates'];
    final list = (raw is List) ? raw.whereType<Map<String, dynamic>>().toList() : const <Map<String, dynamic>>[];
    return list.map(BoardTemplateSummary.fromJson).toList();
  }

  static Future<String> adminUploadTemplateImageFile(
    String filePath, {
    required String dvToken,
  }) async {
    if (kIsWeb) throw Exception('Image upload is not supported on web.');
    final bytes = await File(filePath).readAsBytes();
    final req = http.MultipartRequest('POST', _url('/admin/template-images'));
    req.headers['Authorization'] = 'Bearer $dvToken';
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'upload.png'));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Upload failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final url = decoded['url'] as String?;
    if (url == null || url.isEmpty) throw Exception('Upload response missing url');
    return url;
  }

  static Future<String> adminCreateTemplate({
    required String dvToken,
    required String name,
    required String kind,
    required Map<String, dynamic> templateJson,
    String? previewImageId,
  }) async {
    final json = await _postJson(
      path: '/admin/templates',
      dvToken: dvToken,
      body: {
        'name': name,
        'kind': kind,
        'templateJson': templateJson,
        'previewImageId': previewImageId,
      },
    );
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) throw Exception('Create response missing id');
    return id;
  }

  static Future<void> adminUpdateTemplate({
    required String dvToken,
    required String id,
    required String name,
    required String kind,
    required Map<String, dynamic> templateJson,
    String? previewImageId,
  }) async {
    await _putJson(
      path: '/admin/templates/$id',
      dvToken: dvToken,
      body: {
        'name': name,
        'kind': kind,
        'templateJson': templateJson,
        'previewImageId': previewImageId,
      },
    );
  }

  static Future<void> adminDeleteTemplate(String id, {required String dvToken}) async {
    await _delete(path: '/admin/templates/$id', dvToken: dvToken);
  }

  static Future<Map<String, dynamic>> adminCanvaImportCurrentPage({
    required String dvToken,
    String? designId,
    String? designToken,
    required List<Map<String, dynamic>> elements,
  }) async {
    final json = await _postJson(
      path: '/admin/canva/import/current-page',
      dvToken: dvToken,
      body: {
        if (designId != null) 'designId': designId,
        if (designToken != null) 'designToken': designToken,
        'elements': elements,
      },
    );
    return json;
  }

  static Future<Map<String, dynamic>> adminSyncWizardDefaults({
    required String dvToken,
    required bool reset,
  }) async {
    // Back-compat: still supported, but may time out on hosted backends.
    final json = await _postJson(
      path: '/admin/wizard/sync-defaults',
      dvToken: dvToken,
      body: {'reset': reset},
    );
    return json;
  }

  static Future<Map<String, dynamic>> adminStartWizardSync({
    required String dvToken,
    required bool reset,
  }) async {
    final json = await _postJson(
      path: '/admin/wizard/sync-defaults/start',
      dvToken: dvToken,
      body: {'reset': reset},
    );
    return json;
  }

  static Future<Map<String, dynamic>> adminWizardSyncStatus({
    required String dvToken,
    required String jobId,
  }) async {
    final uri = _url('/admin/wizard/sync-defaults/status').replace(
      queryParameters: {'jobId': jobId},
    );
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $dvToken'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Request failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> adminStartStockImagesSync({
    required String dvToken,
    int perCategory = 12,
  }) async {
    final json = await _postJson(
      path: '/admin/stock/sync-category-images/start',
      dvToken: dvToken,
      body: {'perCategory': perCategory},
    );
    return json;
  }

  static Future<Map<String, dynamic>> adminStockImagesSyncStatus({
    required String dvToken,
    required String jobId,
  }) async {
    final uri = _url('/admin/stock/sync-category-images/status').replace(
      queryParameters: {'jobId': jobId},
    );
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $dvToken'});
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Request failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

