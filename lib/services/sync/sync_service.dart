import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import '../models/habit_item.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import 'boards_storage_service.dart';
import 'dv_auth_service.dart';
import 'grid_tiles_storage_service.dart';
import 'habit_progress_widget_snapshot_service.dart';
import 'logical_date_service.dart';
import 'vision_board_components_storage_service.dart';

/// Best-effort sync layer:
/// - Maintains an outbox in SharedPreferences.
/// - Flushes to backend when possible (idempotent upserts).
/// - Bootstraps local state when local boards list is empty.
final class SyncService {
  SyncService._();

  static const int localRetainDays = 30;
  static const String _outboxKey = 'dv_sync_outbox_v1';
  static const String _bootstrapAppliedKey = 'dv_sync_bootstrap_applied_v1';
  static const String _lastSnapshotMsKey = 'dv_sync_last_snapshot_ms_v1';

  static final ValueNotifier<bool> authExpired = ValueNotifier<bool>(false);

  static Uri _url(String path) => Uri.parse('${DvAuthService.backendBaseUrl()}$path');

  static Future<void> bootstrapIfNeeded({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final localBoards = await BoardsStorageService.loadBoards(prefs: p);
    if (localBoards.isNotEmpty) return;

    final token = await DvAuthService.getDvToken(prefs: p);
    if (token == null) return;

    final alreadyApplied = p.getBool(_bootstrapAppliedKey) ?? false;
    if (alreadyApplied) return;

    final res = await http.get(_url('/sync/bootstrap'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 401) {
      authExpired.value = true;
      return;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // Non-fatal: keep local empty; user can still use offline.
      return;
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final homeTz = decoded['home_timezone'] as String?;
    if (homeTz != null && homeTz.trim().isNotEmpty) {
      await DvAuthService.setHomeTimezone(homeTz.trim(), prefs: p);
      await LogicalDateService.reloadHomeTimezone(prefs: p);
    }
    final gender = decoded['gender'] as String?;
    if (gender != null && gender.trim().isNotEmpty) {
      await DvAuthService.setGender(gender.trim(), prefs: p);
    } else {
      await DvAuthService.setGender('prefer_not_to_say', prefs: p);
    }

    final boardsRaw = decoded['boards'];
    if (boardsRaw is! List) {
      await p.setBool(_bootstrapAppliedKey, true);
      return;
    }

    final boards = <VisionBoardInfo>[];

    for (final entry in boardsRaw) {
      if (entry is! Map<String, dynamic>) continue;
      final boardId = entry['boardId'] as String?;
      final boardJson = entry['boardJson'];
      if (boardId == null || boardId.isEmpty) continue;
      if (boardJson is! Map<String, dynamic>) continue;

      final infoJson = boardJson['info'];
      if (infoJson is Map<String, dynamic>) {
        try {
          boards.add(VisionBoardInfo.fromJson(infoJson));
        } catch (_) {
          // ignore malformed
        }
      }

      // Seed components/tiles when present.
      final layoutType = boardJson['layoutType'] as String?;
      final componentsRaw = boardJson['components'];
      final gridTilesRaw = boardJson['gridTiles'];

      if (layoutType == VisionBoardInfo.layoutGrid && gridTilesRaw is List) {
        final tiles = gridTilesRaw
            .whereType<Map<String, dynamic>>()
            .map(GridTileModel.fromJson)
            .toList();
        await GridTilesStorageService.saveTiles(boardId, tiles, prefs: p);
      } else if (componentsRaw is List) {
        final comps = <VisionComponent>[];
        for (final c in componentsRaw) {
          if (c is! Map<String, dynamic>) continue;
          try {
            comps.add(visionComponentFromJson(c));
          } catch (_) {}
        }
        await VisionBoardComponentsStorageService.saveComponents(boardId, comps, prefs: p);
      }
    }

    if (boards.isNotEmpty) {
      await BoardsStorageService.saveBoards(boards, prefs: p);
    }
    await p.setBool(_bootstrapAppliedKey, true);
  }

  static Future<void> enqueueHabitCompletion({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDate,
    int? rating,
    String? note,
    bool deleted = false,
    SharedPreferences? prefs,
  }) async {
    await _enqueue(
      {
        'kind': 'habit',
        'boardId': boardId,
        'componentId': componentId,
        'habitId': habitId,
        'logicalDate': logicalDate,
        'rating': rating,
        'note': note,
        'deleted': deleted,
      },
      prefs: prefs,
    );

    // Best-effort: keep widget snapshot current for the active board.
    Future<void>(() async {
      await HabitProgressWidgetSnapshotService.refreshIfAffectedBoardBestEffort(boardId, prefs: prefs);
    });
  }

  static Future<void> enqueueBoardSnapshot({
    required String boardId,
    required Map<String, dynamic> boardJson,
    SharedPreferences? prefs,
  }) async {
    await _enqueue(
      {
        'kind': 'board',
        'boardId': boardId,
        'boardJson': boardJson,
      },
      prefs: prefs,
    );
  }

  static Future<void> pushSnapshotsBestEffort({
    SharedPreferences? prefs,
    Duration minInterval = const Duration(hours: 12),
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await DvAuthService.getDvToken(prefs: p);
    if (token == null) return;

    final lastMs = p.getInt(_lastSnapshotMsKey);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (lastMs != null && nowMs - lastMs < minInterval.inMilliseconds) return;

    final boards = await BoardsStorageService.loadBoards(prefs: p);
    if (boards.isEmpty) return;

    for (final b in boards) {
      final boardJson = await _buildBoardSnapshot(b, prefs: p);
      await enqueueBoardSnapshot(boardId: b.id, boardJson: boardJson, prefs: p);
    }
    await p.setInt(_lastSnapshotMsKey, nowMs);
    await flush(prefs: p);
  }

  static Future<Map<String, dynamic>> _buildBoardSnapshot(
    VisionBoardInfo b, {
    required SharedPreferences prefs,
  }) async {
    if (b.layoutType == VisionBoardInfo.layoutGrid) {
      final tiles = await GridTilesStorageService.loadTiles(b.id, prefs: prefs);
      return {
        'info': b.toJson(),
        'layoutType': b.layoutType,
        'gridTiles': tiles.map((t) => t.toJson()).toList(),
      };
    }
    final comps = await VisionBoardComponentsStorageService.loadComponents(b.id, prefs: prefs);
    return {
      'info': b.toJson(),
      'layoutType': b.layoutType,
      'components': comps.map((c) => c.toJson()).toList(),
    };
  }

  static Future<void> flush({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await DvAuthService.getDvToken(prefs: p);
    if (token == null) return;

    final outbox = await _loadOutbox(prefs: p);
    if (outbox.isEmpty) return;

    final boards = <Map<String, dynamic>>[];
    final habitCompletions = <Map<String, dynamic>>[];

    for (final it in outbox) {
      final kind = it['kind'];
      if (kind == 'board') {
        final boardId = it['boardId'];
        final boardJson = it['boardJson'];
        if (boardId is String && boardJson is Map<String, dynamic>) {
          boards.add({'boardId': boardId, 'boardJson': boardJson});
        }
      } else if (kind == 'habit') {
        habitCompletions.add(Map<String, dynamic>.from(it)..remove('kind'));
      } else if (kind == 'checklist') {
        // Legacy outbox entry type (tasks/checklists removed). Drop on flush.
        continue;
      }
    }

    final tz = await DvAuthService.getHomeTimezone(prefs: p);
    final gender = await DvAuthService.getGender(prefs: p);
    final body = <String, dynamic>{
      if (boards.isNotEmpty) 'boards': boards,
      if (habitCompletions.isNotEmpty) 'habitCompletions': habitCompletions,
      'userSettings': {
        if (tz != null && tz.trim().isNotEmpty) 'homeTimezone': tz.trim(),
        'gender': gender,
      },
    };

    if (body.isEmpty) return;

    final res = await http.post(
      _url('/sync/push'),
      headers: {'Authorization': 'Bearer $token', 'content-type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode == 401) {
      authExpired.value = true;
      return;
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      // Keep outbox for later.
      return;
    }

    authExpired.value = false;
    await _saveOutbox(const [], prefs: p);
    await pruneLocalFeedback(prefs: p);
  }

  static Future<void> pruneLocalFeedback({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: p);
    final today = LogicalDateService.today();
    final cutoff = today.subtract(const Duration(days: localRetainDays - 1));
    final cutoffIso = LogicalDateService.toIsoDate(cutoff);

    final boards = await BoardsStorageService.loadBoards(prefs: p);
    for (final b in boards) {
      if (b.layoutType == VisionBoardInfo.layoutGrid) {
        final tiles = await GridTilesStorageService.loadTiles(b.id, prefs: p);
        final nextTiles = tiles.map((t) => _pruneTile(t, cutoffIso)).toList();
        await GridTilesStorageService.saveTiles(b.id, nextTiles, prefs: p);
      } else {
        final comps = await VisionBoardComponentsStorageService.loadComponents(b.id, prefs: p);
        final next = comps.map((c) => _pruneComponent(c, cutoffIso)).toList();
        await VisionBoardComponentsStorageService.saveComponents(b.id, next, prefs: p);
      }
    }
  }

  static VisionComponent _pruneComponent(VisionComponent c, String cutoffIso) {
    final habits = c.habits.map((h) {
      final nextFb = <String, HabitCompletionFeedback>{};
      for (final e in h.feedbackByDate.entries) {
        if (e.key.compareTo(cutoffIso) >= 0) nextFb[e.key] = e.value;
      }
      return h.copyWith(feedbackByDate: nextFb);
    }).toList();
    return c.copyWithCommon(habits: habits, tasks: const []);
  }

  static GridTileModel _pruneTile(GridTileModel t, String cutoffIso) {
    final habits = t.habits.map((h) {
      final nextFb = <String, HabitCompletionFeedback>{};
      for (final e in h.feedbackByDate.entries) {
        if (e.key.compareTo(cutoffIso) >= 0) nextFb[e.key] = e.value;
      }
      return h.copyWith(feedbackByDate: nextFb);
    }).toList();
    return t.copyWith(habits: habits, tasks: const []);
  }

  static Future<void> _enqueue(Map<String, dynamic> item, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final outbox = await _loadOutbox(prefs: p);
    outbox.add(item);
    await _saveOutbox(outbox, prefs: p);

    // Best-effort flush (avoid doing work on web where backend may not be reachable).
    if (!kIsWeb) {
      unawaited(flush(prefs: p));
    }
  }

  static Future<List<Map<String, dynamic>>> _loadOutbox({required SharedPreferences prefs}) async {
    final raw = prefs.getString(_outboxKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> _saveOutbox(List<Map<String, dynamic>> items, {required SharedPreferences prefs}) async {
    await prefs.setString(_outboxKey, jsonEncode(items));
  }
}

