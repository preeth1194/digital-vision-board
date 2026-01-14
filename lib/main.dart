import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/hotspot_model.dart';
import 'models/vision_component.dart';
import 'widgets/habits_list_page.dart';
import 'widgets/global_insights_page.dart';
import 'widgets/habit_tracker_sheet.dart';
import 'widgets/vision_board_builder.dart';

// Conditional import: File is not available on web
import 'dart:io' if (dart.library.html) 'dart:html' as io;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock orientation to portrait only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Board Hotspot Builder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _OrientationLock(
        child: VisionBoardExamplePage(),
      ),
    );
  }
}

class VisionBoardExamplePage extends StatefulWidget {
  const VisionBoardExamplePage({super.key});

  @override
  State<VisionBoardExamplePage> createState() => _VisionBoardExamplePageState();
}

class _OrientationLock extends StatefulWidget {
  final Widget child;
  
  const _OrientationLock({required this.child});

  @override
  State<_OrientationLock> createState() => _OrientationLockState();
}

class _OrientationLockState extends State<_OrientationLock> {
  @override
  void initState() {
    super.initState();
    // Lock to portrait on init
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    // Keep portrait locked
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _VisionBoardExamplePageState extends State<VisionBoardExamplePage> {
  List<VisionComponent> _components = [];
  String? _selectedComponentId;
  List<HotspotModel> _legacyHotspots = [];
  bool _isEditing = true;
  bool _isLoading = true;
  int _viewModeIndex = 0; // 0: Vision Board, 1: Habits, 2: Insights

  static const String _componentsKey = 'vision_board_components';
  static const String _hotspotsKey = 'vision_board_hotspots'; // legacy
  static const String _imagePathKey = 'vision_board_image_path'; // used as background image
  static const String _backgroundColorKey = 'vision_board_background_color';
  SharedPreferences? _prefs;
  
  final ImagePicker _imagePicker = ImagePicker();
  dynamic _selectedImageFile; // File on mobile, null on web
  ImageProvider? _imageProvider;
  Size? _backgroundImageSize;
  Color _backgroundColor = const Color(0xFFF7F7FA);

  @override
  void initState() {
    super.initState();
    print('=== initState called ===');
    print('Platform: ${kIsWeb ? "Web" : "Native"}');
    // Load saved image first, then initialize storage
    _loadSavedImage();
    // Initialize SharedPreferences first, then load
    _initializeStorage();
  }

  /// Load saved image path from storage
  Future<void> _loadSavedImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? imagePath = prefs.getString(_imagePathKey);
      
      if (imagePath != null && imagePath.isNotEmpty && !kIsWeb) {
        try {
          final io.File imageFile = io.File(imagePath);
          if (await imageFile.exists()) {
            setState(() {
              _selectedImageFile = imageFile;
              _imageProvider = FileImage(imageFile);
            });
            print('Loaded saved image: $imagePath');
          }
        } catch (e) {
          print('Error loading file: $e');
        }
      } else {
        // Default: empty canvas with a solid background color
        setState(() {
          _imageProvider = null;
        });
      }

      if (_imageProvider != null) {
        _backgroundImageSize = await _resolveImageSize(_imageProvider!);
        await _maybeMigrateLegacyHotspots();
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Error loading saved image: $e');
      // Fallback: empty canvas
      setState(() {
        _imageProvider = null;
      });
      _backgroundImageSize = null;
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

  /// Save image path to storage
  Future<void> _saveImagePath(String? imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (imagePath != null && imagePath.isNotEmpty) {
        await prefs.setString(_imagePathKey, imagePath);
        print('Saved image path: $imagePath');
      } else {
        await prefs.remove(_imagePathKey);
        print('Removed image path');
      }
    } catch (e) {
      print('Error saving image path: $e');
    }
  }

  /// Pick an image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // On web, use the bytes directly
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _imageProvider = MemoryImage(bytes);
          });
          // For web, we can't save file paths, so we'll save a flag
          await _saveImagePath('web_image_selected');
        } else {
          // On mobile, use File
          try {
            final io.File imageFile = io.File(pickedFile.path);
            setState(() {
              _selectedImageFile = imageFile;
              _imageProvider = FileImage(imageFile);
            });
            // Save the image path
            await _saveImagePath(pickedFile.path);
          } catch (e) {
            print('Error creating File: $e');
          }
        }

        if (_imageProvider != null) {
          _backgroundImageSize = await _resolveImageSize(_imageProvider!);
          await _maybeMigrateLegacyHotspots();
          if (mounted) setState(() {});
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image loaded successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show dialog to choose image source
  Future<void> _showImageSourceDialog() async {
    if (kIsWeb) {
      // Web only supports gallery
      await _pickImage(ImageSource.gallery);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Initialize SharedPreferences and load data
  Future<void> _initializeStorage() async {
    try {
      print('Initializing SharedPreferences...');
      
      // On web, we need to ensure we're using the same storage context
      // Get instance - this may take a moment on web
      _prefs = await SharedPreferences.getInstance();
      print('SharedPreferences instance obtained');
      
      // On web, add a delay and ensure we reload the instance to get fresh data
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 300));
        // Get a fresh instance to ensure we're reading from the actual localStorage
        _prefs = await SharedPreferences.getInstance();
      }
      
      await _loadComponents();
    } catch (e, stackTrace) {
      print('Error initializing storage: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load components (and legacy hotspots) from local storage.
  Future<void> _loadComponents() async {
    try {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
      });
      
      // On web, get a fresh instance to ensure we're reading the latest data
      if (kIsWeb) {
        _prefs = await SharedPreferences.getInstance();
        // Small delay to ensure localStorage is ready
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Use cached instance or get new one
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (_prefs == null) {
        _prefs = prefs;
      }

      final bg = prefs.getInt(_backgroundColorKey);
      if (bg != null) {
        _backgroundColor = Color(bg);
      }

      final String? componentsJson = prefs.getString(_componentsKey);
      if (componentsJson != null && componentsJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(componentsJson) as List<dynamic>;
          final List<VisionComponent> loaded = decoded
              .map((j) => VisionComponent.fromJson(j as Map<String, dynamic>))
              .toList();
          if (mounted) {
            setState(() {
              _components = loaded;
              _legacyHotspots = [];
              _isLoading = false;
            });
          }
        } catch (e, stackTrace) {
          print('✗ Error parsing components JSON: $e');
          print('Stack trace: $stackTrace');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        // Legacy: load hotspots so we can migrate once we know background image size.
        final String? hotspotsJson = prefs.getString(_hotspotsKey);
        if (hotspotsJson != null && hotspotsJson.isNotEmpty) {
          try {
            final List<dynamic> decoded = jsonDecode(hotspotsJson) as List<dynamic>;
            final List<HotspotModel> loadedHotspots = decoded
                .map((json) => HotspotModel.fromJson(json as Map<String, dynamic>))
                .toList();
            if (mounted) {
              setState(() {
                _legacyHotspots = loadedHotspots;
              });
            }
          } catch (e, stackTrace) {
            print('✗ Error parsing legacy hotspots JSON: $e');
            print('Stack trace: $stackTrace');
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

      await _maybeMigrateLegacyHotspots();
    } catch (e, stackTrace) {
      print('✗ Error loading components: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _maybeMigrateLegacyHotspots() async {
    if (_components.isNotEmpty) return;
    if (_legacyHotspots.isEmpty) return;
    if (_backgroundImageSize == null) return;

    final converted = _legacyHotspots
        .map((h) => convertHotspotToComponent(h, _backgroundImageSize!))
        .toList();

    if (!mounted) return;
    setState(() {
      _components = converted;
      _legacyHotspots = [];
    });
    await _saveComponents();
  }

  /// Save components to local storage
  Future<void> _saveComponents() async {
    if (_isLoading) return;
    try {
      // Use cached instance or get new one
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (_prefs == null) {
        _prefs = prefs;
      }

      final List<Map<String, dynamic>> componentsJson =
          _components.map((c) => c.toJson()).toList();
      await prefs.setString(_componentsKey, jsonEncode(componentsJson));
      await prefs.setInt(_backgroundColorKey, _backgroundColor.value);
      
      // On web, add a delay and force a commit
      if (kIsWeb) {
        // Give it time to write to localStorage
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Force reload the instance to ensure it's synced
        _prefs = await SharedPreferences.getInstance();
      }
    } catch (e, stackTrace) {
      print('✗ Error saving components: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _onComponentsChanged(List<VisionComponent> components) {
    setState(() {
      _components = components;
    });
    
    // Automatically save whenever components change (but not while loading)
    if (!_isLoading) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _saveComponents();
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      // Clear selection when switching modes
      _selectedComponentId = null;
      // Reset view mode to Vision Board when switching modes
      if (_isEditing) {
        _viewModeIndex = 0;
      }
    });
  }

  Future<void> _clearComponents() async {
    setState(() {
      _components = [];
      _selectedComponentId = null;
    });
    // Save the cleared state
    await _saveComponents();
  }

  void _deleteSelectedComponent() {
    if (_selectedComponentId == null) return;
    _onComponentsChanged(
      _components.where((c) => c.id != _selectedComponentId).toList(),
    );
    setState(() => _selectedComponentId = null);
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
      builder: (BuildContext sheetContext) {
        return HabitTrackerSheet(
          component: component,
          onComponentUpdated: (updated) {
            final next = _components.map((c) => c.id == updated.id ? updated : c).toList();
            _onComponentsChanged(next);
          },
        );
      },
    );
  }

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}';

  int _nextZ() {
    if (_components.isEmpty) return 0;
    return _components.map((c) => c.zIndex).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _editSelectedTextComponent() async {
    if (_selectedComponentId == null) return;
    final component = _components.firstWhere(
      (c) => c.id == _selectedComponentId,
      orElse: () => throw StateError('Component not found'),
    );
    if (component is! TextComponent) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TextEditorDialog(
        initialText: component.text,
        initialStyle: component.style,
      ),
    );

    if (result == null) return;

    final updated = component.copyWith(
      text: result['text'] as String,
      style: result['style'] as TextStyle,
    );

    final updatedComponents = _components.map((c) => c.id == component.id ? updated : c).toList();
    _onComponentsChanged(updatedComponents);
    setState(() => _selectedComponentId = updated.id);
  }

  Future<void> _addTextComponent() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _TextEditorDialog(
        initialText: '',
        initialStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );

    if (result == null) return;
    final text = result['text'] as String;
    if (text.isEmpty) return;
    
    // Use text content as ID (truncated if long)
    final name = text.length > 20 ? '${text.substring(0, 20)}...' : text;

    final c = TextComponent(
      id: name,
      position: const Offset(120, 120),
      size: const Size(260, 90),
      rotation: 0,
      scale: 1,
      zIndex: _nextZ(),
      text: text,
      style: result['style'] as TextStyle,
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

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (pickedFile == null) return;
      if (!mounted) return;

      // Ask for name
      final String? name = await showDialog<String>(
        context: context,
        builder: (context) => const _AddNameDialog(title: 'Name this Image'),
      );
      
      if (name == null || name.isEmpty) return;

      final c = ImageComponent(
        id: name, // Use user provided name as ID
        position: const Offset(120, 120),
        size: const Size(320, 220),
        rotation: 0,
        scale: 1,
        zIndex: _nextZ(),
        imagePath: pickedFile.path,
      );

      _onComponentsChanged([..._components, c]);
      setState(() => _selectedComponentId = c.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding image: $e')),
      );
    }
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
                const Text(
                  'Background',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Prevent resizing when keyboard opens to stop image from zooming out/shifting
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_isEditing 
            ? 'Edit Vision Board' 
            : _viewModeIndex == 0 ? 'Vision Board' : _viewModeIndex == 1 ? 'Habits' : 'Insights'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
            tooltip: _isEditing ? 'Switch to View Mode' : 'Switch to Edit Mode',
            onPressed: _toggleEditMode,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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

    switch (_viewModeIndex) {
      case 1:
        return HabitsListPage(
          components: _components,
          onComponentsUpdated: _onComponentsChanged,
        );
      case 2:
        return GlobalInsightsPage(components: _components);
      case 0:
      default:
        return VisionBoardBuilder(
          components: _components,
          isEditing: false,
          selectedComponentId: null,
          onSelectedComponentIdChanged: (_) {},
          onComponentsChanged: _onComponentsChanged,
          onOpenComponent: _openHabitTrackerForComponent,
          backgroundColor: _backgroundColor,
          backgroundImage: _imageProvider,
          backgroundImageSize: _backgroundImageSize,
        );
    }
  }

  Future<void> _showLayersDialog() async {
    if (!mounted) return;
    
    // Sort components by zIndex descending (Top to Bottom) for the list
    final sortedComponents = List<VisionComponent>.from(_components)
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));
      
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => _LayersSheet(
        components: sortedComponents,
        selectedId: _selectedComponentId,
        onDelete: (id) {
          final updated = _components.where((c) => c.id != id).toList();
          _onComponentsChanged(updated);
          if (_selectedComponentId == id) {
            setState(() => _selectedComponentId = null);
          }
          Navigator.of(context).pop();
        },
        onReorder: (oldIndex, newIndex) {
          // Work with the actual _components list, but sorted by zIndex
          // The sheet provides indices in the sorted list
          final sorted = List<VisionComponent>.from(_components)
            ..sort((a, b) => b.zIndex.compareTo(a.zIndex));
          
          // Adjust newIndex for removal
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          
          // Reorder the sorted list
          final item = sorted.removeAt(oldIndex);
          sorted.insert(newIndex, item);
          
          // Now assign new z-indexes based on the new order
          // Index 0 (top of list) = highest z-index
          final count = sorted.length;
          final updated = <VisionComponent>[];
          
          for (int i = 0; i < count; i++) {
            // Find the component in _components and update its z-index
            final component = sorted[i];
            final existing = _components.firstWhere((c) => c.id == component.id);
            updated.add(existing.copyWithCommon(zIndex: count - 1 - i));
          }
          
          _onComponentsChanged(updated);
        },
        onSelect: (id) {
           setState(() => _selectedComponentId = id);
           Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget? _buildBottomBar() {
    // Using a safe minimum height wrapper
    return SizedBox(
      height: 80 + MediaQuery.of(context).padding.bottom, // Fixed height wrapper
      child: _isEditing 
        ? BottomAppBar(
            height: 80, // Explicit height
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
                // Edit Selected (only for text components)
                if (_selectedComponentId != null && _components.any((c) => c.id == _selectedComponentId && c is TextComponent))
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
            onTap: (index) {
              setState(() {
                _viewModeIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
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
}

class _TextEditorDialog extends StatefulWidget {
  final String initialText;
  final TextStyle initialStyle;

  const _TextEditorDialog({
    required this.initialText,
    required this.initialStyle,
  });

  @override
  State<_TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<_TextEditorDialog> {
  late final TextEditingController _textController;
  late double _fontSize;
  late Color _textColor;
  late FontWeight _fontWeight;
  late TextAlign _textAlign;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _fontSize = widget.initialStyle.fontSize ?? 28;
    _textColor = widget.initialStyle.color ?? Colors.black;
    _fontWeight = widget.initialStyle.fontWeight ?? FontWeight.w600;
    _textAlign = TextAlign.left; // TextStyle doesn't support textAlign
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    final style = TextStyle(
      fontSize: _fontSize,
      color: _textColor,
      fontWeight: _fontWeight,
    );
    
    Navigator.of(context).pop({
      'text': text,
      'style': style,
      'textAlign': _textAlign, // Pass separately since TextStyle doesn't support it
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Text Editor',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Type something...',
                  border: OutlineInputBorder(),
                ),
                autofocus: widget.initialText.isEmpty,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              // Font Size
              Row(
                children: [
                  const Text('Font Size: '),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 72,
                      divisions: 30,
                      label: _fontSize.round().toString(),
                      onChanged: (value) => setState(() => _fontSize = value),
                    ),
                  ),
                  Text('${_fontSize.round()}'),
                ],
              ),
              const SizedBox(height: 16),
              // Font Weight
              Row(
                children: [
                  const Text('Weight: '),
                  Expanded(
                    child: SegmentedButton<FontWeight>(
                      segments: const [
                        ButtonSegment(value: FontWeight.normal, label: Text('Normal')),
                        ButtonSegment(value: FontWeight.w600, label: Text('Bold')),
                        ButtonSegment(value: FontWeight.w300, label: Text('Light')),
                      ],
                      selected: {_fontWeight},
                      onSelectionChanged: (Set<FontWeight> newSelection) {
                        setState(() => _fontWeight = newSelection.first);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Text Alignment
              Row(
                children: [
                  const Text('Align: '),
                  Expanded(
                    child: SegmentedButton<TextAlign>(
                      segments: const [
                        ButtonSegment(value: TextAlign.left, label: Icon(Icons.format_align_left)),
                        ButtonSegment(value: TextAlign.center, label: Icon(Icons.format_align_center)),
                        ButtonSegment(value: TextAlign.right, label: Icon(Icons.format_align_right)),
                      ],
                      selected: {_textAlign},
                      onSelectionChanged: (Set<TextAlign> newSelection) {
                        setState(() => _textAlign = newSelection.first);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Color Picker
              Wrap(
                spacing: 10,
                children: [
                  const Text('Color: '),
                  ..._colorOptions.map((color) {
                    return InkWell(
                      onTap: () => setState(() => _textColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _textColor == color ? Colors.blue : Colors.grey,
                            width: _textColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              // Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _textController.text.isEmpty ? 'Preview' : _textController.text,
                  style: TextStyle(
                    fontSize: _fontSize,
                    color: _textColor,
                    fontWeight: _fontWeight,
                  ),
                  textAlign: _textAlign,
                ),
              ),
              const SizedBox(height: 20),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<Color> _colorOptions = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.amber,
  ];
}

class _AddNameDialog extends StatefulWidget {
  final String title;
  const _AddNameDialog({required this.title});

  @override
  State<_AddNameDialog> createState() => _AddNameDialogState();
}

class _AddNameDialogState extends State<_AddNameDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Name (ID)',
          hintText: 'e.g. Vacation Photo',
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context).pop(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              Navigator.of(context).pop(_nameController.text.trim());
            }
          },
          child: const Text('Set Name'),
        ),
      ],
    );
  }
}

class _LayersSheet extends StatefulWidget {
  final List<VisionComponent> components;
  final String? selectedId;
  final Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;

  const _LayersSheet({
    required this.components,
    required this.selectedId,
    required this.onReorder,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<_LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<_LayersSheet> {
  late List<VisionComponent> _list;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.components);
  }

  @override
  void didUpdateWidget(covariant _LayersSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.components != oldWidget.components) {
      _list = List.from(widget.components);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Layers (Drag to Reorder)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        Flexible(
          child: ReorderableListView(
            shrinkWrap: true,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = _list.removeAt(oldIndex);
                _list.insert(newIndex, item);
              });
              // Pass the adjusted newIndex to parent
              widget.onReorder(oldIndex, oldIndex < newIndex ? newIndex : newIndex + 1);
            },
            children: [
              for (int i = 0; i < _list.length; i++)
                ListTile(
                  key: ValueKey(_list[i].id),
                  title: Text(_list[i].id),
                  leading: Icon(_getIconForType(_list[i])),
                  selected: _list[i].id == widget.selectedId,
                  onTap: () => widget.onSelect(_list[i].id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => widget.onDelete(_list[i].id),
                        tooltip: 'Delete',
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForType(VisionComponent c) {
    if (c is ImageComponent) return Icons.image;
    if (c is TextComponent) return Icons.text_fields;
    return Icons.layers;
  }
}

