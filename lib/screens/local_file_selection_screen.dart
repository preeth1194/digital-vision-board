import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

import '../services/music_provider_service.dart';
import '../utils/app_typography.dart';

/// Screen for selecting local audio files from device storage
class LocalFileSelectionScreen extends StatefulWidget {
  const LocalFileSelectionScreen({super.key});

  @override
  State<LocalFileSelectionScreen> createState() => _LocalFileSelectionScreenState();
}

class _LocalFileSelectionScreenState extends State<LocalFileSelectionScreen> {
  final LocalFileProvider _localFileProvider = LocalFileProvider();
  List<String> _selectedFiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedFiles();
  }

  Future<void> _loadSelectedFiles() async {
    setState(() => _loading = true);
    try {
      final files = await _localFileProvider.getSelectedFiles();
      if (mounted) {
        setState(() {
          _selectedFiles = files;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePaths = result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();

        await _localFileProvider.addFiles(filePaths);
        await _loadSelectedFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${filePaths.length} file(s) added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFile(String filePath) async {
    await _localFileProvider.removeFile(filePath);
    await _loadSelectedFiles();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File removed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _clearAllFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Files'),
        content: const Text('Are you sure you want to remove all selected files?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _localFileProvider.clearFiles();
      await _loadSelectedFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All files cleared'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _confirmSelection() {
    Navigator.of(context).pop({
      'selected': true,
    });
  }

  String _getFileName(String filePath) {
    return path.basename(filePath);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Local Files'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearAllFiles,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Add files button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Audio Files'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
                // Files list
                Expanded(
                  child: _selectedFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_off,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No files selected',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap "Add Audio Files" to select audio files from your device',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final filePath = _selectedFiles[index];
                            final fileName = _getFileName(filePath);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: Icon(
                                  Icons.audiotrack,
                                  color: colorScheme.primary,
                                ),
                                title: Text(
                                  fileName,
                                  style: AppTypography.body(context).copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: FutureBuilder<FileStat>(
                                  future: File(filePath).stat(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Text(
                                        _formatFileSize(snapshot.data!.size),
                                        style: AppTypography.caption(context),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _removeFile(filePath),
                                  tooltip: 'Remove',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedFiles.isEmpty
                      ? 'No files selected'
                      : '${_selectedFiles.length} file${_selectedFiles.length == 1 ? '' : 's'} selected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _selectedFiles.isNotEmpty ? _confirmSelection : null,
                icon: const Icon(Icons.check),
                label: const Text('Confirm'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
