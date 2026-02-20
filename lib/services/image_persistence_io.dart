import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Directory? _cachedImagesDir;

Future<Directory> _ensureImagesDir() async {
  if (_cachedImagesDir != null && await _cachedImagesDir!.exists()) {
    return _cachedImagesDir!;
  }
  Directory baseDir;
  try {
    baseDir = await getApplicationSupportDirectory();
  } catch (e) {
    debugPrint('[ImagePersistence] getApplicationSupportDirectory failed, using HOME fallback: $e');
    final home = Platform.environment['HOME'] ?? Platform.environment['TMPDIR'] ?? '/tmp';
    baseDir = Directory(p.join(home, 'Library', 'Application Support'));
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
  }
  final imagesDir = Directory(p.join(baseDir.path, 'vision_images'));
  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }
  _cachedImagesDir = imagesDir;
  return imagesDir;
}

Future<String?> persistImageToAppStorage(String sourcePath) async {
  final imagesDir = await _ensureImagesDir();

  final ext = p.extension(sourcePath);
  final filename =
      'img_${DateTime.now().microsecondsSinceEpoch}${ext.isNotEmpty ? ext : '.jpg'}';
  final destPath = p.join(imagesDir.path, filename);

  final src = File(sourcePath);
  if (!await src.exists()) return null;
  final copied = await src.copy(destPath);
  return copied.path;
}

Future<String?> persistImageBytesToAppStorage(
  List<int> bytes, {
  required String extension,
}) async {
  final imagesDir = await _ensureImagesDir();
  final ext = extension.startsWith('.') ? extension : '.$extension';
  final filename = 'img_${DateTime.now().microsecondsSinceEpoch}$ext';
  final destPath = p.join(imagesDir.path, filename);

  final file = File(destPath);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

