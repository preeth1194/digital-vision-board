import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Conditional import: File is not available on web
import 'dart:io' if (dart.library.html) 'dart:html' as io;

import '../models/hotspot_model.dart';
import '../models/vision_components.dart';
import '../services/boards_storage_service.dart';
import '../screens/global_insights_screen.dart';
import '../screens/habits_list_screen.dart';
import '../widgets/editor/add_name_dialog.dart';
import '../widgets/editor/layers_sheet.dart';
import '../widgets/editor/text_editor_dialog.dart';
import '../widgets/habit_tracker_sheet.dart';
import '../widgets/vision_board_builder.dart';

class VisionBoardEditorScreen extends StatefulWidget {
  final String boardId;
  final String title;
  final bool initialIsEditing;

  const VisionBoardEditorScreen({
    super.key,
    required this.boardId,
    required this.title,
    required this.initialIsEditing,
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
  int _viewModeIndex = 0; // 0: Vision Board, 1: Habits, 2: Insights

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
      final io.File imageFile = io.File(pickedFile.path);
      if (!mounted) return;
      setState(() {
        _selectedImageFile = imageFile;
        _imageProvider = FileImage(imageFile);
      });
      await _saveImagePath(pickedFile.path);
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

    final converted =
        _legacyHotspots.map((h) => convertHotspotToComponent(h, _backgroundImageSize!)).toList();
    if (!mounted) return;
    setState(() {
      _components = converted;
      _legacyHotspots = [];
    });
    await _saveComponents();
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
    );
    if (result == null) return;

    final updated = component.copyWith(text: result.text, style: result.style);
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

    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _pickedImageMaxSide,
      maxHeight: _pickedImageMaxSide,
      imageQuality: _pickedImageQuality,
    );
    if (pickedFile == null || !mounted) return;

    final String? name = await showAddNameDialog(context, title: 'Your Vision/Goal');
    if (name == null || name.isEmpty) return;

    final c = ImageComponent(
      id: name,
      position: const Offset(120, 120),
      size: const Size(320, 220),
      rotation: 0,
      scale: 1,
      zIndex: _nextZ(),
      imagePath: pickedFile.path,
    );
    _onComponentsChanged([..._components, c]);
    setState(() => _selectedComponentId = c.id);
  }

  Future<void> _showBackgroundOptions() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = <Color>[
          const Color(0xFFF7F7FA),
          Colors.white,
          const Color(0xFF111827),
          const Color(0xFF0EA5E9),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
          const Color(0xFFEF4444),
          const Color(0xFF8B5CF6),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Background', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Future.delayed(const Duration(milliseconds: 150));
                    if (!mounted) return;
                    await _showBackgroundImageSourceDialog();
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Upload background image'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: colors.map((c) {
                    return InkWell(
                      onTap: () {
                        setState(() => _backgroundColor = c);
                        _saveComponents();
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() {
                      _imageProvider = null;
                      _selectedImageFile = null;
                      _backgroundImageSize = null;
                    });
                    await _saveImagePath(null);
                    if (mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.hide_image_outlined),
                  label: const Text('Clear background image'),
                ),
              ],
            ),
          ),
        );
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
        final updated = _components.where((c) => c.id != id).toList();
        _onComponentsChanged(updated);
        if (_selectedComponentId == id) setState(() => _selectedComponentId = null);
        Navigator.of(context).pop();
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
      2 => GlobalInsightsScreen(components: _components),
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
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}

