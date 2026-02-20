import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dv_auth_service.dart';

final class StockImagesService {
  StockImagesService._();

  static Uri _url(String path) => Uri.parse('${DvAuthService.backendBaseUrl()}$path');

  static Future<List<String>> searchPexelsUrls({
    required String query,
    int perPage = 12,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = _url('/stock/pexels/search').replace(
      queryParameters: {
        'query': q,
        'perPage': perPage.toString(),
      },
    );
    try {
      final res = await http.get(uri, headers: {'accept': 'application/json'}).timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final ok = decoded['ok'] == true;
      if (!ok) return const [];
      final photos = decoded['photos'];
      if (photos is! List) return const [];
      final urls = <String>[];
      for (final p in photos) {
        if (p is! Map<String, dynamic>) continue;
        final src = p['src'];
        if (src is! Map<String, dynamic>) continue;
        final u = (src['large'] as String?) ?? (src['medium'] as String?) ?? (src['small'] as String?);
        if (u != null && u.trim().isNotEmpty) urls.add(u.trim());
      }
      return urls;
    } catch (_) {
      return const [];
    }
  }
}

