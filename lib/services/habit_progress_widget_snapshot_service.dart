import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/habit_progress_widget_native_bridge.dart';
import '../services/habit_storage_service.dart';
import '../services/habit_timer_state_service.dart';
import '../services/logical_date_service.dart';

/// Builds and stores a compact JSON snapshot for the native home-screen widget.
///
/// Loads ALL habits across every board; excludes timer/location-bound habits.
final class HabitProgressWidgetSnapshotService {
  HabitProgressWidgetSnapshotService._();

  static const String snapshotPrefsKey = 'habit_progress_widget_snapshot_v1';

  static Future<void> refreshBestEffort({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    try {
      await LogicalDateService.ensureInitialized(prefs: p);
      final json = await _buildSnapshotJson(prefs: p);
      if (json == null) return;
      await p.setString(snapshotPrefsKey, json);
      await HabitProgressWidgetNativeBridge.writeSnapshotToAppGroupBestEffort(json);
      await HabitProgressWidgetNativeBridge.updateWidgetsBestEffort();
    } catch (_) {
      // Best-effort: ignore errors (widgets are optional).
    }
  }

  static Future<String?> _buildSnapshotJson({required SharedPreferences prefs}) async {
    final now = LogicalDateService.now();
    final iso = LogicalDateService.toIsoDate(now);

    final pending = <Map<String, dynamic>>[];
    int eligibleTotal = 0;

    final allHabits = await HabitStorageService.loadAll(prefs: prefs);

    for (final h in allHabits) {
      if (!h.isScheduledOnDate(now)) continue;
      if (HabitTimerStateService.targetMsForHabit(h) > 0) continue;
      eligibleTotal++;
      if (!h.isCompletedForCurrentPeriod(now)) {
        pending.add({
          'habitId': h.id,
          'name': h.name,
        });
      }
    }

    final top3 = pending.take(3).toList();
    final allDone = eligibleTotal > 0 && pending.isEmpty;

    final snap = <String, dynamic>{
      'v': 2,
      'generatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'isoDate': iso,
      'eligibleTotal': eligibleTotal,
      'pendingTotal': pending.length,
      'pending': top3,
      'allDone': allDone,
    };

    return jsonEncode(snap);
  }
}
