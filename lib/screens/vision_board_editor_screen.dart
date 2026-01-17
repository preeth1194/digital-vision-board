import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Conditional import: File is not available on web
import 'dart:io' if (dart.library.html) 'dart:html' as io;

import '../models/hotspot_model.dart';
import '../models/goal_metadata.dart';
import '../models/vision_components.dart';
import '../services/boards_storage_service.dart';
import '../services/board_scan_service.dart';
import '../services/canva_import_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/image_persistence.dart';
import '../services/image_region_cropper.dart';
import '../services/image_service.dart';
import '../screens/global_insights_screen.dart';
import '../screens/habits_list_screen.dart';
import '../screens/tasks_list_screen.dart';
import '../widgets/editor/add_name_dialog.dart';
import '../widgets/editor/background_options_sheet.dart';
import '../widgets/editor/layers_sheet.dart';
import '../widgets/editor/text_editor_dialog.dart';
import '../widgets/grid/image_source_sheet.dart';
import '../widgets/habit_tracker_sheet.dart';
import '../widgets/vision_board_builder.dart';
import '../widgets/vision_board_hotspot_builder.dart';

class VisionBoardEditorScreen extends StatefulWidget {
  final String boardId;
  final String title;
  final bool initialIsEditing;
  final String? autoImportType; // 'import_physical' or 'import_canva'

  const VisionBoardEditorScreen({
    super.key,
    required this.boardId,
    required this.title,
    required this.initialIsEditing,
    this.autoImportType,
  });

  @override
  State<VisionBoardEditorScreen> createState() => _VisionBoardEditorScreenState();
}

class _VisionBoardEditorScreenState extends State<VisionBoardEditorScreen> {
  static const String _legacyHotspotsKey = 'vision_board_hotspots';

  // Image pick/compress settings (shared for background + image components)
  static const double _pickedImageMaxSide = 2048;
  static const int _pickedImageQuality = 92;

  List<VisionComponent> _components = [];
  String? _selectedComponentId;
  List<HotspotModel> _legacyHotspots = [];

  late bool _isEditing;
  bool _isLoading = true;
  int _viewModeIndex = 0; // 0: Vision Board, 1: Habits, 2: Tasks, 3: Insights

  SharedPreferences? _prefs;
  final ImagePicker _imagePicker = ImagePicker();

  dynamic _selectedImageFile; // File on mobile, null on web
  ImageProvider? _imageProvider;
  Size? _backgroundImageSize;
  Color _backgroundColor = const Color(0xFFF7F7FA);

  String get _componentsKey => BoardsStorageService.boardComponentsKey(widget.boardId);
  String get _imagePathKey => BoardsStorageService.boardImagePathKey(widget.boardId);
  String get _backgroundColorKey => BoardsStorageService.boardBgColorKey(widget.boardId);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialIsEditing;
    _loadSavedImage();
    _initializeStorage();
    
