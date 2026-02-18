import 'dart:ui';

Future<String?> cropAndPersistImageRegion({
  required String sourcePath,
  required Rect region,
  int quality = 92,
}) async {
  // Web flow isn't supported in this app yet (picker/cropper + file persistence).
  return null;
}

