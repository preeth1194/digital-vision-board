import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/vision_components.dart';
import 'boards_storage_service.dart';
import 'image_persistence.dart';
import 'vision_board_components_storage_service.dart';

class CanvaImportService {
  CanvaImportService._();

  static const _dvTokenKey = 'dv_canva_token_v1';

  static String backendBaseUrl() {
    const raw = String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: 'https://digital-vision-board.onrender.com',
    );
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  static Future<String?> getStoredDvToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_dvTokenKey);
    return (t != null && t.isNotEmpty) ? t : null;
  }

  static Future<void> setStoredDvToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token.isEmpty) {
      await prefs.remove(_dvTokenKey);
    } else {
      await prefs.setString(_dvTokenKey, token);
    }
  }

  static Future<String?> connectViaOAuth({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (kIsWeb) return null; // deep-links not wired for web in this app

    final completer = Completer<String?>();
    final appLinks = AppLinks();
    late final StreamSubscription sub;

    sub = appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme != 'dvb') return;
      if (uri.host != 'oauth') return;
      final token = uri.queryParameters['dvToken'];
      if (token == null || token.isEmpty) return;
      await sub.cancel();
      await setStoredDvToken(token);
      if (!completer.isCompleted) completer.complete(token);
    });

    final returnTo = Uri.encodeComponent('dvb://oauth');
    final url = Uri.parse('${backendBaseUrl()}/auth/canva/start?returnTo=$returnTo');
    // Launch is handled by UI using url_launcher (already in the app).
    // This function only waits for the deep-link to return.

    // Give caller the URL to open by throwing it in the error? Keep simple:
    // Caller should open [url] in a browser, then await this future.
    // We'll store it in prefs for discovery.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dv_canva_last_oauth_url', url.toString());

    return completer.future.timeout(timeout, onTimeout: () async {
      await sub.cancel();
      return null;
    });
  }

  static Future<Uri> getOAuthStartUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('dv_canva_last_oauth_url');
    if (raw != null && raw.isNotEmpty) return Uri.parse(raw);
    final returnTo = Uri.encodeComponent('dvb://oauth');
    return Uri.parse('${backendBaseUrl()}/auth/canva/start?returnTo=$returnTo');
  }

  static Future<Map<String, dynamic>> _getJson(
    String path, {
    required String dvToken,
  }) async {
    final res = await http.get(
      Uri.parse('${backendBaseUrl()}$path'),
      headers: { 'Authorization': 'Bearer $dvToken' },
    );
    if (res.statusCode == 404) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      final error = body?['error'] as String?;
      if (error == 'no_packages') {
        throw Exception(
          'No Canva package found. Please sync a design from the Canva panel first.\n\n'
          'Steps:\n'
          '1. Open your design in Canva\n'
          '2. Use the Digital Vision Board panel\n'
          '3. Map habits to elements\n'
          '4. Click "Sync board to app"\n'
          '5. Then try importing again',
        );
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Request failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<int>> _downloadBytes(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Download failed (${res.statusCode})');
    }
    return res.bodyBytes;
  }

  static Future<void> importLatestPackageIntoBoard(
    String boardId, {
    required String dvToken,
  }) async {
    if (kIsWeb) {
      throw Exception('Canva import is not supported on web yet.');
    }

    final habitsJson = await _getJson('/habits', dvToken: dvToken);
    final habitsList = (habitsJson['habits'] as List<dynamic>? ?? const []);
    final habitNameById = <String, String>{
      for (final h in habitsList)
        if (h is Map<String, dynamic> && (h['id'] as String?) != null)
          (h['id'] as String): (h['name'] as String? ?? (h['id'] as String)),
    };

    Map<String, dynamic> pkgJson;
    try {
      pkgJson = await _getJson('/canva/packages/latest', dvToken: dvToken);
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('no_packages')) {
        throw Exception(
          'No Canva package found. Please sync a design from the Canva panel first. '
          'Open your design in Canva, use the Digital Vision Board panel to map habits to elements, '
          'and click "Sync" to create a package.',
        );
      }
      rethrow;
    }
    final pkg = pkgJson['package'] as Map<String, dynamic>?;
    if (pkg == null) {
      throw Exception(
        'No Canva package found. Please sync a design from the Canva panel first. '
        'Open your design in Canva, use the Digital Vision Board panel to map habits to elements, '
        'and click "Sync" to create a package.',
      );
    }

    // Background from export (if available)
    final export = pkg['export'] as Map<String, dynamic>?;
    final urls = export?['urls'] as List<dynamic>?;
    if (urls != null && urls.isNotEmpty && urls.first is String) {
      final bytes = await _downloadBytes(urls.first as String);
      final path = await persistImageBytesToAppStorage(bytes, extension: 'png');
      if (path != null && path.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(BoardsStorageService.boardImagePathKey(boardId), path);
      }
    }

    // Components (zones with habits)
    final mapped = (pkg['mappedElements'] as List<dynamic>? ?? const []);
    final components = <VisionComponent>[];

    int z = 0;
    for (final m in mapped) {
      if (m is! Map<String, dynamic>) continue;
      final habitId = m['habitId'] as String?;
      final bounds = m['bounds'] as Map<String, dynamic>?;
      if (habitId == null || habitId.isEmpty || bounds == null) continue;

      final x = (bounds['x'] as num?)?.toDouble();
      final y = (bounds['y'] as num?)?.toDouble();
      final w = (bounds['w'] as num?)?.toDouble();
      final h = (bounds['h'] as num?)?.toDouble();
      if (x == null || y == null || w == null || h == null) continue;
      if (w <= 0 || h <= 0) continue;

      final habitName = habitNameById[habitId] ?? habitId;
      final habit = HabitItem(id: habitId, name: habitName, completedDates: const []);

      components.add(
        ZoneComponent(
          id: 'canva_${pkg['id']}_${z}',
          position: Offset(x, y),
          size: Size(w, h),
          rotation: 0,
          scale: 1,
          zIndex: z,
          habits: [habit],
        ),
      );
      z++;
    }

    await VisionBoardComponentsStorageService.saveComponents(boardId, components);
  }
}