    // Auto-trigger import if specified
    if (widget.autoImportType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.autoImportType == 'import_physical') {
          _importGoalsFromPhysicalVisionBoard();
        } else if (widget.autoImportType == 'import_canva') {
          _importFromCanva();
        }
      });
    }
  }

  Future<void> _initializeStorage() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 200));
        _prefs = await SharedPreferences.getInstance();
      }
      await _loadComponents();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSavedImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? imagePath = prefs.getString(_imagePathKey);

      if (imagePath != null && imagePath.isNotEmpty && !kIsWeb) {
        final io.File imageFile = io.File(imagePath);
        if (await imageFile.exists()) {
          if (!mounted) return;
          setState(() {
            _selectedImageFile = imageFile;
            _imageProvider = FileImage(imageFile);
          });
        }
      } else {
        if (!mounted) return;
        setState(() => _imageProvider = null);
      }

      if (_imageProvider != null) {
        _backgroundImageSize = await _resolveImageSize(_imageProvider!);
        await _maybeMigrateLegacyHotspots();
        if (mounted) setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _imageProvider = null;
        _backgroundImageSize = null;
      });
    }
  }

  Future<Size?> _resolveImageSize(ImageProvider provider) async {
    try {
      final ImageStream stream = provider.resolve(const ImageConfiguration());
      final completer = Completer<ImageInfo>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(info);
        stream.removeListener(listener);
      }, onError: (dynamic error, StackTrace? stackTrace) {
        completer.completeError(error, stackTrace);
        stream.removeListener(listener);
      });
      stream.addListener(listener);
      final info = await completer.future;
      return Size(info.image.width.toDouble(), info.image.height.toDouble());
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveImagePath(String? imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    if (imagePath != null && imagePath.isNotEmpty) {
      await prefs.setString(_imagePathKey, imagePath);
    } else {
      await prefs.remove(_imagePathKey);
    }
  }

  Future<void> _pickBackgroundImage(ImageSource source) async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: _pickedImageMaxSide,
      maxHeight: _pickedImageMaxSide,
      imageQuality: _pickedImageQuality,
    );
    if (pickedFile == null) return;

    if (kIsWeb) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() => _imageProvider = MemoryImage(bytes));
      await _saveImagePath('web_image_selected');
    } else {
      final persistedPath = await persistImageToAppStorage(pickedFile.path);
      final io.File imageFile = io.File(persistedPath ?? pickedFile.path);
      if (!mounted) return;
      setState(() {
        _selectedImageFile = imageFile;
        _imageProvider = FileImage(imageFile);
      });
      await _saveImagePath(imageFile.path);
    }

    if (_imageProvider != null) {
      _backgroundImageSize = await _resolveImageSize(_imageProvider!);
      await _maybeMigrateLegacyHotspots();
      if (mounted) setState(() {});
    }
  }

  Future<void> _showBackgroundImageSourceDialog() async {
    if (kIsWeb) {
      await _pickBackgroundImage(ImageSource.gallery);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickBackgroundImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickBackgroundImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadComponents() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs ??= prefs;

      final bg = prefs.getInt(_backgroundColorKey);
      if (bg != null) _backgroundColor = Color(bg);

      final String? componentsJson = prefs.getString(_componentsKey);
      if (componentsJson != null && componentsJson.isNotEmpty) {
        final decoded = jsonDecode(componentsJson) as List<dynamic>;
        final loaded =
            decoded.map((j) => visionComponentFromJson(j as Map<String, dynamic>)).toList();
        if (!mounted) return;
        setState(() {
          _components = loaded;
          _legacyHotspots = [];
          _isLoading = false;
        });
      } else {
        final String? hotspotsJson = prefs.getString(_legacyHotspotsKey);
        if (hotspotsJson != null && hotspotsJson.isNotEmpty) {
          try {
            final decoded = jsonDecode(hotspotsJson) as List<dynamic>;
            final loadedHotspots =
                decoded.map((j) => HotspotModel.fromJson(j as Map<String, dynamic>)).toList();
            if (mounted) setState(() => _legacyHotspots = loadedHotspots);
          } catch (_) {}
        }
        if (mounted) setState(() => _isLoading = false);
      }

      await _maybeMigrateLegacyHotspots();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _maybeMigrateLegacyHotspots() async {
    if (_components.isNotEmpty) return;
    if (_legacyHotspots.isEmpty) return;
    if (_backgroundImageSize == null) return;

    // New behavior: convert legacy hotspots into real image layers by cropping
    // the corresponding region from the background image. This makes them
    // permanent layers that show up in the Layers sheet and support habits.
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    final bgPath = prefs.getString(_imagePathKey);

    final converted = <VisionComponent>[];
    for (final h in _legacyHotspots) {
      final id = (h.id ?? '').trim().isNotEmpty ? h.id!.trim() : 'Goal';
      final rect = Rect.fromLTWH(
        h.x * _backgroundImageSize!.width,
        h.y * _backgroundImageSize!.height,
        h.width * _backgroundImageSize!.width,
        h.height * _backgroundImageSize!.height,
      );

      String? croppedPath;
      if (bgPath != null && bgPath.isNotEmpty && bgPath != 'web_image_selected' && !kIsWeb) {
        croppedPath = await cropAndPersistImageRegion(
          sourcePath: bgPath,
          region: rect,
          quality: _pickedImageQuality,
        );
      }

      if (croppedPath != null && croppedPath.isNotEmpty) {
        converted.add(
          ImageComponent(
            id: id,
            position: Offset(rect.left, rect.top),
            size: Size(rect.width, rect.height),
            rotation: 0,
            scale: 1,
            zIndex: converted.length,
            habits: h.habits,
            imagePath: croppedPath,
          ),
        );
      } else {
        // Fallback to legacy transparent zone.
        converted.add(convertHotspotToComponent(h, _backgroundImageSize!));
      }
    }

    if (!mounted) return;
    setState(() {
      _components = converted;
      _legacyHotspots = [];
    });
    await _saveComponents();
  }

  Future<void> _createGoalFromBackgroundHotspot() async {
    if (!_isEditing) return;
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hotspots are not supported on web yet.')),
      );
      return;
    }

    final bgProvider = _imageProvider;
    final bgSize = _backgroundImageSize;
    if (bgProvider == null || bgSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a background image first to create hotspots.')),
      );
      return;
    }

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    if (!mounted) return;
    final bgPath = prefs.getString(_imagePathKey);
    if (bgPath == null || bgPath.isEmpty || bgPath == 'web_image_selected') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background image file not available for cropping.')),
      );
      return;
    }

    var hotspots = <HotspotModel>[];
    var selected = <HotspotModel>{};

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog.fullscreen(
            child: SafeArea(
              top: true,
              bottom: false,
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  title: const Text('Create goals from your photo'),
                  actions: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                body: VisionBoardHotspotBuilder(
                  imageProvider: bgProvider,
                  hotspots: hotspots,
                  selectedHotspots: selected,
                  isEditing: true,
                  showLabels: true,
                  onHotspotsChanged: (next) => setDialogState(() => hotspots = next),
                  onHotspotSelected: (h) => setDialogState(() => selected = {h}),
                  onHotspotCreated: (x, y, width, height) async {
                    final categorySuggestions = _components
                        .whereType<ImageComponent>()
                        .map((c) => c.goal?.category)
                        .whereType<String>()
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toSet()
                        .toList();

                    final nameRes = await showAddNameAndCategoryDialog(
                      dialogContext,
                      title: 'Your Vision/Goal',
                      categoryHint: 'Category (optional)',
                      categorySuggestions: categorySuggestions,
                    );
                    if (nameRes == null || nameRes.name.trim().isEmpty) return null;

                    final rect = Rect.fromLTWH(
                      x * bgSize.width,
                      y * bgSize.height,
                      width * bgSize.width,
                      height * bgSize.height,
                    );

                    final croppedPath = await cropAndPersistImageRegion(
                      sourcePath: bgPath,
                      region: rect,
                      quality: _pickedImageQuality,
                    );
                    if (croppedPath == null || croppedPath.isEmpty) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Failed to crop that region. Try again.')),
                        );
                      }
                      return null;
                    }

                    final component = ImageComponent(
                      id: nameRes.name.trim(),
                      position: Offset(rect.left, rect.top),
                      size: Size(rect.width, rect.height),
                      rotation: 0,
                      scale: 1,
                      zIndex: _nextZ(),
                      imagePath: croppedPath,
                      goal: (nameRes.category == null)
                          ? null
                          : GoalMetadata(title: nameRes.name.trim(), category: nameRes.category),
                    );

                    _onComponentsChanged([..._components, component]);
                    if (mounted) setState(() => _selectedComponentId = component.id);

                    return HotspotModel(
                      x: x,
                      y: y,
                      width: width,
                      height: height,
                      id: nameRes.name.trim(),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _importGoalsFromPhysicalVisionBoard() async {
    if (!_isEditing) return;
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import is not supported on web yet.')),
      );
      return;
    }

    final scannedPath = await scanAndCropPhysicalBoard(allowGallery: true);
    if (scannedPath == null || scannedPath.isEmpty) return;
    if (!mounted) return;

    final imageFile = io.File(scannedPath);
    setState(() {
      _selectedImageFile = imageFile;
      _imageProvider = FileImage(imageFile);
      _backgroundImageSize = null;
    });
    await _saveImagePath(scannedPath);

    if (_imageProvider != null) {
      _backgroundImageSize = await _resolveImageSize(_imageProvider!);
      await _maybeMigrateLegacyHotspots();
      if (mounted) setState(() {});
    }

    await _createGoalFromBackgroundHotspot();
  }

  Future<void> _importFromCanva() async {
    if (!_isEditing) return;
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canva import is not supported on web yet.')),
      );
      return;
    }

    try {
      // Ensure we have a dvToken (OAuth deep-link flow).
      var token = await CanvaImportService.getStoredDvToken();
      if (token == null) {
        final url = await CanvaImportService.getOAuthStartUrl();
        await launchUrl(url, mode: LaunchMode.externalApplication);
        token = await CanvaImportService.connectViaOAuth();
      }
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canva connection not completed.')),
        );
        return;
      }

      await CanvaImportService.importLatestPackageIntoBoard(widget.boardId, dvToken: token);
      await _loadSavedImage();
      await _loadComponents();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imported latest Canva package.')),
        );
      }

      // Optional: backup PNG to Google Drive with explicit consent.
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs ??= prefs;
      final bgPath = prefs.getString(_imagePathKey);
      if (!mounted) return;

      if (bgPath != null && bgPath.isNotEmpty && !kIsWeb) {
        final doBackup = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Backup to Google Drive?'),
            content: const Text(
              'Your imported Canva board background was saved on this device. '
              'Do you want to back it up to Google Drive? This will ask you to sign in to Google and grant Drive access.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not now')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Backup')),
            ],
          ),
        );

        if (doBackup == true) {
          try {
            final fileId = await GoogleDriveBackupService.backupPng(
              filePath: bgPath,
              fileName: 'vision_board_${widget.boardId}.png',
            );
            await GoogleDriveBackupService.saveBoardBackgroundBackupRef(
              boardId: widget.boardId,
              driveFileId: fileId,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Backed up to Google Drive (file id: $fileId).')),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Google Drive backup failed. '
                  'Make sure Google Sign-In is configured for Android/iOS. '
                  'Error: ${e.toString()}',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Canva import failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _backupToGoogleDrive() async {
    if (!_isEditing) return;
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Drive backup is not supported on web yet.')),
      );
      return;
    }

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    final bgPath = prefs.getString(_imagePathKey);
    
    if (bgPath == null || bgPath.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No background image found to backup.')),
      );
      return;
    }

    try {
      final fileId = await GoogleDriveBackupService.backupPng(
        filePath: bgPath,
        fileName: 'vision_board_${widget.boardId}.png',
      );
      await GoogleDriveBackupService.saveBoardBackgroundBackupRef(
        boardId: widget.boardId,
        driveFileId: fileId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backed up to Google Drive (file id: $fileId).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google Drive backup failed. '
            'Make sure Google Sign-In is configured for Android/iOS. '
            'Error: ${e.toString()}',
          ),
        ),
      );
    }
  }

  Future<void> _restoreBackgroundFromGoogleDrive() async {
    if (!_isEditing) return;
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Drive restore is not supported on web yet.')),
      );
      return;
    }

    try {
      final fileId = await GoogleDriveBackupService.getBoardBackgroundBackupRef(
        boardId: widget.boardId,
      );
      if (fileId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Google Drive backup found for this board yet.')),
        );
        return;
      }

      final bytes = await GoogleDriveBackupService.downloadFileBytes(driveFileId: fileId);
      final path = await persistImageBytesToAppStorage(bytes, extension: 'png');
      if (path == null || path.isEmpty) throw Exception('Failed to save downloaded image.');

      await _saveImagePath(path);
      await _loadSavedImage();
      await _maybeMigrateLegacyHotspots();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored background from Google Drive.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google Drive restore failed. '
            'Make sure Google Sign-In is configured. '
            'Error: ${e.toString()}',
          ),
        ),
      );
    }
  }

  Future<void> _saveComponents() async {
    if (_isLoading) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;

    await prefs.setString(
      _componentsKey,
      jsonEncode(_components.map((c) => c.toJson()).toList()),
    );
    await prefs.setInt(_backgroundColorKey, _backgroundColor.value);
  }

  void _onComponentsChanged(List<VisionComponent> components) {
    setState(() => _components = components);
    if (!_isLoading) {
      Future.delayed(const Duration(milliseconds: 100), _saveComponents);
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _selectedComponentId = null;
      if (_isEditing) _viewModeIndex = 0;
    });
  }

  int _nextZ() {
    if (_components.isEmpty) return 0;
    return _components.map((c) => c.zIndex).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _openHabitTrackerForComponent(VisionComponent component) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HabitTrackerSheet(
        boardId: widget.boardId,
        component: component,
        onComponentUpdated: (updated) {
          final next = _components.map((c) => c.id == updated.id ? updated : c).toList();
          _onComponentsChanged(next);
        },
      ),
    );
  }

  Future<void> _editSelectedTextComponent() async {
    if (_selectedComponentId == null) return;
    final component = _components.firstWhere((c) => c.id == _selectedComponentId);
    if (component is! TextComponent) return;

    final result = await showTextEditorDialog(
      context,
      initialText: component.text,
      initialStyle: component.style,
      initialTextAlign: component.textAlign,
    );
    if (result == null) return;

    final updated = component.copyWith(text: result.text, style: result.style, textAlign: result.textAlign);
    _onComponentsChanged(_components.map((c) => c.id == component.id ? updated : c).toList());
    setState(() => _selectedComponentId = updated.id);
  }

  Future<void> _addTextComponent() async {
    final result = await showTextEditorDialog(
      context,
      initialText: '',
      initialStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.black),
    );
    if (result == null || result.text.isEmpty) return;

    final name = result.text.length > 20 ? '${result.text.substring(0, 20)}...' : result.text;
    final c = TextComponent(
      id: name,
      position: const Offset(120, 120),
      size: const Size(260, 90),
      rotation: 0,
      scale: 1,
      zIndex: _nextZ(),
      text: result.text,
      style: result.style,
      textAlign: result.textAlign,
    );

    _onComponentsChanged([..._components, c]);
    setState(() => _selectedComponentId = c.id);
  }

  Future<void> _addImageComponent() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add Image is not supported on web yet.')),
      );
      return;
    }

    final ImageSource? source = await showImageSourceSheet(context);
    if (!mounted) return;
    if (source == null) return;

    final String? croppedPath = await ImageService.pickAndCropImage(
      context,
      source: source,
      maxWidth: _pickedImageMaxSide,
      maxHeight: _pickedImageMaxSide,
      imageQuality: _pickedImageQuality,
    );
    if (!mounted) return;
    if (croppedPath == null || croppedPath.isEmpty) return;

    // Get actual image dimensions to set appropriate default size
    final imageFile = io.File(croppedPath);
    Size? imageSize;
    if (await imageFile.exists()) {
      try {
        final imageProvider = FileImage(imageFile);
        imageSize = await _resolveImageSize(imageProvider);
      } catch (_) {
        // If we can't resolve size, use defaults below
      }
    }

    // Use actual image dimensions with reasonable defaults and limits
    // Maintain aspect ratio but cap maximum size
    const minSize = 200.0;
    const maxSize = 800.0;
    Size defaultSize;
    
    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      // Use actual image dimensions, but scale if too large
      double width = imageSize.width;
      double height = imageSize.height;
      
      // Ensure minimum size
      if (width < minSize && height < minSize) {
        final scale = minSize / (width > height ? width : height);
        width = width * scale;
        height = height * scale;
      }
      
      // Cap maximum size while maintaining aspect ratio
      if (width > maxSize || height > maxSize) {
        final scale = maxSize / (width > height ? width : height);
        width = width * scale;
        height = height * scale;
      }
      
      defaultSize = Size(width, height);
    } else {
      // Fallback to a larger default size if we can't detect dimensions
      defaultSize = const Size(500, 400);
    }

    final categorySuggestions = _components
        .whereType<ImageComponent>()
        .map((c) => c.goal?.category)
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final nameRes = await showAddNameAndCategoryDialog(
      context,
      title: 'Your Vision/Goal',
      categoryHint: 'Category (optional)',
      categorySuggestions: categorySuggestions,
    );
    if (nameRes == null || nameRes.name.isEmpty) return;

    final c = ImageComponent(
      id: nameRes.name,
      position: const Offset(120, 120),
      size: defaultSize,
      rotation: 0,
      scale: 1,
      zIndex: _nextZ(),
      imagePath: croppedPath,
      goal: (nameRes.category == null) ? null : GoalMetadata(title: nameRes.name, category: nameRes.category),
    );
    _onComponentsChanged([..._components, c]);
    setState(() => _selectedComponentId = c.id);
  }

  Future<void> _showBackgroundOptions() async {
    if (!mounted) return;
    await showBackgroundOptionsSheet(
      context,
      onPickBackgroundImage: () async {
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
        await _showBackgroundImageSourceDialog();
      },
      onPickColor: (c) {
        setState(() => _backgroundColor = c);
        _saveComponents();
      },
      onClearBackgroundImage: () async {
        setState(() {
          _imageProvider = null;
          _selectedImageFile = null;
          _backgroundImageSize = null;
        });
        await _saveImagePath(null);
      },
    );
  }

  Future<void> _showLayersDialog() async {
    final sorted = List<VisionComponent>.from(_components)
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));

    await showLayersSheet(
      context,
      componentsTopToBottom: sorted,
      selectedId: _selectedComponentId,
      onDelete: (id) {
        final component = _components.cast<VisionComponent?>().firstWhere(
              (c) => c?.id == id,
              orElse: () => null,
            );
        final hasTrackerData = component != null &&
            ((component.habits.isNotEmpty || component.tasks.isNotEmpty) ||
                component.habits.any((h) => h.completedDates.isNotEmpty) ||
                component.tasks.any((t) => t.checklist.any((c) => (c.completedOn ?? '').trim().isNotEmpty)));

        Future<void>(() async {
          bool ok = true;
          if (hasTrackerData) {
            ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete goal?'),
                    content: Text(
                      'Delete "$id"? This will delete all habits, tasks, and streak history associated with this goal.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ) ??
                false;
          }
          if (!ok) return;

          final updated = _components.where((c) => c.id != id).toList();
          _onComponentsChanged(updated);
          if (_selectedComponentId == id) setState(() => _selectedComponentId = null);
          if (mounted) Navigator.of(context).pop();
        });
      },
      onSelect: (id) {
        setState(() => _selectedComponentId = id);
        Navigator.of(context).pop();
      },
      onReorder: (newOrderTopToBottom) {
        final count = newOrderTopToBottom.length;
        final updated = <VisionComponent>[];
        for (int i = 0; i < count; i++) {
          final component = newOrderTopToBottom[i];
          final existing = _components.firstWhere((c) => c.id == component.id);
          updated.add(existing.copyWithCommon(zIndex: count - 1 - i));
        }
        _onComponentsChanged(updated);
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_isEditing) {
      return VisionBoardBuilder(
        components: _components,
        isEditing: true,
        selectedComponentId: _selectedComponentId,
        onSelectedComponentIdChanged: (id) => setState(() => _selectedComponentId = id),
        onComponentsChanged: _onComponentsChanged,
        onOpenComponent: _openHabitTrackerForComponent,
        backgroundColor: _backgroundColor,
        backgroundImage: _imageProvider,
        backgroundImageSize: _backgroundImageSize,
      );
    }

    return switch (_viewModeIndex) {
      1 => HabitsListScreen(components: _components, onComponentsUpdated: _onComponentsChanged),
      2 => TasksListScreen(components: _components, onComponentsUpdated: _onComponentsChanged),
      3 => GlobalInsightsScreen(components: _components),
      _ => VisionBoardBuilder(
          components: _components,
          isEditing: false,
          selectedComponentId: null,
          onSelectedComponentIdChanged: (_) {},
          onComponentsChanged: _onComponentsChanged,
          onOpenComponent: _openHabitTrackerForComponent,
          backgroundColor: _backgroundColor,
          backgroundImage: _imageProvider,
          backgroundImageSize: _backgroundImageSize,
        ),
    };
  }

  Widget _buildBottomBar() {
    return SizedBox(
      height: 80 + MediaQuery.of(context).padding.bottom,
      child: _isEditing
          ? BottomAppBar(
              height: 80,
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    tooltip: 'Add Image',
                    onPressed: _addImageComponent,
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_fields),
                    tooltip: 'Add Text',
                    onPressed: _addTextComponent,
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_paint_outlined),
                    tooltip: 'Background',
                    onPressed: _showBackgroundOptions,
                  ),
                  IconButton(
                    icon: const Icon(Icons.layers_outlined),
                    tooltip: 'Layers',
                    onPressed: _showLayersDialog,
                  ),
                  if (_selectedComponentId != null &&
                      _components.any((c) => c.id == _selectedComponentId && c is TextComponent))
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit Text',
                      onPressed: _editSelectedTextComponent,
                    ),
                ],
              ),
            )
          : BottomNavigationBar(
              currentIndex: _viewModeIndex,
              onTap: (index) => setState(() => _viewModeIndex = index),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_customize_outlined),
                  label: 'Vision Board',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.check_circle_outline),
                  label: 'Habits',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.checklist),
                  label: 'Tasks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.insights),
                  label: 'Insights',
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edit: ${widget.title}'
              : (_viewModeIndex == 0
                  ? widget.title
                  : _viewModeIndex == 1
                      ? 'Habits'
                      : _viewModeIndex == 2
                          ? 'Tasks'
                          : 'Insights'),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: _isEditing ? 'Switch to View Mode' : 'Switch to Edit Mode',
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
            onPressed: _toggleEditMode,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'restore_google_drive') {
                _restoreBackgroundFromGoogleDrive();
              } else if (value == 'backup_google_drive') {
                _backupToGoogleDrive();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'restore_google_drive',
                child: Row(
                  children: [
                    Icon(Icons.cloud_download_outlined),
                    SizedBox(width: 12),
                    Text('Restore from Google Drive'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup_google_drive',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined),
                    SizedBox(width: 12),
                    Text('Backup to Google Drive'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}

