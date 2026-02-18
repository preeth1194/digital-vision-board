import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// Best-effort bridge to ask native puzzle widget to refresh.
///
/// - Android: triggers AppWidget update.
/// - iOS: (when WidgetKit extension is added) reloads timelines.
final class PuzzleWidgetNativeBridge {
  PuzzleWidgetNativeBridge._();

  static const MethodChannel _ch = MethodChannel('dvb/puzzle_widget');

  static const String defaultIosAppGroupId = 'group.seerohabitseeding';

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
