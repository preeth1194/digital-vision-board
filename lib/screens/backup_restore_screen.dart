import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auto_sync_service.dart';
import '../services/backup_service.dart';
import '../services/google_drive_backup_service.dart';
import '../utils/app_typography.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  SharedPreferences? _prefs;
  bool _linked = false;
  bool _loading = true;
  List<DriveBackupInfo> _backups = [];
  int _estimatedSize = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    _linked = await GoogleDriveBackupService.isLinked(prefs: _prefs);
    _estimatedSize = await BackupService.estimateBackupSize(prefs: _prefs);
    if (_linked) {
      try {
        _backups = await GoogleDriveBackupService.listBackups();
      } catch (_) {}
    }
    await AutoSyncService.loadCachedState(prefs: _prefs);
    if (mounted) setState(() => _loading = false);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Backup & Restore', style: AppTypography.heading3(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_linked) ..._buildNotLinkedSection(scheme),
                if (_linked) ..._buildLinkedSection(scheme),
              ],
            ),
    );
  }

  List<Widget> _buildNotLinkedSection(ColorScheme scheme) {
    return [
      Icon(Icons.cloud_off_outlined, size: 64, color: scheme.onSurfaceVariant),
      const SizedBox(height: 16),
      Text(
        'Keep Your Data Safe',
        style: AppTypography.heading3(context),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        'Link your Google account to back up your boards, journal, '
        'habits, and more to your personal Google Drive \u2014 '
        'encrypted and private.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _linkGoogle,
        icon: const Icon(Icons.link),
        label: const Text('Link Google Account'),
      ),
      const SizedBox(height: 8),
      Text(
        'Estimated backup size: ${_formatBytes(_estimatedSize)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
        textAlign: TextAlign.center,
      ),
    ];
  }

  List<Widget> _buildLinkedSection(ColorScheme scheme) {
    return [
      _buildStatusCard(scheme),
      const SizedBox(height: 16),
      _buildBackupNowButton(scheme),
      const SizedBox(height: 24),
      if (_backups.isNotEmpty) ...[
        Text('Backups on Google Drive',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
        const SizedBox(height: 8),
        ..._backups.map((b) => _buildBackupTile(b, scheme)),
      ],
      if (_backups.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No backups yet.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ),
      const SizedBox(height: 24),
      _buildInfoSection(scheme),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _unlinkGoogle,
        icon: const Icon(Icons.link_off),
        label: const Text('Unlink Google Account'),
        style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
      ),
    ];
  }

  Widget _buildStatusCard(ColorScheme scheme) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: AutoSyncService.state,
      builder: (context, syncState, _) {
        final IconData icon;
        final String title;
        final String subtitle;
        final Color iconColor;

        switch (syncState) {
          case SyncState.syncing:
            icon = Icons.sync;
            title = 'Syncing...';
            subtitle = 'Encrypting and uploading to Google Drive';
            iconColor = scheme.primary;
          case SyncState.error:
            icon = Icons.cloud_off_outlined;
            title = 'Last sync failed';
            subtitle = AutoSyncService.lastError ?? 'Unknown error';
            iconColor = scheme.error;
          case SyncState.success:
          case SyncState.idle:
            icon = Icons.cloud_done_outlined;
            title = AutoSyncService.lastSyncText;
            subtitle = AutoSyncService.nextSyncText.isNotEmpty
                ? '${AutoSyncService.nextSyncText} \u2022 Auto-sync every 24h'
                : 'Auto-sync every 24 hours on app open';
            iconColor = scheme.primary;
        }

        return Card(
          child: ListTile(
            leading: syncState == SyncState.syncing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: iconColor,
                    ),
                  )
                : Icon(icon, color: iconColor),
            title: Text(title),
            subtitle: Text(subtitle,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        );
      },
    );
  }

  Widget _buildBackupNowButton(ColorScheme scheme) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: AutoSyncService.state,
      builder: (context, syncState, _) {
        final syncing = syncState == SyncState.syncing;
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: syncing ? null : _backupNow,
            icon: syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.backup_outlined),
            label: Text(syncing ? 'Backing up...' : 'Back Up Now'),
          ),
        );
      },
    );
  }

  Widget _buildBackupTile(DriveBackupInfo backup, ColorScheme scheme) {
    final date = backup.createdTime;
    final dateStr = date != null
        ? '${date.toLocal().day}/${date.toLocal().month}/${date.toLocal().year} '
            '${date.toLocal().hour.toString().padLeft(2, '0')}:'
            '${date.toLocal().minute.toString().padLeft(2, '0')}'
        : 'Unknown date';
    final sizeStr =
        backup.sizeBytes != null ? _formatBytes(backup.sizeBytes!) : '';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(dateStr),
        subtitle: sizeStr.isNotEmpty ? Text(sizeStr) : null,
        trailing: IconButton(
          icon: const Icon(Icons.restore),
          tooltip: 'Restore this backup',
          onPressed: () => _confirmRestore(backup),
        ),
      ),
    );
  }

  Widget _buildInfoSection(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About backups',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
        const SizedBox(height: 8),
        Text(
          '\u2022 Backups are encrypted with AES-256 before upload\n'
          '\u2022 Auto-sync runs every 24 hours when you open the app\n'
          '\u2022 Last ${GoogleDriveBackupService.maxBackups} backups are kept\n'
          '\u2022 Estimated size: ${_formatBytes(_estimatedSize)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  Future<void> _linkGoogle() async {
    final ok = await GoogleDriveBackupService.linkGoogleAccount();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in was cancelled.')),
        );
      }
      return;
    }
    await _load();
  }

  Future<void> _unlinkGoogle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Google Account?'),
        content: const Text(
            'Auto-sync will stop. Existing backups on Drive are not deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unlink')),
        ],
      ),
    );
    if (confirmed != true) return;
    await GoogleDriveBackupService.unlinkGoogleAccount(prefs: _prefs);
    await _load();
  }

  Future<void> _backupNow() async {
    await AutoSyncService.syncNow(prefs: _prefs);
    await _load();
  }

  Future<void> _confirmRestore(DriveBackupInfo backup) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
            'Choose how to handle your current data:'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('Keep local data')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'replace'),
              child: const Text('Replace all data')),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == 'keep') return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading and restoring backup...')),
    );

    try {
      final localPath = await GoogleDriveBackupService.downloadBackupArchive(
        driveFileId: backup.fileId,
      );
      final ok = await BackupService.restoreBackup(
        encryptedPath: localPath,
        prefs: _prefs,
      );
      try {
        await File(localPath).parent.delete(recursive: true);
      } catch (_) {}

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully. Restart the app for full effect.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed. The backup may be corrupted.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore error: $e')),
      );
    }
  }
}
