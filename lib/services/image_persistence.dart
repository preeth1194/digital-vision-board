// Conditional import wrapper for persisting images into app storage.
//
// On IO platforms, this copies the file into an app-owned directory and returns
// the new path.
// On web, it returns null (this app currently doesn't support image file
// persistence on web).
import 'image_persistence_web.dart'
    if (dart.library.io) 'image_persistence_io.dart' as impl;

/// Copies [sourcePath] into app-owned storage and returns the new path.
///
/// Returns null if persistence isn't supported on this platform.
Future<String?> persistImageToAppStorage(String sourcePath) =>
    impl.persistImageToAppStorage(sourcePath);

/// Writes [bytes] into app-owned storage and returns the new path.
///
/// Returns null if persistence isn't supported on this platform.
Future<String?> persistImageBytesToAppStorage(
  List<int> bytes, {
  required String extension,
}) =>
    impl.persistImageBytesToAppStorage(bytes, extension: extension);

