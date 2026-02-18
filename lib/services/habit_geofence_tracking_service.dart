import 'dart:async';

import 'package:geofence_service/geofence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/vision_board_info.dart';
import 'boards_storage_service.dart';
import 'grid_tiles_storage_service.dart';
import 'habit_completion_applier.dart';
import 'habit_timer_state_service.dart';
import 'logical_date_service.dart';
import 'notifications_service.dart';
import 'vision_board_components_storage_service.dart';

/// App-level geofence tracker for location-bound habits.
///
/// Notes:
/// - `geofence_service` runs while the app process is alive.
/// - We use ENTER/DWELL/EXIT to accumulate time-inside via [HabitTimerStateService].
/// - We can optionally auto-complete habits by persisting completion to local storage
///   and enqueuing sync, without requiring UI to be open.
final class HabitGeofenceTrackingService {
  HabitGeofenceTrackingService._();

  static final HabitGeofenceTrackingService instance = HabitGeofenceTrackingService._();

  final GeofenceService _svc = GeofenceService.instance;
  bool _initialized = false;

  // Map per component so UI screens can refresh just their component’s habits.
  final Map<String, List<_HabitGeoTarget>> _targetsByComponentKey = <String, List<_HabitGeoTarget>>{};

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  void _ensureInitialized() {
    if (_initialized) return;

    _svc.setup(
      interval: 5000,
      accuracy: 100,
      loiteringDelayMs: 60000,
      statusChangeDelayMs: 10000,
      useActivityRecognition: false,
      allowMockLocations: false,
      printDevLog: false,
      geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
    );

    _svc.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
    _svc.addStreamErrorListener(_onError);
    _initialized = true;
  }

  /// Register/refresh geofence targets for one component (board + componentId).
  Future<void> configureForComponent({
    required String boardId,
    required String componentId,
    required List<HabitItem> habits,
  }) async {
    _ensureInitialized();
    final key = '$boardId::$componentId';
    final enabled = habits
        .where((h) => h.locationBound?.enabled == true)
        .map((h) => _HabitGeoTarget(boardId: boardId, componentId: componentId, habit: h))
        .toList();
    _targetsByComponentKey[key] = enabled;
    await _rebuildService();
  }

  /// Bootstraps geofence targets from local storage for all boards.
  Future<void> bootstrapFromStorage({required SharedPreferences prefs}) async {
    _ensureInitialized();
    await LogicalDateService.ensureInitialized(prefs: prefs);

    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    _targetsByComponentKey.clear();

    for (final b in boards) {
      if (b.layoutType.trim() == VisionBoardInfo.layoutGrid) {
        final tiles = await GridTilesStorageService.loadTiles(b.id, prefs: prefs);
        for (final t in tiles) {
          final enabled = t.habits
              .where((h) => h.locationBound?.enabled == true)
              .map((h) => _HabitGeoTarget(boardId: b.id, componentId: t.id, habit: h))
              .toList();
          if (enabled.isEmpty) continue;
          _targetsByComponentKey['${b.id}::${t.id}'] = enabled;
        }
      } else {
        final comps = await VisionBoardComponentsStorageService.loadComponents(b.id, prefs: prefs);
        for (final c in comps) {
          final enabled = c.habits
              .where((h) => h.locationBound?.enabled == true)
              .map((h) => _HabitGeoTarget(boardId: b.id, componentId: c.id, habit: h))
              .toList();
          if (enabled.isEmpty) continue;
          _targetsByComponentKey['${b.id}::${c.id}'] = enabled;
        }
      }
    }

    await _rebuildService(prefs: prefs);
  }

  Future<void> stop() async {
    if (!_svc.isRunningService) return;
    await _svc.stop();
  }

  Future<void> _rebuildService({SharedPreferences? prefs}) async {
    // Rebuild the full geofence list from our component-target map.
    _svc.clearGeofenceList();

    final targets = _targetsByComponentKey.values.expand((x) => x).toList();
    for (final t in targets) {
      final h = t.habit;
      final lb = h.locationBound;
      if (lb == null || !lb.enabled) continue;

      final targetMs = HabitTimerStateService.targetMsForHabit(h);

      final geofence = Geofence(
        id: 'habit:${t.boardId}:${t.componentId}:${h.id}',
        data: <String, dynamic>{
          'habitId': h.id,
          'boardId': t.boardId,
          'componentId': t.componentId,
          'targetMs': targetMs,
        },
        latitude: lb.lat,
        longitude: lb.lng,
        radius: [
          GeofenceRadius(id: 'radius_${lb.radiusMeters}m', length: lb.radiusMeters.toDouble()),
        ],
      );
      _svc.addGeofence(geofence);
    }

    if (targets.isEmpty) {
      if (_svc.isRunningService) {
        await _svc.stop();
      }
      return;
    }

    if (_svc.isRunningService) return;
    await _svc.start().catchError(_onError);
  }

  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    final data = geofence.data;
    if (data is! Map) return;

    final habitId = data['habitId'] as String?;
    final boardId = data['boardId'] as String?;
    final componentId = data['componentId'] as String?;
    final targetMs = (data['targetMs'] as num?)?.toInt() ?? 0;

    if (habitId == null || habitId.trim().isEmpty) return;
    if (boardId == null || boardId.trim().isEmpty) return;
    if (componentId == null || componentId.trim().isEmpty) return;

    // ENTER/DWELL -> inside, EXIT -> outside
    final inside = geofenceStatus != GeofenceStatus.EXIT;
    final eventMs = location.timestamp.millisecondsSinceEpoch;

    final prefs = await _prefs();
    await LogicalDateService.ensureInitialized(prefs: prefs);
    final logicalDate = LogicalDateService.today();

    await HabitTimerStateService.applyGeofenceEvent(
      prefs: prefs,
      habitId: habitId,
      logicalDate: logicalDate,
      inside: inside,
      eventMs: eventMs,
    );

    // Auto-complete in background (process alive) when the time target is reached.
    if (targetMs > 0) {
      final acc = await HabitTimerStateService.accumulatedMsNow(
        prefs: prefs,
        habitId: habitId,
        logicalDate: logicalDate,
        nowMs: eventMs,
      );
      if (acc >= targetMs) {
        await HabitTimerStateService.pause(
          prefs: prefs,
          habitId: habitId,
          logicalDate: logicalDate,
          nowMs: eventMs,
        );
        final iso = LogicalDateService.isoToday();
        final didComplete = await HabitCompletionApplier.markCompleted(
          boardId: boardId,
          componentId: componentId,
          habitId: habitId,
          logicalDateIso: iso,
          prefs: prefs,
        );
        if (didComplete) {
          final habitName = _lookupHabitName(boardId, componentId, habitId);
          await NotificationsService.showGeofenceCompletionNotification(
            habitId: habitId,
            habitName: habitName ?? 'your habit',
            boardId: boardId,
            componentId: componentId,
          );
        }
      }
    }
  }

  String? _lookupHabitName(String boardId, String componentId, String habitId) {
    final key = '$boardId::$componentId';
    final targets = _targetsByComponentKey[key];
    if (targets == null) return null;
    for (final t in targets) {
      if (t.habit.id == habitId) return t.habit.name;
    }
    return null;
  }

  void _onError(dynamic error) {
    // Best-effort; errors are surfaced by permission UX elsewhere.
  }
}

final class _HabitGeoTarget {
  final String boardId;
  final String componentId;
  final HabitItem habit;
  const _HabitGeoTarget({required this.boardId, required this.componentId, required this.habit});
}

