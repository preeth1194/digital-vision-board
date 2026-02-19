import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Metadata for a backup file on Google Drive.
class DriveBackupInfo {
  final String fileId;
  final String name;
  final DateTime? createdTime;
  final int? sizeBytes;

  const DriveBackupInfo({
    required this.fileId,
    required this.name,
    this.createdTime,
    this.sizeBytes,
  });
}

class GoogleDriveBackupService {
  GoogleDriveBackupService._();

  static const _folderIdKey = 'dv_google_drive_folder_id_v1';
  static const _folderName = 'Digital Vision Board';
  static const _boardBackupPrefix = 'dv_board_drive_bg_file_id_v1_';
  static const _googleLinkedKey = 'dv_google_backup_linked_v1';
  static const maxBackups = 3;

  static const _scopes = <String>[
    drive.DriveApi.driveFileScope,
  ];

  static GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  /// Whether the user has linked Google for backup.
  static Future<bool> isLinked({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getBool(_googleLinkedKey) ?? false;
  }

  static Future<void> setLinked(bool linked, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(_googleLinkedKey, linked);
  }

  static Future<String> backupPng({
    required String filePath,
    required String fileName,
  }) async {
    if (kIsWeb) throw Exception('Not supported on web.');

    final f = File(filePath);
    if (!await f.exists()) throw Exception('File not found: $filePath');

    final client = await _getAuthClient();
    final api = drive.DriveApi(client);

    try {
      final folderId = await _getOrCreateFolderId(api);
      final media = drive.Media(f.openRead(), await f.length());

      final created = await api.files.create(
        drive.File()
          ..name = fileName
          ..parents = [folderId],
        uploadMedia: media,
        $fields: 'id',
      );

      final id = created.id;
      if (id == null || id.isEmpty) throw Exception('Drive upload failed.');
      return id;
    } finally {
      client.close();
    }
  }

  static Future<void> saveBoardBackgroundBackupRef({
    required String boardId,
    required String driveFileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_boardBackupPrefix$boardId', driveFileId);
  }

  static Future<String?> getBoardBackgroundBackupRef({
    required String boardId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('$_boardBackupPrefix$boardId');
    return (id != null && id.isNotEmpty) ? id : null;
  }

  static Future<List<int>> downloadFileBytes({
    required String driveFileId,
  }) async {
    if (kIsWeb) throw Exception('Not supported on web.');

    final client = await _getAuthClient();
    final api = drive.DriveApi(client);

    try {
      final resp = await api.files.get(
        driveFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (resp is! drive.Media) {
        throw Exception('Unexpected Drive download response.');
      }

      final chunks = <int>[];
      await for (final chunk in resp.stream) {
        chunks.addAll(chunk);
      }
      return chunks;
    } finally {
      client.close();
    }
  }

  /// Upload an encrypted backup archive to Google Drive.
  /// Returns the Drive file ID.
  static Future<String> uploadBackupArchive({
    required String filePath,
  }) async {
    if (kIsWeb) throw Exception('Not supported on web.');

    final f = File(filePath);
    if (!await f.exists()) throw Exception('Backup file not found: $filePath');

    final client = await _getAuthClient();
    final api = drive.DriveApi(client);

    try {
      final folderId = await _getOrCreateFolderId(api);
      final fileName =
          'dvb_${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.dvb.enc';
      final media = drive.Media(f.openRead(), await f.length());

      final created = await api.files.create(
        drive.File()
          ..name = fileName
          ..parents = [folderId],
        uploadMedia: media,
        $fields: 'id',
      );

      final id = created.id;
      if (id == null || id.isEmpty) throw Exception('Drive upload failed.');

      await _pruneOldBackups(api, folderId);
      await setLinked(true);
      return id;
    } finally {
      client.close();
    }
  }

  /// List all backup archives in the Drive folder, newest first.
  static Future<List<DriveBackupInfo>> listBackups() async {
    if (kIsWeb) throw Exception('Not supported on web.');

    final client = await _getAuthClient();
    final api = drive.DriveApi(client);

    try {
      final folderId = await _getOrCreateFolderId(api);
      final result = await api.files.list(
        q: "'$folderId' in parents and name contains '.dvb.enc' and trashed = false",
        orderBy: 'createdTime desc',
        $fields: 'files(id,name,createdTime,size)',
        spaces: 'drive',
      );

      return (result.files ?? []).map((f) {
        return DriveBackupInfo(
          fileId: f.id ?? '',
          name: f.name ?? '',
          createdTime: f.createdTime,
          sizeBytes: f.size != null ? int.tryParse(f.size!) : null,
        );
      }).toList();
    } finally {
      client.close();
    }
  }

  /// Download a backup archive to a temp file. Returns the local file path.
  static Future<String> downloadBackupArchive({
    required String driveFileId,
  }) async {
    if (kIsWeb) throw Exception('Not supported on web.');

    final client = await _getAuthClient();
    final api = drive.DriveApi(client);

    try {
      final resp = await api.files.get(
        driveFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (resp is! drive.Media) {
        throw Exception('Unexpected Drive download response.');
      }

      final tempDir = await Directory.systemTemp.createTemp('dvb_restore_');
      final filePath = '${tempDir.path}/backup.dvb.enc';
      final outFile = File(filePath);
      final sink = outFile.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      return filePath;
    } finally {
      client.close();
    }
  }

  /// Link Google account for backup. Returns true if successful.
  static Future<bool> linkGoogleAccount() async {
    if (kIsWeb) return false;
    try {
      final client = await _getAuthClient();
      client.close();
      await setLinked(true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Unlink Google account from backup.
  static Future<void> unlinkGoogleAccount({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(_googleLinkedKey, false);
    await p.remove(_folderIdKey);
  }

  static Future<_GoogleAuthClient> _getAuthClient() async {
    await _googleSignIn.initialize();
    GoogleSignInAccount? account =
        await _googleSignIn.attemptLightweightAuthentication();
    if (account == null) {
      account = await _googleSignIn.authenticate(scopeHint: _scopes);
    }
    if (account == null) throw Exception('Google sign-in cancelled.');

    final authorization =
        await account.authorizationClient.authorizeScopes(_scopes);
    if (authorization.accessToken == null) {
      throw Exception('Failed to get Drive authorization.');
    }

    return _GoogleAuthClient(<String, String>{
      'Authorization': 'Bearer ${authorization.accessToken!}',
    });
  }

  static Future<void> _pruneOldBackups(
    drive.DriveApi api,
    String folderId,
  ) async {
    try {
      final result = await api.files.list(
        q: "'$folderId' in parents and name contains '.dvb.enc' and trashed = false",
        orderBy: 'createdTime desc',
        $fields: 'files(id,name,createdTime)',
        spaces: 'drive',
      );

      final files = result.files ?? [];
      if (files.length <= maxBackups) return;

      for (int i = maxBackups; i < files.length; i++) {
        final fid = files[i].id;
        if (fid != null) {
          try {
            await api.files.delete(fid);
          } catch (_) {}
        }
      }
    } catch (_) {
      // non-fatal
    }
  }

  static Future<String> _getOrCreateFolderId(drive.DriveApi api) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_folderIdKey);
    if (cached != null && cached.isNotEmpty) return cached;

    // With drive.file scope, listing arbitrary folders is limited. We create our
    // app folder once and then cache its id.
    final folder = await api.files.create(
      drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder',
      $fields: 'id',
    );

    final id = folder.id;
    if (id == null || id.isEmpty) throw Exception('Failed to create Drive folder.');
    await prefs.setString(_folderIdKey, id);
    return id;
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

