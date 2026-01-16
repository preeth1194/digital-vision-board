import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_components.dart';
import 'boards_storage_service.dart';

class VisionBoardComponentsStorageService {
  VisionBoardComponentsStorageService._();

  static Future<List<VisionComponent>> loadComponents(
    String boardId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(BoardsStorageService.boardComponentsKey(boardId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = (jsonDecode(raw) as List<dynamic>);
      return decoded.map((e) => visionComponentFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveComponents(
    String boardId,
    List<VisionComponent> components, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      BoardsStorageService.boardComponentsKey(boardId),
      jsonEncode(components.map((c) => c.toJson()).toList()),
    );
  }
}

