import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
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
/// - Runs while the app process is alive.
/// - Uses foreground location stream + distance checks (no discontinued plugins).
/// - We use enter/inside/exit events to accumulate time-inside via [HabitTimerStateService].
/// - We can optionally auto-complete habits by persisting completion to local storage
///   and enqueuing sync, without requiring UI to be open.
final class HabitGeofenceTrackingService {
  HabitGeofenceTrackingService._();

  static final HabitGeofenceTrackingService instance = HabitGeofenceTrackingService._();

  bool _initialized = false;
  StreamSubscription<Position>? _positionSub;

  // Map per component so UI screens can refresh just their component’s habits.
  final Map<String, List<_HabitGeoTarget>> _targetsByComponentKey = <String, List<_HabitGeoTarget>>{};
  final Map<String, bool> _lastInsideByTargetId = <String, bool>{};

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  void _ensureInitialized() {
    if (_initialized) return;
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
    await _positionSub?.cancel();
    _positionSub = null;
    _lastInsideByTargetId.clear();
  }

  Future<void> _rebuildService({SharedPreferences? prefs}) async {
    final targets = _targetsByComponentKey.values.expand((x) => x).toList();

    debugPrint('[Geofence] _rebuildService: ${targets.length} target(s)');
    if (targets.isEmpty) {
      await stop();
      debugPrint('[Geofence] Stopped service (no targets)');
      return;
    }

    if (_positionSub != null) {
      debugPrint('[Geofence] Location stream already running');
      return;
    }
    debugPrint('[Geofence] Starting location stream...');
    await _startLocationStream().catchError(_onError);
  }

  Future<void> _startLocationStream() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint('[Geofence] Location services disabled');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[Geofence] Location permission denied');
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) {
        unawaited(_onPosition(position));
      },
      onError: _onError,
      cancelOnError: false,
    );
  }

  Future<void> _onPosition(Position position) async {
    final targets = _targetsByComponentKey.values.expand((x) => x).toList();
    if (targets.isEmpty) return;

    final eventMs = position.timestamp.millisecondsSinceEpoch;

    for (final t in targets) {
      final h = t.habit;
      final lb = h.locationBound;
      if (lb == null || !lb.enabled) continue;

      final id = _targetId(t);
      final distM = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lb.lat,
        lb.lng,
      );
      final inside = distM <= lb.radiusMeters;
      final prevInside = _lastInsideByTargetId[id];
      final changed = prevInside == null || prevInside != inside;
      _lastInsideByTargetId[id] = inside;

      // Skip repeated "outside" states to avoid useless writes.
      if (!inside && !changed) continue;

      await _handleTargetEvent(
        target: t,
        inside: inside,
        eventMs: eventMs,
        wasInsideBefore: prevInside == true,
      );
    }
  }

  Future<void> _handleTargetEvent({
    required _HabitGeoTarget target,
    required bool inside,
    required int eventMs,
    required bool wasInsideBefore,
  }) async {
    final h = target.habit;
    final lb = h.locationBound;
    if (lb == null || !lb.enabled) return;
    final habitId = h.id;
    final boardId = target.boardId;
    final componentId = target.componentId;
    final targetMs = HabitTimerStateService.targetMsForHabit(h);
    final triggerMode = lb.triggerMode;

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

    debugPrint('[Geofence] targetMs=$targetMs, inside=$inside, triggerMode=$triggerMode');

    // "departure" mode: complete only on an actual inside -> outside transition.
    if (triggerMode == 'departure' && !inside && wasInsideBefore) {
      final iso = LogicalDateService.isoToday();
      final didComplete = await HabitCompletionApplier.markCompleted(
        boardId: boardId,
        componentId: componentId,
        habitId: habitId,
        logicalDateIso: iso,
        prefs: prefs,
      );
      debugPrint('[Geofence] Departure complete -> didComplete=$didComplete');
      if (didComplete) {
        final habitName = _lookupHabitName(boardId, componentId, habitId);
        await NotificationsService.showGeofenceCompletionNotification(
          habitId: habitId,
          habitName: habitName ?? 'your habit',
          boardId: boardId,
          componentId: componentId,
        );
      }
      return;
    }

    // Dwell-based: accumulate time inside and auto-complete once target is reached.
    if (targetMs > 0) {
      final acc = await HabitTimerStateService.accumulatedMsNow(
        prefs: prefs,
        habitId: habitId,
        logicalDate: logicalDate,
        nowMs: eventMs,
      );
      debugPrint('[Geofence] accumulated=${acc}ms / target=${targetMs}ms');
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
        debugPrint('[Geofence] markCompleted -> didComplete=$didComplete');
        if (didComplete) {
          final habitName = _lookupHabitName(boardId, componentId, habitId);
          debugPrint('[Geofence] Showing notification for "$habitName"');
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

  String _targetId(_HabitGeoTarget t) => 'habit:${t.boardId}:${t.componentId}:${t.habit.id}';

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
    debugPrint('[Geofence] Error: $error');
  }
}

final class _HabitGeoTarget {
  final String boardId;
  final String componentId;
  final HabitItem habit;
  const _HabitGeoTarget({required this.boardId, required this.componentId, required this.habit});
}

