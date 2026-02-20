import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'habit_completion_applier.dart';
import 'habit_progress_widget_native_bridge.dart';
import 'habit_progress_widget_snapshot_service.dart';
import 'logical_date_service.dart';

/// iOS 17+ WidgetKit AppIntents can't directly invoke Flutter code, so they
/// enqueue actions into the app group. The app consumes them on startup/resume.
final class HabitProgressWidgetActionQueueService with WidgetsBindingObserver {
  HabitProgressWidgetActionQueueService._();

  static final HabitProgressWidgetActionQueueService instance = HabitProgressWidgetActionQueueService._();
  bool _started = false;
  bool _draining = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(drainOnceBestEffort());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(drainOnceBestEffort());
    }
  }

  Future<void> drainOnceBestEffort() async {
    if (_draining) return;
    _draining = true;
    try {
      final actions = await HabitProgressWidgetNativeBridge.readAndClearQueuedWidgetActionsBestEffort();
      if (actions.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await LogicalDateService.ensureInitialized(prefs: prefs);
      final iso = LogicalDateService.isoToday();

      for (final a in actions) {
        final kind = (a['kind'] ?? '').trim();
        if (kind != 'toggle') continue;
        final habitId = (a['habitId'] ?? '').trim();
        if (habitId.isEmpty) continue;
        await HabitCompletionApplier.toggleForToday(
          habitId: habitId,
          logicalDateIso: iso,
          prefs: prefs,
        );
      }

      await HabitProgressWidgetSnapshotService.refreshBestEffort(prefs: prefs);
    } catch (_) {
      // ignore
    } finally {
      _draining = false;
    }
  }
}
