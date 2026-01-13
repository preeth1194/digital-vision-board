import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/hotspot_model.dart';
import 'widgets/vision_board_hotspot_builder.dart';

void main() {
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
      home: const VisionBoardExamplePage(),
    );
  }
}

class VisionBoardExamplePage extends StatefulWidget {
  const VisionBoardExamplePage({super.key});

  @override
  State<VisionBoardExamplePage> createState() => _VisionBoardExamplePageState();
}

class _VisionBoardExamplePageState extends State<VisionBoardExamplePage> {
  List<HotspotModel> _hotspots = [];
  bool _isEditing = true;
  bool _isLoading = true;
  static const String _hotspotsKey = 'vision_board_hotspots';
  SharedPreferences? _prefs;

  // Example: Using a network image
  // Replace with your actual image source (FileImage, AssetImage, NetworkImage, etc.)
  final ImageProvider _imageProvider = const NetworkImage(
    'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800',
  );

  // Alternative examples:
  // final ImageProvider _imageProvider = AssetImage('assets/images/vision_board.jpg');
  // final ImageProvider _imageProvider = FileImage(File('/path/to/image.jpg'));

  @override
  void initState() {
    super.initState();
    print('=== initState called ===');
    print('Platform: ${kIsWeb ? "Web" : "Native"}');
    // Initialize SharedPreferences first, then load
    _initializeStorage();
  }

  /// Initialize SharedPreferences and load data
  Future<void> _initializeStorage() async {
    try {
      print('Initializing SharedPreferences...');
      
      // On web, we need to ensure we're using the same storage context
      // Get instance - this may take a moment on web
      _prefs = await SharedPreferences.getInstance();
      print('SharedPreferences instance obtained');
      
      // Verify it's working by checking if we can read/write
      final String testKey = '$_hotspotsKey._test';
      await _prefs!.setString(testKey, 'test');
      final String? testValue = _prefs!.getString(testKey);
      await _prefs!.remove(testKey);
      
      if (testValue == 'test') {
        print('SharedPreferences is working correctly');
      } else {
        print('WARNING: SharedPreferences test failed!');
      }
      
      // On web, add a delay and ensure we reload the instance to get fresh data
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 300));
        // Get a fresh instance to ensure we're reading from the actual localStorage
        _prefs = await SharedPreferences.getInstance();
        print('Web: Got fresh SharedPreferences instance after delay');
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
      
      // Get all keys for debugging
      final Set<String> allKeys = prefs.getKeys();
      print('All SharedPreferences keys: $allKeys');
      print('Looking for key: $_hotspotsKey');
      
      // Try to get the value
      final String? hotspotsJson = prefs.getString(_hotspotsKey);
      
