import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';
import 'google_drive_backup_service.dart';

enum SyncState { idle, syncing, success, error }

/// Handles automatic 24-hour backup cycle. Checks on app open and resume.
class AutoSyncService {
  AutoSyncService._();

  static const _lastSyncKey = 'dv_last_auto_sync_ms_v1';
  static const syncIntervalMs = 24 * 60 * 60 * 1000;

  static final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);
  static String? lastError;

  static int? _cachedLastSyncMs;

  static int? get lastSyncMs => _cachedLastSyncMs;

  static Duration? get timeUntilNextSync {
    final last = _cachedLastSyncMs;
    if (last == null) return null;
    final nextMs = last + syncIntervalMs;
    final diff = nextMs - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? Duration(milliseconds: diff) : Duration.zero;
  }

  /// Human-readable "last synced" text.
  static String get lastSyncText {
    final ms = _cachedLastSyncMs;
    if (ms == null) return 'Never synced';
    final ago = DateTime.now().millisecondsSinceEpoch - ms;
    if (ago < 60 * 1000) return 'Last synced just now';
    if (ago < 60 * 60 * 1000) return 'Last synced ${ago ~/ (60 * 1000)}m ago';
    if (ago < 24 * 60 * 60 * 1000) {
      return 'Last synced ${ago ~/ (60 * 60 * 1000)}h ago';
    }
    if (ago < 48 * 60 * 60 * 1000) return 'Last synced yesterday';
    return 'Last synced ${ago ~/ (24 * 60 * 60 * 1000)} days ago';
  }

  /// Human-readable next sync countdown.
  static String get nextSyncText {
    final remaining = timeUntilNextSync;
    if (remaining == null) return '';
    if (remaining <= Duration.zero) return 'Sync due';
    final hours = remaining.inHours;
    final mins = remaining.inMinutes % 60;
    if (hours > 0) return 'Next sync in ${hours}h ${mins}m';
    return 'Next sync in ${mins}m';
  }

  /// Called from DashboardScreen init and resume. Runs backup if 24h have passed.
  static Future<void> maybeSyncIfDue({SharedPreferences? prefs}) async {
    if (kIsWeb) return;
    final p = prefs ?? await SharedPreferences.getInstance();
    _cachedLastSyncMs = p.getInt(_lastSyncKey);

    final linked = await GoogleDriveBackupService.isLinked(prefs: p);
    if (!linked) return;

    final last = _cachedLastSyncMs ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < syncIntervalMs) return;

    await _runSync(p);
  }

  /// Manual trigger from drawer or backup screen.
  static Future<void> syncNow({SharedPreferences? prefs}) async {
    if (kIsWeb) return;
    final p = prefs ?? await SharedPreferences.getInstance();
    await _runSync(p);
  }

  static Future<void> _runSync(SharedPreferences prefs) async {
    if (state.value == SyncState.syncing) return;
    state.value = SyncState.syncing;
    lastError = null;

    try {
      final encPath = await BackupService.createBackup(prefs: prefs);
      try {
        await GoogleDriveBackupService.uploadBackupArchive(filePath: encPath);
      } finally {
        try {
          await File(encPath).delete();
        } catch (_) {}
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastSyncKey, now);
      _cachedLastSyncMs = now;
      state.value = SyncState.success;
    } catch (e) {
      lastError = e.toString();
      state.value = SyncState.error;
    }
  }

  /// Reload cached last sync time from prefs.
  static Future<void> loadCachedState({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    _cachedLastSyncMs = p.getInt(_lastSyncKey);
  }
}
