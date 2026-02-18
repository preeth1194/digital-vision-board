import 'dart:convert';

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

  static String absolutizeMaybe(String pathOrUrl) {
    final lower = pathOrUrl.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return pathOrUrl;
    
    // Check if this is a local file path (Android/iOS app data directories)
    // Android: /data/user/0/... or /storage/emulated/0/...
    // iOS: /var/mobile/... or similar
    if (pathOrUrl.startsWith('/data/') || 
        pathOrUrl.startsWith('/storage/') ||
        pathOrUrl.startsWith('/var/') ||
        pathOrUrl.startsWith('/private/') ||
        pathOrUrl.contains('/com.seerohabitseeding.app/') ||
        pathOrUrl.contains('/vision_images/')) {
      // This is a local file path, not a server path
      return pathOrUrl;
    }
    
    // Only convert to server URL if it starts with / and is not a local path
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
}

