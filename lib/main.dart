import 'dart:convert';
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
  static const String _hotspotsKey = 'vision_board_hotspots';

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
    _loadHotspots();
  }

  /// Load hotspots from local storage
  Future<void> _loadHotspots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? hotspotsJson = prefs.getString(_hotspotsKey);
      
      if (hotspotsJson != null && hotspotsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(hotspotsJson) as List<dynamic>;
        final List<HotspotModel> loadedHotspots = decoded
            .map((json) => HotspotModel.fromJson(json as Map<String, dynamic>))
            .toList();
        
        if (mounted) {
          setState(() {
            _hotspots = loadedHotspots;
          });
          print('Loaded ${loadedHotspots.length} hotspots from storage');
        }
      }
    } catch (e) {
      print('Error loading hotspots: $e');
    }
  }

  /// Save hotspots to local storage
  Future<void> _saveHotspots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> hotspotsJson = 
          _hotspots.map((hotspot) => hotspot.toJson()).toList();
      final String jsonString = jsonEncode(hotspotsJson);
      await prefs.setString(_hotspotsKey, jsonString);
      print('Saved ${_hotspots.length} hotspots to storage');
    } catch (e) {
      print('Error saving hotspots: $e');
    }
  }

  void _onHotspotsChanged(List<HotspotModel> hotspots) {
    setState(() {
      _hotspots = hotspots;
    });
    print('Hotspots updated: ${hotspots.length} total');
    for (var hotspot in hotspots) {
      print('  - $hotspot');
    }
    // Automatically save whenever hotspots change
    _saveHotspots();
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
    _onHotspotsChanged(_hotspots);
  }

  void _onHotspotDelete(HotspotModel hotspot) {
    setState(() {
      _hotspots.remove(hotspot);
    });
    _onHotspotsChanged(_hotspots);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision Board Hotspot Builder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
