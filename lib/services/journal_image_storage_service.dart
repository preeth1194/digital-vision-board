import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for managing journal images stored in app's local storage.
///
/// Images are copied from gallery to app's documents directory and persist
/// even if deleted from the original gallery location.
final class JournalImageStorageService {
  JournalImageStorageService._();

  static const String _subdirectory = 'journal_images';

  /// Get the directory where journal images are stored.
  static Future<Directory> _getImageDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(path.join(appDocDir.path, _subdirectory));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }

  /// Save an image from source file to app storage.
  ///
  /// Returns the full path to the saved image file.
  /// Throws if file operations fail.
  static Future<String> saveImage(File sourceFile, String entryId, int index) async {
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file does not exist', sourceFile.path);
    }

    final imageDir = await _getImageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(sourceFile.path);
    final filename = 'journal_img_${entryId}_${timestamp}_$index$extension';
    final destFile = File(path.join(imageDir.path, filename));

    try {
      await sourceFile.copy(destFile.path);
      return destFile.path;
    } catch (e) {
      throw FileSystemException(
        'Failed to save image',
        destFile.path,
        e is OSError ? e : null,
      );
    }
  }

  /// Load an image file from storage.
  ///
  /// Returns the File if it exists, null otherwise.
  static Future<File?> loadImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Delete an image file from storage.
  ///
  /// Does nothing if file doesn't exist.
  static Future<void> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore errors when deleting
    }
  }

  /// Delete all images associated with a journal entry.
  ///
  /// Searches for files matching the entry ID pattern and deletes them.
  static Future<void> deleteImagesForEntry(String entryId) async {
    try {
      final imageDir = await _getImageDirectory();
      if (!await imageDir.exists()) return;

      final files = imageDir.listSync();
      for (final file in files) {
        if (file is File) {
          final filename = path.basename(file.path);
          // Check if filename contains the entry ID
          if (filename.contains('journal_img_${entryId}_')) {
            try {
              await file.delete();
            } catch (_) {
              // Continue deleting other files even if one fails
            }
          }
        }
      }
    } catch (_) {
      // Ignore errors
    }
  }
}
