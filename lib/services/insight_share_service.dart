import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders a fixed-layout insight card to PNG and opens the platform share sheet.
final class InsightShareService {
  InsightShareService._();

  /// Instagram-feed-friendly 4:5 logical size (scaled by [pixelRatio] when rasterizing).
  static const Size shareLogicalSize = Size(1080, 1350);

  static Future<bool> shareInsightCard({
    required BuildContext context,
    required Widget card,
    String fileName = 'habit_seeding_insight',
  }) async {
    if (kIsWeb) return false;
    final bytes = await rasterizeCard(context: context, card: card);
    if (bytes == null) return false;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName.png';
    final file = File(path);
    await file.writeAsBytes(bytes);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'image/png')],
        ),
      );
      return true;
    } on MissingPluginException catch (e, st) {
      // Hot restart does not register new native plugins — need full `flutter run`.
      debugPrint(
        'InsightShareService: share_plus not linked ($e). '
        'Stop the app and run `flutter run` again (not hot restart). $st',
      );
      return false;
    } catch (e, st) {
      debugPrint('InsightShareService: share failed: $e $st');
      return false;
    }
  }

  static Future<Uint8List?> rasterizeCard({
    required BuildContext context,
    required Widget card,
    Size logicalSize = shareLogicalSize,
    double pixelRatio = 3,
  }) async {
    if (kIsWeb) return null;
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return null;

    final key = GlobalKey();
    late OverlayEntry entry;
    final theme = Theme.of(context);
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -12000,
        top: 0,
        child: Material(
          color: Colors.transparent,
          child: Theme(
            data: theme,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: MediaQueryData(
                  size: logicalSize,
                  devicePixelRatio: pixelRatio,
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                ),
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: logicalSize.width,
                    height: logicalSize.height,
                    child: card,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(entry);
    WidgetsBinding.instance.scheduleFrame();
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 32));

    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }
}
