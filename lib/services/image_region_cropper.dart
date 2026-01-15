import 'dart:ui';

import 'image_region_cropper_web.dart'
    if (dart.library.io) 'image_region_cropper_io.dart' as impl;

/// Crop a pixel-space [region] from [sourcePath] and persist it into app storage.
///
/// Returns the new persisted file path, or null if unsupported/failed.
Future<String?> cropAndPersistImageRegion({
  required String sourcePath,
  required Rect region,
  int quality = 92,
}) =>
    impl.cropAndPersistImageRegion(
      sourcePath: sourcePath,
      region: region,
      quality: quality,
    );

