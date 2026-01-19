import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// Best-effort bridge to ask native home-screen widgets to refresh.
///
/// - Android: triggers AppWidget update.
/// - iOS: (when WidgetKit extension is added) reloads timelines.
final class HabitProgressWidgetNativeBridge {
  HabitProgressWidgetNativeBridge._();

  static const MethodChannel _ch = MethodChannel('dvb/habit_progress_widget');

  static const String defaultIosAppGroupId = 'group.digital_vision_board';

  static Future<void> writeSnapshotToAppGroupBestEffort(
    String snapshotJson, {
    String iosAppGroupId = defaultIosAppGroupId,
  }) async {
    try {
      await _ch.invokeMethod<void>(
        'writeSnapshotToAppGroup',
        <String, dynamic>{
          'snapshot': snapshotJson,
          'iosAppGroupId': iosAppGroupId,
        },
      );
    } catch (_) {
      // ignore
    }
  }

  static Future<List<Map<String, String>>> readAndClearQueuedWidgetActionsBestEffort({
    String iosAppGroupId = defaultIosAppGroupId,
  }) async {
    try {
      final res = await _ch.invokeMethod<dynamic>(
        'readAndClearQueuedWidgetActions',
        <String, dynamic>{'iosAppGroupId': iosAppGroupId},
      );
      if (res is! List) return const [];
      return res
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry('$k', '$v')))
          .map((m) => Map<String, String>.from(m))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> updateWidgetsBestEffort() async {
    // No-op for web (this app doesn't support deep links/widgets on web).
    if (defaultTargetPlatform == TargetPlatform.fuchsia) return;
    try {
      await _ch.invokeMethod<void>('updateWidgets');
    } catch (_) {
      // Non-fatal: widgets are best-effort.
    }
  }
}

