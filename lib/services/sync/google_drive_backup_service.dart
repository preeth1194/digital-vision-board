import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveBackupService {
  GoogleDriveBackupService._();

  static const _folderIdKey = 'dv_google_drive_folder_id_v1';
  static const _folderName = 'Digital Vision Board';
  static const _boardBackupPrefix = 'dv_board_drive_bg_file_id_v1_';

  // Minimal scope: can create/read files created by this app.
  static const _scopes = <String>[
    drive.DriveApi.driveFileScope,
  ];

  static GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  static Future<String> backupPng({
    required String filePath,
    required String fileName,
  }) async {
    if (kIsWeb) {
      throw Exception('Google Drive backup is not supported on web yet.');
    }

    final f = File(filePath);
    if (!await f.exists()) throw Exception('File not found: $filePath');

    // Initialize GoogleSignIn if not already initialized
    await _googleSignIn.initialize();

    // Try lightweight authentication first, then full authentication if needed
    GoogleSignInAccount? account = await _googleSignIn.attemptLightweightAuthentication();
    if (account == null) {
      account = await _googleSignIn.authenticate(scopeHint: _scopes);
    }
    if (account == null) {
      throw Exception('Google sign-in cancelled.');
    }

    // Request authorization for scopes to get access token
    final authorization = await account.authorizationClient.authorizeScopes(_scopes);
    if (authorization.accessToken == null) {
      throw Exception('Failed to get authorization for Drive access.');
    }

    final headers = <String, String>{
      'Authorization': 'Bearer ${authorization.accessToken!}',
    };
    final client = _GoogleAuthClient(headers);
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
      if (id == null || id.isEmpty) throw Exception('Drive upload failed (missing file id).');
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
    if (kIsWeb) {
      throw Exception('Google Drive download is not supported on web yet.');
    }

    // Initialize GoogleSignIn if not already initialized
    await _googleSignIn.initialize();

    // Try lightweight authentication first, then full authentication if needed
    GoogleSignInAccount? account = await _googleSignIn.attemptLightweightAuthentication();
    if (account == null) {
      account = await _googleSignIn.authenticate(scopeHint: _scopes);
    }
    if (account == null) {
      throw Exception('Google sign-in cancelled.');
    }

    // Request authorization for scopes to get access token
    final authorization = await account.authorizationClient.authorizeScopes(_scopes);
    if (authorization.accessToken == null) {
      throw Exception('Failed to get authorization for Drive access.');
    }

    final headers = <String, String>{
      'Authorization': 'Bearer ${authorization.accessToken!}',
    };
    final client = _GoogleAuthClient(headers);
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

