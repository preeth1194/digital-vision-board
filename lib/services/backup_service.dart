import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'encryption_service.dart';

/// Collects all user data (SharedPreferences + media files) into a single
/// encrypted `.dvb.enc` archive for Google Drive backup, and handles restore.
class BackupService {
  BackupService._();

  static const backupExtension = '.dvb.enc';

  static const _prefixesToBackup = [
    'dv_habits_v1',
    'dv_journal_entries_v1',
    'dv_journal_books_v1',
    'dv_affirmations_v1',
    'dv_overall_streak_v1',
    'dv_micro_habit_selections_v1',
    'dv_theme_mode_v1',
    'dv_custom_alarm_sound_v1',
    'dv_measurement_unit_v1',
    'dv_home_timezone_v1',
    'dv_gender_v1',
    'dv_user_display_name_v1',
    'dv_user_weight_kg_v1',
    'dv_user_height_cm_v1',
    'dv_user_dob_v1',
    'dv_user_profile_pic_v1',
    'dv_user_phone_v1',
    'dv_user_email_v1',
    'vision_boards_list_v1',
    'active_vision_board_id_v1',
    'routines_list_v1',
    'active_routine_id_v1',
    'user_total_coins',
    'last_streak_bonus_date',
    'is_subscribed',
    'active_plan_id',
    'ad_free_coin_date',
    'puzzle_image_path',
    'puzzle_last_rotation_ms',
    'puzzle_cooldown_end_ms',
    'habit_progress_widget_snapshot_v1',
    'sun_times_lat',
    'sun_times_lng',
    'sun_times_location_name',
  ];

  static const _dynamicPrefixes = [
    'vision_board_',
    'dv_board_drive_bg_file_id_v1_',
    'puzzle_state_',
    'habit_timer_state_v1:',
    'rhythmic_timer_state_v1:',
    'dv_micro_habit_selections_v1',
    'dv_affirmation_rotation_',
    'reward_ads_watched_',
    'active_ad_unlock_session',
  ];

  /// Create an encrypted backup archive. Returns the path to the .dvb.enc file.
  static Future<String> createBackup({SharedPreferences? prefs}) async {
    final p2 = prefs ?? await SharedPreferences.getInstance();
    final key = await EncryptionService.getOrCreateKey(prefs: p2);
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final archivePath = p.join(tempDir.path, 'dvb_backup_$ts.tar');
    final encPath = p.join(tempDir.path, 'dvb_backup_$ts$backupExtension');

    try {
      final archive = Archive();

      // 1. Collect SharedPreferences as JSON
      final prefsData = _collectPrefsData(p2);
      final prefsJson = utf8.encode(jsonEncode(prefsData));
      archive.addFile(ArchiveFile('prefs.json', prefsJson.length, prefsJson));

      // 2. Collect media files
      await _addMediaDir(archive, 'journal_images', await _journalImagesDir());
      await _addMediaDir(archive, 'journal_audio', await _journalAudioDir());
      await _addMediaDir(archive, 'vision_images', await _visionImagesDir());

      // 3. Write tar archive
      final tarBytes = TarEncoder().encode(archive);
      await File(archivePath).writeAsBytes(tarBytes, flush: true);

      // 4. Encrypt
      await EncryptionService.encryptFile(
        inputPath: archivePath,
        outputPath: encPath,
        key: key,
      );

      return encPath;
    } finally {
      // Cleanup unencrypted tar
      try {
        await File(archivePath).delete();
      } catch (_) {}
    }
  }

