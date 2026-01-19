import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'habit_completion_applier.dart';
import 'habit_progress_widget_snapshot_service.dart';
import 'logical_date_service.dart';

/// Handles deep links used by native home-screen widgets.
///
/// Supported:
/// - `dvb://widget/toggle?boardId=...&componentId=...&habitId=...`
final class WidgetDeepLinkService {
  WidgetDeepLinkService._();

  static StreamSubscription<Uri>? _sub;
  static bool _started = false;

  static Future<void> start() async {
    if (_started) return;
    _started = true;
    if (kIsWeb) return;

    final appLinks = AppLinks();

    Future<void> handle(Uri? uri) async {
      if (uri == null) return;
      if (uri.scheme != 'dvb') return;
      if (uri.host != 'widget') return;
      final path = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
      if (path != 'toggle') return;

      final boardId = (uri.queryParameters['boardId'] ?? '').trim();
      final componentId = (uri.queryParameters['componentId'] ?? '').trim();
      final habitId = (uri.queryParameters['habitId'] ?? '').trim();
      if (boardId.isEmpty || componentId.isEmpty || habitId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await LogicalDateService.ensureInitialized(prefs: prefs);

      final iso = LogicalDateService.isoToday();
      final ok = await HabitCompletionApplier.toggleForToday(
        boardId: boardId,
        componentId: componentId,
        habitId: habitId,
        logicalDateIso: iso,
        prefs: prefs,
      );
      if (!ok) return;

      await HabitProgressWidgetSnapshotService.refreshBestEffort(prefs: prefs);
    }

    try {
      final initial = await appLinks.getInitialLink();
      await handle(initial);
    } catch (_) {
      // ignore
    }

    _sub = appLinks.uriLinkStream.listen((uri) async {
      await handle(uri);
    });
  }

  static Future<void> stop() async {
    _started = false;
    await _sub?.cancel();
    _sub = null;
  }
}

