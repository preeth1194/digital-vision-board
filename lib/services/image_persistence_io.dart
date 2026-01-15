import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _ensureImagesDir() async {
  final baseDir = await getApplicationSupportDirectory();
  final imagesDir = Directory(p.join(baseDir.path, 'vision_images'));
  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }
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

