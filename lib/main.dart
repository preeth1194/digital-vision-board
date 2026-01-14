import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/hotspot_model.dart';
import 'widgets/vision_board_hotspot_builder.dart';
import 'widgets/habits_list_page.dart';
import 'widgets/global_insights_page.dart';

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
  List<HotspotModel> _hotspots = [];
  Set<HotspotModel> _selectedHotspots = {};
  bool _isEditing = true;
  bool _isLoading = true;
  bool _showLabels = true;
  int _viewModeIndex = 0; // 0: Vision Board, 1: Habits, 2: Insights

  static const String _hotspotsKey = 'vision_board_hotspots';
  static const String _imagePathKey = 'vision_board_image_path';
  SharedPreferences? _prefs;
  
  final ImagePicker _imagePicker = ImagePicker();
  dynamic _selectedImageFile; // File on mobile, null on web
  ImageProvider? _imageProvider;

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
        // Use default network image if no saved image
        setState(() {
          _imageProvider = const NetworkImage(
            'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800',
          );
        });
      }
    } catch (e) {
      print('Error loading saved image: $e');
      // Fallback to default image
      setState(() {
        _imageProvider = const NetworkImage(
          'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800',
        );
      });
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
      
      await _loadHotspots();
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

  /// Load hotspots from local storage
  Future<void> _loadHotspots() async {
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
      
      // Try to get the value
      final String? hotspotsJson = prefs.getString(_hotspotsKey);
      
      if (hotspotsJson != null && hotspotsJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(hotspotsJson) as List<dynamic>;
          final List<HotspotModel> loadedHotspots = decoded
              .map((json) => HotspotModel.fromJson(json as Map<String, dynamic>))
              .toList();
          
          if (mounted) {
            setState(() {
              _hotspots = loadedHotspots;
              _isLoading = false;
            });
          }
        } catch (e, stackTrace) {
          print('✗ Error parsing JSON: $e');
          print('Stack trace: $stackTrace');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('✗ Error loading hotspots: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Save hotspots to local storage
  Future<void> _saveHotspots() async {
    // Don't save while loading to prevent overwriting with empty list
    if (_isLoading) {
      print('Skipping save - still loading...');
      return;
    }
    
    try {
      // Use cached instance or get new one
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (_prefs == null) {
        _prefs = prefs;
      }
      
      final List<Map<String, dynamic>> hotspotsJson = 
          _hotspots.map((hotspot) => hotspot.toJson()).toList();
      final String jsonString = jsonEncode(hotspotsJson);
      
      // Save using SharedPreferences
      await prefs.setString(_hotspotsKey, jsonString);
      
      // On web, add a delay and force a commit
      if (kIsWeb) {
        // Give it time to write to localStorage
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Force reload the instance to ensure it's synced
        _prefs = await SharedPreferences.getInstance();
      }
    } catch (e, stackTrace) {
      print('✗ Error saving hotspots: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _onHotspotsChanged(List<HotspotModel> hotspots) {
    setState(() {
      _hotspots = hotspots;
    });
    
    // Automatically save whenever hotspots change (but not while loading)
    if (!_isLoading) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _saveHotspots();
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      // Clear selection when switching modes
      _selectedHotspots.clear();
      // Reset view mode to Vision Board when switching modes
      if (_isEditing) {
        _viewModeIndex = 0;
      }
    });
  }

  Future<void> _clearHotspots() async {
    setState(() {
      _hotspots = [];
      _selectedHotspots.clear();
    });
    // Save the cleared state
    await _saveHotspots();
  }

  void _onHotspotDelete(HotspotModel hotspot) {
    final List<HotspotModel> updatedHotspots = List.from(_hotspots)..remove(hotspot);
    _onHotspotsChanged(updatedHotspots);
    setState(() {
      _selectedHotspots.remove(hotspot);
    });
  }

  void _deleteSelectedHotspots() {
    if (_selectedHotspots.isEmpty) return;

    final List<HotspotModel> updatedHotspots = List.from(_hotspots)
      ..removeWhere((h) => _selectedHotspots.contains(h));
    
    _onHotspotsChanged(updatedHotspots);
    setState(() {
      _selectedHotspots.clear();
    });
  }

  void _onHotspotSelectionToggled(HotspotModel hotspot) {
    setState(() {
      // Check if we can find this hotspot in the selection using coordinate matching
      // (in case object references changed)
      final existing = _selectedHotspots.lookup(hotspot);
      if (existing != null) {
        _selectedHotspots.remove(existing);
      } else {
        // Also try manual iteration if lookup fails
        bool found = false;
        for (final s in _selectedHotspots) {
          if ((s.x - hotspot.x).abs() < 0.0001 &&
              (s.y - hotspot.y).abs() < 0.0001 &&
              (s.width - hotspot.width).abs() < 0.0001 &&
              (s.height - hotspot.height).abs() < 0.0001) {
            _selectedHotspots.remove(s);
            found = true;
            break;
          }
        }
        if (!found) {
          _selectedHotspots.add(hotspot);
        }
      }
    });
  }

  /// Show overlay for creating or editing a hotspot
  Future<HotspotModel?> _showHotspotDialog({
    HotspotModel? existingHotspot,
    double? x,
    double? y,
    double? width,
    double? height,
  }) async {
    final bool isEditing = existingHotspot != null;
    
    final TextEditingController titleController = TextEditingController(
      text: existingHotspot?.id ?? '',
    );
    final TextEditingController linkController = TextEditingController(
      text: existingHotspot?.link ?? '',
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    // Using showModalBottomSheet for overlay style as requested
    return showModalBottomSheet<HotspotModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEditing ? 'Edit Goal' : 'Add Goal',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Goal Title',
                        hintText: 'Enter your goal',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Goal title is required';
                        }
                        return null;
                      },
                      autofocus: !isEditing,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: linkController,
                      decoration: const InputDecoration(
                        labelText: 'Link URL (Optional)',
                        hintText: 'https://example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                      textCapitalization: TextCapitalization.none,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final String title = titleController.text.trim();
                          final String? link = linkController.text.trim().isEmpty
                              ? null
                              : linkController.text.trim();

                          HotspotModel hotspot;
                          if (isEditing && existingHotspot != null) {
                            // Update existing hotspot
                            hotspot = existingHotspot.copyWith(
                              id: title,
                              link: link,
                            );
                          } else {
                            // Create new hotspot
                            hotspot = HotspotModel(
                              x: x!,
                              y: y!,
                              width: width!,
                              height: height!,
                              id: title,
                              link: link,
                            );
                          }

                          Navigator.of(sheetContext).pop(hotspot);
                        }
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  /// Handle hotspot creation after drawing
  Future<HotspotModel?> _onHotspotCreated(
    double x,
    double y,
    double width,
    double height,
  ) async {
    return _showHotspotDialog(
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  /// Handle hotspot edit when tapped in edit mode
  Future<HotspotModel?> _onHotspotEdit(HotspotModel hotspot) async {
    return _showHotspotDialog(existingHotspot: hotspot);
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
            tooltip: 'Upload Image',
            onPressed: _showImageSourceDialog,
          ),
          // REMOVED: Refresh Icon
          
          IconButton(
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
            tooltip: _isEditing ? 'Switch to View Mode' : 'Switch to Edit Mode',
            onPressed: _toggleEditMode,
          ),
          
          // Tag Visibility Icon - Available in BOTH modes if viewing the board
          if (_isEditing || (_viewModeIndex == 0 && !_isEditing))
            IconButton(
              icon: Icon(_showLabels ? Icons.label : Icons.label_off),
              tooltip: 'Toggle Labels',
              onPressed: () {
                setState(() {
                  _showLabels = !_showLabels;
                });
              },
            ),
          
          // REMOVED: Clear All Hotspots (Delete All) Button
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isEditing) {
      // Edit Mode - Always Vision Board
      return _imageProvider != null
          ? VisionBoardHotspotBuilder(
              imageProvider: _imageProvider!,
              hotspots: _hotspots,
              onHotspotsChanged: _onHotspotsChanged,
              onHotspotDelete: _onHotspotDelete,
              onHotspotCreated: _onHotspotCreated,
              onHotspotEdit: _onHotspotEdit,
              isEditing: true,
              selectedHotspots: _selectedHotspots,
              onHotspotSelected: _onHotspotSelectionToggled,
              showLabels: _showLabels,
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      // View Mode - Based on _viewModeIndex
      switch (_viewModeIndex) {
        case 1:
          return HabitsListPage(
            hotspots: _hotspots,
            onHotspotsUpdated: _onHotspotsChanged,
          );
        case 2:
          // Global Insights Page (IMPLEMENTED)
          return GlobalInsightsPage(hotspots: _hotspots);
        case 0:
        default:
          return _imageProvider != null
              ? VisionBoardHotspotBuilder(
                  imageProvider: _imageProvider!,
                  hotspots: _hotspots,
                  onHotspotsChanged: _onHotspotsChanged,
                  onHotspotDelete: _onHotspotDelete,
                  onHotspotCreated: _onHotspotCreated,
                  onHotspotEdit: _onHotspotEdit,
                  isEditing: false,
                  selectedHotspots: const {},
                  onHotspotSelected: null,
                  showLabels: _showLabels,
                )
              : const Center(child: CircularProgressIndicator());
      }
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
                // Delete Selected
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Selected',
                  color: _selectedHotspots.isNotEmpty ? Colors.red : null,
                  onPressed: _selectedHotspots.isNotEmpty ? _deleteSelectedHotspots : null,
                ),
                // Toggle Labels (Also in AppBar, but kept here for convenience if needed, though redundant if in AppBar)
                IconButton(
                  icon: Icon(_showLabels ? Icons.label : Icons.label_off),
                  tooltip: 'Toggle Labels',
                  onPressed: () {
                    setState(() {
                      _showLabels = !_showLabels;
                    });
                  },
                ),
                // Edit Properties (Only if 1 is selected)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Properties',
                  onPressed: _selectedHotspots.length == 1
                      ? () async {
                          final hotspot = _selectedHotspots.first;
                          final HotspotModel? updated = await _onHotspotEdit(hotspot);
                          if (updated != null && mounted) {
                            // Update the hotspot in the list
                            final index = _hotspots.indexOf(hotspot);
                            if (index != -1) {
                              final updatedHotspots = List<HotspotModel>.from(_hotspots);
                              updatedHotspots[index] = updated;
                              _onHotspotsChanged(updatedHotspots);
                              
                              // Update selection
                              setState(() {
                                _selectedHotspots.remove(hotspot);
                                _selectedHotspots.add(updated);
                              });
                            }
                          }
                        }
                      : null,
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
