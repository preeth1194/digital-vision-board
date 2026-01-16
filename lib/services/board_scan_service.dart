import 'board_scan_service_web.dart'
    if (dart.library.io) 'board_scan_service_io.dart' as impl;

/// Opens an edge-detection scanner UI to capture or pick a photo and
/// automatically crop/straighten (perspective correct) the board area.
///
/// Returns the saved file path (in app storage) or null if cancelled/unsupported.
Future<String?> scanAndCropPhysicalBoard({
  required bool allowGallery,
}) =>
    impl.scanAndCropPhysicalBoard(allowGallery: allowGallery);