      print('Loading hotspots from storage...');
      print('Key: $_hotspotsKey');
      print('Raw JSON: $hotspotsJson');
      print('Raw JSON is null: ${hotspotsJson == null}');
      print('Raw JSON isEmpty: ${hotspotsJson?.isEmpty ?? true}');
      if (hotspotsJson != null) {
        print('Raw JSON length: ${hotspotsJson.length}');
        print('Raw JSON preview: ${hotspotsJson.substring(0, hotspotsJson.length > 100 ? 100 : hotspotsJson.length)}...');
      }
      
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
            print('✓ Loaded ${loadedHotspots.length} hotspots from storage');
            for (var hotspot in loadedHotspots) {
              print('  - $hotspot');
            }
          }
        } catch (e, stackTrace) {
          print('✗ Error parsing JSON: $e');
          print('Stack trace: $stackTrace');
          print('JSON was: $hotspotsJson');
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
          print('No saved hotspots found (JSON is null or empty)');
          print('Available keys: $allKeys');
          if (allKeys.isEmpty) {
            print('WARNING: No keys found in SharedPreferences at all!');
          }
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
      
      print('Attempting to save ${_hotspots.length} hotspots...');
      print('Key: $_hotspotsKey');
      print('JSON length: ${jsonString.length}');
      print('JSON preview: ${jsonString.substring(0, jsonString.length > 100 ? 100 : jsonString.length)}...');
      
      // Save using SharedPreferences
      final bool success = await prefs.setString(_hotspotsKey, jsonString);
      
      print('Save operation result: $success');
      
      // On web, add a delay and force a commit
      if (kIsWeb) {
        // Give it time to write to localStorage
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Force reload the instance to ensure it's synced
        _prefs = await SharedPreferences.getInstance();
      }
      
      // Verify the save worked by reading it back (use fresh instance on web)
      final SharedPreferences verifyPrefs = kIsWeb 
          ? await SharedPreferences.getInstance() 
          : prefs;
      final String? verifyJson = verifyPrefs.getString(_hotspotsKey);
      
      print('Verification read - Key: $_hotspotsKey');
      print('Verification read - Value: $verifyJson');
      print('Verification read - Value is null: ${verifyJson == null}');
      print('Verification read - Value length: ${verifyJson?.length ?? 0}');
      
      if (success && verifyJson == jsonString) {
        print('✓ Saved ${_hotspots.length} hotspots to storage (verified)');
        print('Full JSON: $jsonString');
      } else if (success && verifyJson != null && verifyJson.isNotEmpty) {
        print('⚠ Save reported success but verification shows different data');
        print('Expected length: ${jsonString.length}');
        print('Got length: ${verifyJson.length}');
        print('Expected: $jsonString');
        print('Got: $verifyJson');
      } else if (success) {
        print('✗ Save reported success but verification returned null/empty');
        print('This suggests a timing or persistence issue');
      } else {
        print('✗ Save operation failed');
        print('Success: $success, Verify match: ${verifyJson == jsonString}');
        if (verifyJson != null) {
          print('Stored JSON: $verifyJson');
          print('Expected JSON: $jsonString');
        } else {
          print('Verification read returned null!');
        }
      }
    } catch (e, stackTrace) {
      print('✗ Error saving hotspots: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Debug method to check what's in storage
  Future<void> _debugStorage() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_hotspotsKey);
      
      // Get all keys for debugging
      final Set<String> allKeys = prefs.getKeys();
      
      print('=== DEBUG STORAGE ===');
      print('Platform: ${kIsWeb ? "Web" : "Native"}');
      print('Key: $_hotspotsKey');
      print('Stored value: $stored');
      print('Stored value length: ${stored?.length ?? 0}');
      print('Stored value is null: ${stored == null}');
      print('All SharedPreferences keys: $allKeys');
      print('Current hotspots count: ${_hotspots.length}');
      print('Is loading: $_isLoading');
      print('Prefs instance: ${prefs.hashCode}');
      print('===================');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage: ${stored != null ? "Found ${stored.length} chars" : "Empty"} | Keys: ${allKeys.length}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Debug error: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void _onHotspotsChanged(List<HotspotModel> hotspots) {
    print('=== _onHotspotsChanged called ===');
    print('Old count: ${_hotspots.length}');
    print('New count: ${hotspots.length}');
    print('Is loading: $_isLoading');
    
    setState(() {
      _hotspots = hotspots;
    });
    
    print('Hotspots updated: ${hotspots.length} total');
    for (var hotspot in hotspots) {
      print('  - $hotspot');
    }
    
    // Automatically save whenever hotspots change (but not while loading)
    if (!_isLoading) {
      // Use a small delay to ensure state is updated
      Future.delayed(const Duration(milliseconds: 100), () {
        _saveHotspots();
      });
    } else {
      print('Skipping save - still loading');
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _clearHotspots() async {
    setState(() {
      _hotspots = [];
    });
    // Save the cleared state
    await _saveHotspots();
    // Don't call _onHotspotsChanged here as it will trigger another save
    print('Cleared all hotspots');
  }

  void _onHotspotDelete(HotspotModel hotspot) {
    final List<HotspotModel> updatedHotspots = List.from(_hotspots)..remove(hotspot);
    _onHotspotsChanged(updatedHotspots);
  }

  /// Show dialog for creating or editing a hotspot
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

    return showDialog<HotspotModel>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Goal' : 'Add Goal'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Title',
                      hintText: 'Enter your goal',
                      border: OutlineInputBorder(),
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
                    ),
                    keyboardType: TextInputType.url,
                    textCapitalization: TextCapitalization.none,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
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

                  Navigator.of(dialogContext).pop(hotspot);
                }
              },
              child: const Text('Save'),
            ),
          ],
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
      appBar: AppBar(
        title: const Text('Vision Board Hotspot Builder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Debug button (only in debug mode)
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Storage',
            onPressed: _debugStorage,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload from Storage',
            onPressed: _loadHotspots,
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
            tooltip: _isEditing ? 'Switch to View Mode' : 'Switch to Edit Mode',
            onPressed: _toggleEditMode,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear All Hotspots',
            onPressed: _hotspots.isNotEmpty ? _clearHotspots : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: _isEditing ? Colors.orange.shade100 : Colors.green.shade100,
            child: Row(
          children: [
                Icon(
                  _isEditing ? Icons.edit : Icons.visibility,
                  color: _isEditing ? Colors.orange.shade900 : Colors.green.shade900,
                ),
                const SizedBox(width: 8),
                Text(
                  _isEditing
                      ? 'Edit Mode: Tap and drag to draw zones'
                      : 'View Mode: Tap zones to interact',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isEditing ? Colors.orange.shade900 : Colors.green.shade900,
                  ),
                ),
                const Spacer(),
            Text(
                  'Hotspots: ${_hotspots.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),

          // Vision Board Hotspot Builder
          Expanded(
            child: VisionBoardHotspotBuilder(
              imageProvider: _imageProvider,
              hotspots: _hotspots,
              onHotspotsChanged: _onHotspotsChanged,
              onHotspotDelete: _onHotspotDelete,
              onHotspotCreated: _onHotspotCreated,
              onHotspotEdit: _onHotspotEdit,
              isEditing: _isEditing,
            ),
          ),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Mode Instructions:' : 'View Mode Instructions:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isEditing) ...[
                  const Text('• Tap and drag on the image to draw a rectangular zone'),
                  const Text('• Tap a zone to edit its title and link'),
                  const Text('• Long press a zone to delete it'),
                  const Text('• Use pinch to zoom and pan to navigate'),
                  const Text('• Zones are saved with normalized coordinates (0.0-1.0)'),
                  const Text('• Switch to View Mode to interact with zones'),
                ] else ...[
                  const Text('• Tap a zone with a link to open it in your browser'),
                  const Text('• Zones with links show an external link icon'),
                  const Text('• Switch to Edit Mode to add, modify, or delete zones'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
