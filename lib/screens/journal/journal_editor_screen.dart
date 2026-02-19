import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';

import '../../models/journal_entry.dart';
import '../../services/journal_storage_service.dart';
import '../../services/journal_image_storage_service.dart';
import 'models/journal_editor_models.dart';
import 'widgets/editor_spacing.dart';
import 'widgets/font_picker.dart';
import 'widgets/editor_app_bar.dart';
import 'widgets/editor_tag_chip.dart';
import 'widgets/image_embed.dart';
import 'widgets/audio_embed.dart';

final class JournalEntryEditorScreen extends StatefulWidget {
  final List<String> goalTitles;
  final List<String> existingTags;
  final JournalEntry? existingEntry;
  /// When true, opens the voice recorder sheet automatically after build.
  final bool autoShowVoiceRecorder;
  /// Pre-fill title for a brand-new entry (from the new-diary overlay).
  final String? initialTitle;
  /// Pre-fill tags for a brand-new entry (from the new-diary overlay).
  final List<String>? initialTags;
  /// The book this entry belongs to.
  final String? bookId;

  const JournalEntryEditorScreen({
    required this.goalTitles,
    required this.existingTags,
    this.existingEntry,
    this.autoShowVoiceRecorder = false,
    this.initialTitle,
    this.initialTags,
    this.bookId,
  });

  @override
  State<JournalEntryEditorScreen> createState() => _JournalEntryEditorScreenState();
}

class _JournalEntryEditorScreenState extends State<JournalEntryEditorScreen> with WidgetsBindingObserver {
  late quill.QuillController _controller; // Not final - can be replaced on page navigation
  late final FocusNode _focusNode;
  final TextEditingController _titleController = TextEditingController();
  bool _focused = false;
  final Set<String> _tags = <String>{};
  final List<String> _imagePaths = <String>[];
  final List<String> _audioPaths = <String>[];
  final ImagePicker _imagePicker = ImagePicker();
  bool _hasUnsavedChanges = false;
  String? _entryId; // Track entry ID for auto-save updates
  Timer? _autoSaveTimer;
  StreamSubscription? _contentChangesSubscription;
  StreamSubscription? _titleChangesSubscription;
  SaveStatus _saveStatus = SaveStatus.idle;

  // Font selection
  EditorFont _selectedFont = EditorFont.merriweather;
  static const String _fontPrefKey = 'journal_editor_font_v1';

  // Font size overlay
  OverlayEntry? _fontSizeOverlay;
  final GlobalKey _fontSizeBtnKey = GlobalKey();
  final LayerLink _fontSizeLayerLink = LayerLink();

