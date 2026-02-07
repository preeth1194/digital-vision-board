import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for managing journal voice note audio files stored in app's local storage.
///
/// Audio files are saved to the app's documents directory and persist
/// independently of the recording source.
final class JournalAudioStorageService {
  JournalAudioStorageService._();

  static const String _subdirectory = 'journal_audio';

  /// Get the directory where journal audio files are stored.
  static Future<Directory> _getAudioDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(path.join(appDocDir.path, _subdirectory));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Save an audio file from source path to app storage.
  ///
  /// Returns the full path to the saved audio file.
  /// Throws if file operations fail.
  static Future<String> saveAudio(File sourceFile, String entryId, int index) async {
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file does not exist', sourceFile.path);
    }

    final audioDir = await _getAudioDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(sourceFile.path).isNotEmpty
        ? path.extension(sourceFile.path)
        : '.m4a';
    final filename = 'journal_audio_${entryId}_${timestamp}_$index$extension';
    final destFile = File(path.join(audioDir.path, filename));

    try {
      await sourceFile.copy(destFile.path);
      return destFile.path;
    } catch (e) {
      throw FileSystemException(
        'Failed to save audio',
        destFile.path,
        e is OSError ? e : null,
      );
    }
  }

  /// Generate a path for a new recording (before recording starts).
  ///
  /// Returns a file path that the recorder can write to directly.
  static Future<String> generateRecordingPath(String entryId) async {
    final audioDir = await _getAudioDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'journal_audio_${entryId}_${timestamp}_rec.m4a';
    return path.join(audioDir.path, filename);
  }

  /// Load an audio file from storage.
  ///
  /// Returns the File if it exists, null otherwise.
  static Future<File?> loadAudio(String audioPath) async {
    try {
      final file = File(audioPath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Delete an audio file from storage.
  ///
  /// Does nothing if file doesn't exist.
  static Future<void> deleteAudio(String audioPath) async {
    try {
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore errors when deleting
    }
  }

  /// Delete all audio files associated with a journal entry.
  ///
  /// Searches for files matching the entry ID pattern and deletes them.
  static Future<void> deleteAudioForEntry(String entryId) async {
    try {
      final audioDir = await _getAudioDirectory();
      if (!await audioDir.exists()) return;

      final files = audioDir.listSync();
      for (final file in files) {
        if (file is File) {
          final filename = path.basename(file.path);
          if (filename.contains('journal_audio_${entryId}_')) {
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
