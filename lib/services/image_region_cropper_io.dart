import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'image_persistence.dart';

Future<String?> cropAndPersistImageRegion({
  required String sourcePath,
  required Rect region,
  int quality = 92,
}) async {
  final file = File(sourcePath);
  if (!await file.exists()) return null;

  final Uint8List bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final int left = region.left.floor().clamp(0, decoded.width - 1);
  final int top = region.top.floor().clamp(0, decoded.height - 1);
  final int right = region.right.ceil().clamp(0, decoded.width);
  final int bottom = region.bottom.ceil().clamp(0, decoded.height);

  final int w = math.max(1, right - left);
  final int h = math.max(1, bottom - top);

  final cropped = img.copyCrop(
    decoded,
    x: left,
    y: top,
    width: w,
    height: h,
  );

  final jpg = img.encodeJpg(cropped, quality: quality.clamp(1, 100));
  final persisted = await persistImageBytesToAppStorage(
    Uint8List.fromList(jpg),
    extension: '.jpg',
  );
  return persisted;
}