  late ScrollController _scrollController;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!mounted) return;
      if (!_focusNode.hasFocus) _dismissFontSizeOverlay();
      setState(() => _focused = _focusNode.hasFocus);
    });

    // Initialize scroll controller
    _scrollController = ScrollController();

    // Initialize with existing entry data if editing
    if (widget.existingEntry != null) {
      final entry = widget.existingEntry!;
      _entryId = entry.id;
      _titleController.text = entry.title ?? '';
      _tags.addAll(entry.tags);
      _imagePaths.addAll(entry.imagePaths);
      _audioPaths.addAll(entry.audioPaths);

      // Load saved font preference from entry
      if (entry.selectedFont != null) {
        _selectedFont = EditorFont.values.firstWhere(
          (f) => f.name == entry.selectedFont,
          orElse: () => EditorFont.merriweather,
        );
      }

      // Load delta into controller
      if (entry.delta is List && (entry.delta as List).isNotEmpty) {
        try {
          final doc = quill.Document.fromJson(entry.delta as List);
          _controller = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        } catch (_) {
          _controller = quill.QuillController.basic();
        }
      } else {
        _controller = quill.QuillController.basic();
      }
    } else {
      // Create new entry — optionally pre-fill from the new-diary overlay
      _controller = quill.QuillController.basic();
      if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
        _titleController.text = widget.initialTitle!;
      }
      if (widget.initialTags != null) {
        _tags.addAll(widget.initialTags!);
      }
    }

    // Track content changes for auto-save and keep cursor visible
    _contentChangesSubscription = _controller.document.changes.listen((event) {
      if (mounted) {
        setState(() => _hasUnsavedChanges = true);
        _scheduleAutoSave();
        // Keep cursor in view after content changes (typing, paste, etc.)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focused) _ensureCursorVisible();
        });
      }
    });
    // Track title changes for auto-save
    _titleController.addListener(() {
      if (mounted) {
        setState(() => _hasUnsavedChanges = true);
        _scheduleAutoSave();
      }
    });
    // Auto-focus for distraction-free writing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      // Auto-show voice recorder if launched from landing page Record button
      if (widget.autoShowVoiceRecorder) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _showVoiceRecorder();
        });
      }
    });

    // Load saved font preference
    _loadFontPreference();
  }

  Future<void> _loadFontPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFont = prefs.getString(_fontPrefKey);
    if (savedFont != null && mounted) {
      final font = EditorFont.values.firstWhere(
        (f) => f.name == savedFont,
        orElse: () => EditorFont.merriweather,
      );
      setState(() => _selectedFont = font);
    }
  }

  Future<void> _saveFontPreference(EditorFont font) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontPrefKey, font.name);
  }

  void _showFontPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FontPickerSheet(
        selectedFont: _selectedFont,
        onFontSelected: (font) {
          setState(() => _selectedFont = font);
          _saveFontPreference(font);
          Navigator.pop(context);
        },
      ),
    );
  }

  /// Initialize floating images from stored image paths (for new entries)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle all lifecycle states that indicate app is closing or going to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // Save immediately when app goes to background or is closing
      if (_hasUnsavedChanges) {
        _autoSaveTimer?.cancel();
        // Use _saveSync for lifecycle events - no UI updates needed
        _saveSync().catchError((_) {
          // Silent failure - acceptable for lifecycle saves
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();

    // Save unsaved changes before disposing (fire and forget)
    // This ensures data is saved even if widget is disposed unexpectedly
    if (_hasUnsavedChanges && mounted) {
      _saveSync().catchError((_) {
        // Silent failure - acceptable in dispose
      });
    }

    _contentChangesSubscription?.cancel();
    _titleChangesSubscription?.cancel();
    _scrollController.dispose();
    _fontSizeOverlay?.remove();
    _fontSizeOverlay = null;
    _controller.dispose();
    _focusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  /// Scrolls so the cursor line sits near the top of the viewport,
  /// giving the user plenty of visible space below to continue typing.
  void _ensureCursorVisible() {
    if (!_scrollController.hasClients) return;

    // Estimate cursor Y from the number of newlines before the cursor.
    final cursorOffset = _controller.selection.baseOffset;
    if (cursorOffset < 0) return;

    final plainText = _controller.document.toPlainText();
    final textBeforeCursor = cursorOffset <= plainText.length
        ? plainText.substring(0, cursorOffset)
        : plainText;
    final lineCount = '\n'.allMatches(textBeforeCursor).length;

    // Header area height (date + title + tags + divider + spacing)
    const headerHeight = 160.0;
    final cursorY = headerHeight + (lineCount * EditorSpacing.lineHeight);

    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    // If cursor is below the visible area, scroll so the cursor line
    // appears roughly 20% from the top of the viewport.
    final cursorBottomEdge = cursorY + EditorSpacing.lineHeight;
    if (cursorBottomEdge > currentScroll + viewportHeight) {
      final target = (cursorY - viewportHeight * 0.2).clamp(0.0, maxScroll);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _hasUnsavedChanges) {
        _autoSave();
      }
    });
  }

  Future<void> _autoSave() async {
    if (!_hasUnsavedChanges) return;

    final deltaJson = _controller.document.toDelta().toJson();
    final plain = _controller.document.toPlainText().replaceAll('\r', '').trim();

    if (plain.isEmpty && _imagePaths.isEmpty) {
      return; // Don't save empty entries automatically
    }

    final userTitle = _titleController.text.trim();
    final title = userTitle.isNotEmpty
        ? userTitle
        : _deriveTitleFromDeltaOrPlain(deltaJson: deltaJson, plainText: plain);
    final tagsNorm = _tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    String? legacyGoal;
    for (final t in tagsNorm) {
      if (widget.goalTitles.contains(t)) {
        legacyGoal = t;
        break;
      }
    }

    if (!mounted) return;
    setState(() => _saveStatus = SaveStatus.saving);

    try {
      final prefs = await SharedPreferences.getInstance();
      JournalEntry? entry;

      if (_entryId != null) {
        // Update existing entry
        entry = await JournalStorageService.updateEntry(
          id: _entryId!,
          title: title,
          text: plain,
          delta: deltaJson,
          tags: tagsNorm,
          goalTitle: legacyGoal,
          imagePaths: _imagePaths,
          audioPaths: _audioPaths,
          prefs: prefs,
        );
      } else {
        // Create new entry
        entry = await JournalStorageService.addEntry(
          title: title,
          text: plain,
          delta: deltaJson,
          tags: tagsNorm,
          goalTitle: legacyGoal,
          imagePaths: _imagePaths,
          audioPaths: _audioPaths,
          bookId: widget.bookId,
          prefs: prefs,
        );
        if (entry != null) {
          _entryId = entry.id;
        }
      }

      // Update image paths with actual entry ID if needed
      if (entry != null && _imagePaths.isNotEmpty) {
        final updatedImagePaths = <String>[];
        for (int i = 0; i < _imagePaths.length; i++) {
          final oldPath = _imagePaths[i];
          final oldFile = File(oldPath);
          if (await oldFile.exists()) {
            // Check if path already has the correct entry ID
            if (!oldPath.contains(entry.id)) {
              final newPath = await JournalImageStorageService.saveImage(
                oldFile,
                entry.id,
                i,
              );
              updatedImagePaths.add(newPath);
              await JournalImageStorageService.deleteImage(oldPath);
            } else {
              updatedImagePaths.add(oldPath);
            }
          }
        }

        if (updatedImagePaths.isNotEmpty && updatedImagePaths != _imagePaths) {
          await JournalStorageService.updateEntry(
            id: entry.id,
            imagePaths: updatedImagePaths,
            prefs: prefs,
          );
          setState(() {
            _imagePaths.clear();
            _imagePaths.addAll(updatedImagePaths);
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _hasUnsavedChanges = false;
        _saveStatus = SaveStatus.saved;
      });

      // Reset status to idle after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _saveStatus == SaveStatus.saved) {
          setState(() => _saveStatus = SaveStatus.idle);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveStatus = SaveStatus.error);
      // Reset error status after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _saveStatus == SaveStatus.error) {
          setState(() => _saveStatus = SaveStatus.idle);
        }
      });
    }
  }

  /// Synchronous save method without UI updates (for dispose and lifecycle handlers)
  Future<void> _saveSync() async {
    if (!_hasUnsavedChanges) return;

    final deltaJson = _controller.document.toDelta().toJson();
    final plain = _controller.document.toPlainText().replaceAll('\r', '').trim();

    if (plain.isEmpty && _imagePaths.isEmpty) {
      return; // Don't save empty entries
    }

    final userTitle = _titleController.text.trim();
    final title = userTitle.isNotEmpty
        ? userTitle
        : _deriveTitleFromDeltaOrPlain(deltaJson: deltaJson, plainText: plain);
    final tagsNorm = _tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    String? legacyGoal;
    for (final t in tagsNorm) {
      if (widget.goalTitles.contains(t)) {
        legacyGoal = t;
        break;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      JournalEntry? entry;

      if (_entryId != null) {
        // Update existing entry
        entry = await JournalStorageService.updateEntry(
          id: _entryId!,
          title: title,
          text: plain,
          delta: deltaJson,
          tags: tagsNorm,
          goalTitle: legacyGoal,
          imagePaths: _imagePaths,
          audioPaths: _audioPaths,
          selectedFont: _selectedFont.name,
          prefs: prefs,
        );
      } else {
        // Create new entry
        entry = await JournalStorageService.addEntry(
          title: title,
          text: plain,
          delta: deltaJson,
          tags: tagsNorm,
          goalTitle: legacyGoal,
          imagePaths: _imagePaths,
          audioPaths: _audioPaths,
          selectedFont: _selectedFont.name,
          prefs: prefs,
        );
        if (entry != null) {
          _entryId = entry.id;
        }
      }

      // Update image paths with actual entry ID if needed
      if (entry != null && _imagePaths.isNotEmpty) {
        final updatedImagePaths = <String>[];
        for (int i = 0; i < _imagePaths.length; i++) {
          final oldPath = _imagePaths[i];
          final oldFile = File(oldPath);
          if (await oldFile.exists()) {
            // Check if path already has the correct entry ID
            if (!oldPath.contains(entry.id)) {
              final newPath = await JournalImageStorageService.saveImage(
                oldFile,
                entry.id,
                i,
              );
              updatedImagePaths.add(newPath);
              await JournalImageStorageService.deleteImage(oldPath);
            } else {
              updatedImagePaths.add(oldPath);
            }
          }
        }

        if (updatedImagePaths.isNotEmpty && updatedImagePaths != _imagePaths) {
          await JournalStorageService.updateEntry(
            id: entry.id,
            imagePaths: updatedImagePaths,
            prefs: prefs,
          );
          // Don't update state in sync save - widget may be disposed
        }
      }

      // Mark as saved without UI updates
      _hasUnsavedChanges = false;
    } catch (e) {
      // Silent failure - acceptable for sync saves in dispose/lifecycle
      // The user won't see feedback anyway
    }
  }

  /// Public method to save editor content (called from back button handler)
  Future<bool> save() async {
    // Cancel any pending auto-save
    _autoSaveTimer?.cancel();

    if (!_hasUnsavedChanges) return true;

    final deltaJson = _controller.document.toDelta().toJson();
    final plain = _controller.document.toPlainText().replaceAll('\r', '').trim();

    if (plain.isEmpty && _imagePaths.isEmpty) {
      // Allow saving empty if user explicitly wants to
      return true;
    }

    final userTitle = _titleController.text.trim();
    final title = userTitle.isNotEmpty
        ? userTitle
        : _deriveTitleFromDeltaOrPlain(deltaJson: deltaJson, plainText: plain);
    final tagsNorm = _tags.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    String? legacyGoal;
    for (final t in tagsNorm) {
      if (widget.goalTitles.contains(t)) {
        legacyGoal = t;
        break;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      JournalEntry? entry;

      if (_entryId != null) {
        // Update existing entry
        entry = await JournalStorageService.updateEntry(
          id: _entryId!,
          title: title,
          text: plain,
          delta: deltaJson,
          tags: tagsNorm,
          goalTitle: legacyGoal,
          imagePaths: _imagePaths,
          audioPaths: _audioPaths,
          selectedFont: _selectedFont.name,
          prefs: prefs,
        );
      } else {
        // Create new entry
        entry = await JournalStorageService.addEntry(
          title: title,
          text: plain,
          delta: deltaJson,
          tags: tagsNorm,
          goalTitle: legacyGoal,
          imagePaths: _imagePaths,
          audioPaths: _audioPaths,
          selectedFont: _selectedFont.name,
          prefs: prefs,
        );
        if (entry != null) {
          _entryId = entry.id;
        }
      }

      // Update image paths with actual entry ID
      if (entry != null && _imagePaths.isNotEmpty) {
        final updatedImagePaths = <String>[];
        for (int i = 0; i < _imagePaths.length; i++) {
          final oldPath = _imagePaths[i];
          final oldFile = File(oldPath);
          if (await oldFile.exists()) {
            // Check if path already has the correct entry ID
            if (!oldPath.contains(entry.id)) {
              final newPath = await JournalImageStorageService.saveImage(
                oldFile,
                entry.id,
                i,
              );
              updatedImagePaths.add(newPath);
              await JournalImageStorageService.deleteImage(oldPath);
            } else {
              updatedImagePaths.add(oldPath);
            }
          }
        }

        if (updatedImagePaths.isNotEmpty && updatedImagePaths != _imagePaths) {
          await JournalStorageService.updateEntry(
            id: entry.id,
            imagePaths: updatedImagePaths,
            prefs: prefs,
          );
          setState(() {
            _imagePaths.clear();
            _imagePaths.addAll(updatedImagePaths);
          });
        }
      }

      _hasUnsavedChanges = false;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _pickTags() async {
    final goals = widget.goalTitles;
    final existing = widget.existingTags;
    final all = <String>{
      ...existing.map((e) => e.trim()).where((e) => e.isNotEmpty),
      ...goals.map((e) => e.trim()).where((e) => e.isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final q = TextEditingController();
        List<String> filtered = List.of(all);
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void applyFilter(String v) {
              final t = v.trim().toLowerCase();
              setLocal(() {
                filtered = (t.isEmpty)
                    ? List.of(all)
                    : all.where((g) => g.toLowerCase().contains(t)).toList();
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + MediaQuery.of(ctx).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Tag (optional)', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: q,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search or add a tag…',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: applyFilter,
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length + 2,
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            return ListTile(
                              leading: const Icon(Icons.done),
                              title: const Text('Done'),
                              onTap: () => Navigator.of(ctx).pop(),
                            );
                          }
                          if (i == 1) {
                            final candidate = q.text.trim();
                            final canAdd = candidate.isNotEmpty && !all.any((t) => t.toLowerCase() == candidate.toLowerCase());
                            if (!canAdd) return const SizedBox.shrink();
                            return ListTile(
                              leading: const Icon(Icons.add),
                              title: Text('Add "$candidate"'),
                              onTap: () {
                                setState(() {
                                  _tags.add(candidate);
                                  _hasUnsavedChanges = true;
                                  _scheduleAutoSave();
                                });
                                setLocal(() {
                                  q.clear();
                                  filtered = List.of(all);
                                });
                              },
                            );
                          }
                          final g = filtered[i - 2];
                          final selected = _tags.contains(g);
                          return ListTile(
                            leading: Icon(selected ? Icons.check_box : Icons.check_box_outline_blank),
                            title: Text(g),
                            trailing: goals.contains(g) ? const Icon(Icons.flag_outlined) : null,
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _tags.remove(g);
                                } else {
                                  _tags.add(g);
                                }
                                _hasUnsavedChanges = true;
                                _scheduleAutoSave();
                              });
                              setLocal(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _deriveTitleFromDeltaOrPlain({
    required List<dynamic> deltaJson,
    required String plainText,
  }) {
    // 1) If the user used a header style, Quill stores the 'header' attribute on the newline op.
    // We'll scan line-by-line: when we hit a newline with header attribute, use that line's text.
    final words = plainText.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final fallback = words.isEmpty ? 'Journal' : words.take(3).join(' ');

    try {
      final ops = deltaJson.whereType<Map>().toList();
      var lineBuf = StringBuffer();
      for (final op in ops) {
        final insert = op['insert'];
        final attrs = op['attributes'];
        if (insert is! String) continue;

        for (var i = 0; i < insert.length; i++) {
          final ch = insert[i];
          if (ch == '\n') {
            final header = (attrs is Map) ? attrs['header'] : null;
            final line = lineBuf.toString().trim();
            lineBuf = StringBuffer();
            if (header != null && line.isNotEmpty) {
              return line;
            }
          } else {
            lineBuf.write(ch);
          }
        }
      }
    } catch (_) {}

    return fallback;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      if (!await file.exists()) return;

      // Generate a temporary entry ID for saving (will be replaced when entry is actually saved)
      final tempEntryId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final savedPath = await JournalImageStorageService.saveImage(
        file,
        tempEntryId,
        _imagePaths.length,
      );

      setState(() {
        _imagePaths.add(savedPath);
        _hasUnsavedChanges = true;
      });

      // Insert image as inline embed at cursor position
      final imageData = jsonEncode({'path': savedPath, 'width': 300.0});
      final embed = quill.BlockEmbed.image(imageData);
      final index = _controller.selection.baseOffset;
      final length = _controller.selection.extentOffset - index;
      _controller.replaceText(index, length, embed, null);

      _scheduleAutoSave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
      );
    }
  }

  void _showVoiceRecorder() {
    final entryId = _entryId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceRecorderSheet(
        entryId: entryId,
        onRecordingComplete: (String audioPath) {
          setState(() {
            _audioPaths.add(audioPath);
            _hasUnsavedChanges = true;
          });

          // Insert audio embed at cursor position
          final embed = quill.BlockEmbed('audio', audioPath);
          final index = _controller.selection.baseOffset;
          final length = _controller.selection.extentOffset - index;
          _controller.replaceText(index, length, embed, null);

          _scheduleAutoSave();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tagsSorted = _tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Background and paper colors — cream paper on offWhite background
    final bgColor = isDark
        ? colorScheme.surfaceContainerLowest
        : colorScheme.surfaceContainerLowest;
    final paperColor = isDark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surface;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_hasUnsavedChanges) {
          _autoSaveTimer?.cancel();
          final saved = await save();
          if (saved && mounted) {
            Navigator.of(context).pop();
          }
        } else {
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // Minimal app bar
              EditorAppBar(
                isEditing: widget.existingEntry != null,
                saveStatus: _saveStatus,
                onBack: () async {
                  if (_hasUnsavedChanges) {
                    _autoSaveTimer?.cancel();
                    final saved = await save();
                    if (saved && mounted) Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                onAddImage: _pickImage,
                onRecordVoice: _showVoiceRecorder,
                onAddTag: () async {
                  await _pickTags();
                  if (!mounted) return;
                  setState(() {});
                },
                onSelectFont: _showFontPicker,
                selectedFont: _selectedFont,
                onFontSize: _toggleFontSizeOverlay,
                currentFontSize: _currentFontSize,
                fontSizeBtnKey: _fontSizeBtnKey,
                fontSizeLayerLink: _fontSizeLayerLink,
              ),
              // Editor content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(EditorSpacing.pagePadding),
                  child: Container(
                    decoration: BoxDecoration(
                      color: paperColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.onSurface.withOpacity(isDark ? 0.25 : 0.04),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 80,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Page header with date (hidden for Goal Logs entries)
                            if (widget.existingEntry?.id.startsWith('goal_log_') != true) ...[
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  EditorSpacing.contentPadding,
                                  EditorSpacing.elementGap + 4,
                                  EditorSpacing.contentPadding,
                                  0,
                                ),
                                child: Text(
                                  _formatEntryDate(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.primary.withOpacity(0.7),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              SizedBox(height: EditorSpacing.smallGap),
                            ],
                            // Large title field
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: EditorSpacing.contentPadding),
                              child: TextField(
                                controller: _titleController,
                                maxLength: 200,
                                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                decoration: InputDecoration(
                                  hintText: 'Title',
                                  hintStyle: _selectedFont.getTitleStyle(
                                    color: colorScheme.onSurface.withOpacity(0.25),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  counterText: '',
                                ),
                                style: _selectedFont.getTitleStyle(
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: null,
                              ),
                            ),
                            // Tags
                            if (tagsSorted.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  EditorSpacing.contentPadding,
                                  EditorSpacing.smallGap,
                                  EditorSpacing.contentPadding,
                                  0,
                                ),
                                child: Wrap(
                                  spacing: EditorSpacing.smallGap,
                                  runSpacing: EditorSpacing.smallGap,
                                  children: [
                                    for (final t in tagsSorted)
                                      EditorTagChip(
                                        label: t,
                                        onDelete: () => setState(() {
                                          _tags.remove(t);
                                          _hasUnsavedChanges = true;
                                          _scheduleAutoSave();
                                        }),
                                      ),
                                  ],
                                ),
                              ),
                            SizedBox(height: EditorSpacing.elementGap),
                            // Decorative divider
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: EditorSpacing.contentPadding),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: colorScheme.outlineVariant.withOpacity(0.3),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: EditorSpacing.smallGap + 4),
                                    child: Icon(
                                      Icons.auto_stories_outlined,
                                      size: 16,
                                      color: colorScheme.outlineVariant.withOpacity(0.5),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: colorScheme.outlineVariant.withOpacity(0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: EditorSpacing.elementGap),
                            // Quill editor (non-scrollable; parent SingleChildScrollView handles scroll)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: EditorSpacing.smallGap + 4),
                              child: quill.QuillEditor(
                                controller: _controller,
                                focusNode: _focusNode,
                                scrollController: _scrollController,
                                config: quill.QuillEditorConfig(
                                  scrollable: false,
                                  autoFocus: false,
                                  expands: false,
                                  placeholder: 'Begin your story...',
                                  embedBuilders: [
                                    JournalImageEmbedBuilder(
                                      onImageDeleted: (path) {
                                        setState(() {
                                          _imagePaths.remove(path);
                                          _hasUnsavedChanges = true;
                                        });
                                      },
                                    ),
                                    JournalAudioEmbedBuilder(
                                      onAudioDeleted: (path) {
                                        setState(() {
                                          _audioPaths.remove(path);
                                          _hasUnsavedChanges = true;
                                        });
                                      },
                                    ),
                                  ],
                                  padding: EdgeInsets.fromLTRB(
                                    EditorSpacing.elementGap,
                                    0,
                                    EditorSpacing.elementGap,
                                    EditorSpacing.contentPadding + 8,
                                  ),
                                  customStyles: quill.DefaultStyles(
                                    paragraph: quill.DefaultTextBlockStyle(
                                      _selectedFont.getTextStyle(
                                        fontSize: EditorSpacing.bodyFontSize,
                                        color: colorScheme.onSurface.withOpacity(0.9),
                                        height: EditorSpacing.textHeight,
                                      ),
                                      const quill.HorizontalSpacing(0, 0),
                                      const quill.VerticalSpacing(0, 0),
                                      const quill.VerticalSpacing(0, 0),
                                      null,
                                    ),
                                    placeHolder: quill.DefaultTextBlockStyle(
                                      _selectedFont.getTextStyle(
                                        fontSize: EditorSpacing.bodyFontSize,
                                        fontStyle: FontStyle.italic,
                                        color: colorScheme.onSurface.withOpacity(0.3),
                                        height: EditorSpacing.textHeight,
                                      ),
                                      const quill.HorizontalSpacing(0, 0),
                                      const quill.VerticalSpacing(0, 0),
                                      const quill.VerticalSpacing(0, 0),
                                      null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),  // Expanded
              // Inline formatting toolbar above keyboard (only when keyboard is open)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: (_focused && MediaQuery.of(context).viewInsets.bottom > 0)
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 16 * (1 - value)),
                            child: Transform.scale(
                              scale: 0.95 + 0.05 * value,
                              alignment: Alignment.bottomCenter,
                              child: Opacity(
                                opacity: value.clamp(0.0, 1.0),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border(
                              top: BorderSide(
                                color: colorScheme.outlineVariant.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: quill.QuillSimpleToolbar(
                                  controller: _controller,
                                  config: quill.QuillSimpleToolbarConfig(
                                    toolbarSize: 28,
                                    multiRowsDisplay: false,
                                    showDividers: false,
                                    toolbarSectionSpacing: 4,
                                    toolbarRunSpacing: 4,
                                    buttonOptions: const quill.QuillSimpleToolbarButtonOptions(
                                      base: quill.QuillToolbarBaseButtonOptions(
                                        iconSize: 20,
                                        iconButtonFactor: 1.3,
                                      ),
                                    ),
                                    showFontFamily: false,
                                    showFontSize: false,
                                    showHeaderStyle: false,
                                    showStrikeThrough: true,
                                    showInlineCode: false,
                                    showColorButton: true,
                                    showBackgroundColorButton: true,
                                    showClearFormat: true,
                                    showAlignmentButtons: true,
                                    showIndent: true,
                                    showLink: false,
                                    showSearchButton: false,
                                    showSubscript: false,
                                    showSuperscript: false,
                                    showUndo: true,
                                    showRedo: true,
                                    showBoldButton: true,
                                    showItalicButton: true,
                                    showUnderLineButton: true,
                                    showListBullets: true,
                                    showListNumbers: true,
                                    showListCheck: true,
                                    showQuote: true,
                                    showCodeBlock: false,
                                  ),
                                ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Font size overlay ──────────────────────────────────

  static const List<int> _fontSizes = [12, 14, 16, 17, 18, 19, 20, 22, 24, 28, 32, 36, 48, 64, 96];

  int? get _currentFontSize {
    final style = _controller.getSelectionStyle();
    final sizeAttr = style.attributes['size'];
    if (sizeAttr == null || sizeAttr.value == null) return null;
    return int.tryParse(sizeAttr.value.toString());
  }

  void _dismissFontSizeOverlay() {
    _fontSizeOverlay?.remove();
    _fontSizeOverlay = null;
  }

  void _toggleFontSizeOverlay() {
    if (_fontSizeOverlay != null) {
      _dismissFontSizeOverlay();
      return;
    }

    final currentSize = _currentFontSize;

    _fontSizeOverlay = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        return Stack(
          children: [
            // Tap-away dismisser
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismissFontSizeOverlay,
                behavior: HitTestBehavior.opaque,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // Anchored below the font size button
            CompositedTransformFollower(
              link: _fontSizeLayerLink,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
              offset: const Offset(0, 8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, -12 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Material(
                  color: isDark ? cs.surfaceContainerHigh : cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 8,
                  shadowColor: cs.onSurface.withOpacity(0.3),
                  child: Container(
                    width: 100,
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _fontSizes.length,
                      itemBuilder: (context, index) {
                        final size = _fontSizes[index];
                        final isSelected = currentSize == size;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            _controller.formatSelection(
                              quill.Attribute.fromKeyValue('size', size.toString()),
                            );
                            _dismissFontSizeOverlay();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$size',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                    color: isSelected ? cs.primary : cs.onSurface,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_rounded, size: 18, color: cs.primary),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_fontSizeOverlay!);
  }

  String _formatEntryDate() {
    final date = widget.existingEntry?.createdAt ?? DateTime.now();
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

