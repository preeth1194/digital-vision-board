import 'dart:async';

import 'package:geofence_service/geofence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import 'habit_timer_state_service.dart';
import 'logical_date_service.dart';

/// App-level geofence tracker for location-bound habits.
///
/// Notes:
/// - `geofence_service` runs while the app process is alive. On Android it can
///   keep running via a foreground service depending on platform/plugin setup.
/// - We only use ENTER/EXIT to accumulate time-inside via [HabitTimerStateService].
/// - Completion is applied by the UI (when opened) via the normal toggle flow.
final class HabitGeofenceTrackingService {
  HabitGeofenceTrackingService._();

  static final HabitGeofenceTrackingService instance = HabitGeofenceTrackingService._();

  final GeofenceService _svc = GeofenceService.instance;
  bool _initialized = false;

  // Keep the last set of habit geofences we registered so we can cheaply refresh.
  final Set<String> _registeredHabitIds = <String>{};

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  void _ensureInitialized() {
    if (_initialized) return;

    _svc.setup(
      interval: 5000,
      accuracy: 100,
      // We don't rely on DWELL events; we compute dwell via enter/exit timestamps.
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

  Future<void> configureForHabits(List<HabitItem> habits) async {
    _ensureInitialized();

    final enabled = habits.where((h) {
      final lb = h.locationBound;
      return lb != null && lb.enabled;
    }).toList();

    // Remove any old geofences first to avoid duplicates.
    _svc.clearGeofenceList();
    _registeredHabitIds
      ..clear()
      ..addAll(enabled.map((h) => h.id));

    for (final h in enabled) {
      final lb = h.locationBound!;
      final geofence = Geofence(
        id: 'habit:${h.id}',
        data: <String, dynamic>{'habitId': h.id},
        latitude: lb.lat,
        longitude: lb.lng,
        radius: [
          GeofenceRadius(id: 'radius_${lb.radiusMeters}m', length: lb.radiusMeters.toDouble()),
        ],
      );
      _svc.addGeofence(geofence);
    }

    if (_registeredHabitIds.isEmpty) {
      if (_svc.isRunningService) {
        await _svc.stop();
      }
      return;
    }

    if (_svc.isRunningService) return;
    await _svc.start().catchError(_onError);
  }

  Future<void> stop() async {
    if (!_svc.isRunningService) return;
    await _svc.stop();
    _registeredHabitIds.clear();
  }

  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    final data = geofence.data;
    final habitId = (data is Map && data['habitId'] is String)
        ? (data['habitId'] as String)
        : geofence.id.startsWith('habit:')
            ? geofence.id.substring('habit:'.length)
            : null;
    if (habitId == null || habitId.trim().isEmpty) return;

    // ENTER/DWELL -> inside, EXIT -> outside
    final inside = geofenceStatus != GeofenceStatus.EXIT;
    final eventMs = location.timestamp.millisecondsSinceEpoch;

    final prefs = await _prefs();
    final logicalDate = LogicalDateService.today();
    await HabitTimerStateService.applyGeofenceEvent(
      prefs: prefs,
      habitId: habitId,
      logicalDate: logicalDate,
      inside: inside,
      eventMs: eventMs,
    );
  }

  void _onError(dynamic error) {
    // Intentionally no-op; UI can surface errors via normal permission prompts.
  }
}

