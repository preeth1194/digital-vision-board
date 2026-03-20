import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auto_sync_service.dart';
import '../services/backup_service.dart';
import '../services/google_drive_backup_service.dart';
import '../utils/app_typography.dart';
import '../utils/drive_api_setup_helper.dart';

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
        style: AppTypography.body(context).copyWith(
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
        style: AppTypography.bodySmall(context).copyWith(
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
            style: AppTypography.heading3(context)),
        const SizedBox(height: 8),
        ..._backups.map((b) => _buildBackupTile(b, scheme)),
      ],
      if (_backups.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No backups yet.',
                style: AppTypography.secondary(context)),
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
        final String subtitleText;
        final Color iconColor;
        final bool driveApiDisabled;

        switch (syncState) {
          case SyncState.syncing:
            icon = Icons.sync;
            title = 'Syncing...';
            subtitleText = 'Encrypting and uploading to Google Drive';
            iconColor = scheme.primary;
            driveApiDisabled = false;
          case SyncState.error:
            icon = Icons.cloud_off_outlined;
            title = 'Last sync failed';
            subtitleText = AutoSyncService.lastError ?? 'Unknown error';
            iconColor = scheme.error;
            driveApiDisabled = DriveApiSetupHelper.isDriveApiDisabledError(
              AutoSyncService.lastError,
            );
          case SyncState.success:
          case SyncState.idle:
            icon = Icons.cloud_done_outlined;
            title = AutoSyncService.lastSyncText;
            subtitleText = AutoSyncService.nextSyncText.isNotEmpty
                ? '${AutoSyncService.nextSyncText} \u2022 Auto-sync every 24h'
                : 'Auto-sync every 24 hours on app open';
            iconColor = scheme.primary;
            driveApiDisabled = false;
        }

        final Widget subtitleWidget;
        if (syncState == SyncState.error && driveApiDisabled) {
          subtitleWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DriveApiSetupHelper.friendlyMessage,
                style: AppTypography.bodySmall(context).copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Tooltip(
                message:
                    'Enable the Google Drive API for this app\u2019s cloud project',
                child: TextButton(
                  onPressed: () => _openDriveApiConsole(
                    AutoSyncService.lastError ?? '',
                  ),
                  child: Text(
                    'Open Google Cloud Console',
                    style: AppTypography.button(context).copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          subtitleWidget = Text(
            subtitleText,
            style: AppTypography.secondary(context),
          );
        }

        return Card(
          child: ListTile(
            isThreeLine:
                syncState == SyncState.error && driveApiDisabled,
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
            subtitle: subtitleWidget,
          ),
        );
      },
    );
  }

  Future<void> _openDriveApiConsole(String rawError) async {
    final uri = DriveApiSetupHelper.consoleUrlFromDriveError(rawError);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the link.'),
          ),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                    width: 20,
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
    final bulletStyle = AppTypography.bodySmall(context).copyWith(
      color: scheme.onSurfaceVariant,
    );
    Widget bulletLine(String line) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('\u2022 ', style: bulletStyle),
          Expanded(
            child: Text(line, style: bulletStyle),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About backups', style: AppTypography.heading3(context)),
        const SizedBox(height: 8),
        bulletLine('Backups are encrypted with AES-256 before upload'),
        const SizedBox(height: 4),
        bulletLine('Auto-sync runs every 24 hours when you open the app'),
        const SizedBox(height: 4),
        bulletLine(
          'Last ${GoogleDriveBackupService.maxBackups} backups are kept',
        ),
        const SizedBox(height: 4),
        bulletLine('Estimated size: ${_formatBytes(_estimatedSize)}'),
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
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(
            'Restore from backup?',
            style: AppTypography.heading3(ctx),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose how to handle your current data:',
                style: AppTypography.body(ctx).copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'keep'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.outline),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Keep local data',
                  style: AppTypography.button(ctx).copyWith(color: cs.primary),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'replace'),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Replace all data',
                  style: AppTypography.button(ctx).copyWith(color: cs.onError),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  'Cancel',
                  style: AppTypography.button(ctx).copyWith(color: cs.primary),
                ),
              ),
            ],
          ),
        );
      },
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
