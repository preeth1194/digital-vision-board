import 'dart:io';

import 'package:flutter_edge_detection/flutter_edge_detection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> scanAndCropPhysicalBoard({
  required bool allowGallery,
}) async {
  final baseDir = await getApplicationSupportDirectory();
  final imagesDir = Directory(p.join(baseDir.path, 'vision_images'));
  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }

  final outPath =
      p.join(imagesDir.path, 'board_${DateTime.now().microsecondsSinceEpoch}.jpg');

  final ok = await FlutterEdgeDetection.detectEdge(
    outPath,
    canUseGallery: allowGallery,
    androidScanTitle: 'Detect board edges',
    androidCropTitle: 'Crop',
    androidCropBlackWhiteTitle: 'B&W',
    androidCropReset: 'Reset',
  );

  if (!ok) return null;
  final file = File(outPath);
  if (!await file.exists()) return null;
  return outPath;
}

