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

  Future<void> _addTextComponent() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _AddTextDialog(),
    );

    if (result == null || result.isEmpty) return;

    final c = TextComponent(
      id: _newId('text'),
      position: const Offset(120, 120),
      size: const Size(260, 90),
      rotation: 0,
      scale: 1,
      zIndex: _nextZ(),
      text: result,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
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

      final c = ImageComponent(
        id: _newId('image'),
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
          // Image picker button
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Background',
            onPressed: _showImageSourceDialog,
          ),
          // REMOVED: Refresh Icon
          
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
                // Delete Selected
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Selected',
                  color: _selectedComponentId != null ? Colors.red : null,
                  onPressed: _selectedComponentId != null ? _deleteSelectedComponent : null,
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

class _AddTextDialog extends StatefulWidget {
  const _AddTextDialog();

  @override
  State<_AddTextDialog> createState() => _AddTextDialogState();
}

class _AddTextDialogState extends State<_AddTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Text'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Type something...',
        ),
        autofocus: true,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
