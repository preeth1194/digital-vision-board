import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dv_auth_service.dart';

final class CategoryImageItem {
  final String url;
  final String alt;
  final String photographer;
  final String categoryLabel;

  const CategoryImageItem({
    required this.url,
    required this.alt,
    required this.photographer,
    required this.categoryLabel,
  });
}

final class CategoryImagesService {
  CategoryImagesService._();

  static Uri _url(String path) => Uri.parse('${DvAuthService.backendBaseUrl()}$path');

  static Future<List<CategoryImageItem>> getCategoryImages({
    required String coreValueId,
    required String category,
    int limit = 12,
  }) async {
    final cv = coreValueId.trim();
    final cat = category.trim();
    if (cv.isEmpty || cat.isEmpty) return const [];
    final uri = _url('/stock/category-images').replace(
      queryParameters: {
        'coreValueId': cv,
        'category': cat,
        'limit': limit.toString(),
      },
    );
    try {
      final res = await http.get(uri, headers: {'accept': 'application/json'});
      if (res.statusCode < 200 || res.statusCode >= 300) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      if (decoded['ok'] != true) return const [];
      final imgs = decoded['images'];
      if (imgs is! List) return const [];
      final items = <CategoryImageItem>[];
      for (final it in imgs) {
        if (it is! Map<String, dynamic>) continue;
        final u = (it['url'] as String?)?.trim();
        if (u == null || u.isEmpty) continue;
        items.add(
          CategoryImageItem(
            url: u,
            alt: (it['alt'] as String?)?.trim() ?? '',
            photographer: (it['photographer'] as String?)?.trim() ?? '',
            categoryLabel: (it['categoryLabel'] as String?)?.trim() ?? cat,
          ),
        );
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<String>> getCategoryImageUrls({
    required String coreValueId,
    required String category,
    int limit = 12,
  }) async {
    final items = await getCategoryImages(coreValueId: coreValueId, category: category, limit: limit);
    return items.map((e) => e.url).toList();
  }
}