  /// Restore from an encrypted backup file at [encryptedPath].
  /// Returns true on success.
  static Future<bool> restoreBackup({
    required String encryptedPath,
    SharedPreferences? prefs,
  }) async {
    final p2 = prefs ?? await SharedPreferences.getInstance();
    final key = await EncryptionService.getOrCreateKey(prefs: p2);
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tarPath = p.join(tempDir.path, 'dvb_restore_$ts.tar');

    try {
      // 1. Decrypt
      await EncryptionService.decryptFile(
        inputPath: encryptedPath,
        outputPath: tarPath,
        key: key,
      );

      // 2. Extract tar
      final tarBytes = await File(tarPath).readAsBytes();
      final archive = TarDecoder().decodeBytes(tarBytes);

      // 3. Restore SharedPreferences
      final prefsFile = archive.findFile('prefs.json');
      if (prefsFile != null) {
        final json = jsonDecode(utf8.decode(prefsFile.content as List<int>))
            as Map<String, dynamic>;
        await _restorePrefsData(p2, json);
      }

      // 4. Restore media files
      await _restoreMediaDir(archive, 'journal_images', await _journalImagesDir());
      await _restoreMediaDir(archive, 'journal_audio', await _journalAudioDir());
      await _restoreMediaDir(archive, 'vision_images', await _visionImagesDir());

      return true;
    } catch (e) {
      return false;
    } finally {
      try {
        await File(tarPath).delete();
      } catch (_) {}
    }
  }

  /// Estimated backup size in bytes (unencrypted, before compression).
  static Future<int> estimateBackupSize({SharedPreferences? prefs}) async {
    final p2 = prefs ?? await SharedPreferences.getInstance();
    int size = 0;

    final prefsData = _collectPrefsData(p2);
    size += utf8.encode(jsonEncode(prefsData)).length;

    size += await _dirSize(await _journalImagesDir());
    size += await _dirSize(await _journalAudioDir());
    size += await _dirSize(await _visionImagesDir());

    return size;
  }

  // ---- SharedPreferences collection ----

  static Map<String, dynamic> _collectPrefsData(SharedPreferences prefs) {
    final data = <String, dynamic>{};
    final allKeys = prefs.getKeys();

    for (final key in allKeys) {
      if (_shouldBackupKey(key)) {
        final val = prefs.get(key);
        if (val != null) data[key] = val;
      }
    }
    return data;
  }

  static bool _shouldBackupKey(String key) {
    if (_prefixesToBackup.contains(key)) return true;
    for (final prefix in _dynamicPrefixes) {
      if (key.startsWith(prefix)) return true;
    }
    return false;
  }

  static Future<void> _restorePrefsData(
    SharedPreferences prefs,
    Map<String, dynamic> data,
  ) async {
    for (final entry in data.entries) {
      final key = entry.key;
      final val = entry.value;
      if (val is String) {
        await prefs.setString(key, val);
      } else if (val is int) {
        await prefs.setInt(key, val);
      } else if (val is double) {
        await prefs.setDouble(key, val);
      } else if (val is bool) {
        await prefs.setBool(key, val);
      } else if (val is List) {
        await prefs.setStringList(key, val.cast<String>());
      }
    }
  }

  // ---- Media file collection ----

  static Future<String> _journalImagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'journal_images');
  }

  static Future<String> _journalAudioDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'journal_audio');
  }

  static Future<String> _visionImagesDir() async {
    final support = await getApplicationSupportDirectory();
    return p.join(support.path, 'vision_images');
  }

  static Future<void> _addMediaDir(
    Archive archive,
    String archivePrefix,
    String dirPath,
  ) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: dirPath);
        final bytes = await entity.readAsBytes();
        archive.addFile(
          ArchiveFile('$archivePrefix/$relativePath', bytes.length, bytes),
        );
      }
    }
  }

  static Future<void> _restoreMediaDir(
    Archive archive,
    String archivePrefix,
    String dirPath,
  ) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith('$archivePrefix/')) {
        final relativePath = file.name.substring('$archivePrefix/'.length);
        final targetPath = p.join(dirPath, relativePath);
        final targetDir = Directory(p.dirname(targetPath));
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        await File(targetPath).writeAsBytes(file.content as List<int>);
      }
    }
  }

  static Future<int> _dirSize(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
