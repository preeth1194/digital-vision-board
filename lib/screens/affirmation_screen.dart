import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/affirmation.dart';
import '../services/affirmation_service.dart';
import '../widgets/affirmation_card.dart';
import 'affirmation_management_screen.dart';

class AffirmationScreen extends StatefulWidget {
  final SharedPreferences? prefs;

  const AffirmationScreen({super.key, this.prefs});

  @override
  State<AffirmationScreen> createState() => _AffirmationScreenState();
}

class _AffirmationScreenState extends State<AffirmationScreen> {
  List<Affirmation> _affirmations = [];
  List<String> _categories = [];
  String? _selectedCategory;
  int _currentIndex = 0;
  bool _loading = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = widget.prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await _reload();
    _loadRotationState();
  }

  void _loadRotationState() {
    final prefs = _prefs ?? widget.prefs;
    if (prefs == null) return;
    final categoryKey = _selectedCategory ?? 'all';
    final key = 'dv_affirmation_rotation_$categoryKey';
    final savedIndex = prefs.getInt(key) ?? 0;
    if (savedIndex >= 0 && savedIndex < _affirmations.length) {
      setState(() => _currentIndex = savedIndex);
    }
  }

  void _saveRotationState() {
    final prefs = _prefs ?? widget.prefs;
    if (prefs == null) return;
    final categoryKey = _selectedCategory ?? 'all';
    final key = 'dv_affirmation_rotation_$categoryKey';
    prefs.setInt(key, _currentIndex);
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs ??= prefs;
      
      final categories = await AffirmationService.getCategoriesFromBoards(prefs: prefs);
      categories.insert(0, 'General');
      categories.insert(0, 'All');
      
      List<Affirmation> affirmations;
      if (_selectedCategory == null || _selectedCategory == 'All') {
        affirmations = await AffirmationService.getAllAffirmations(prefs: prefs);
      } else if (_selectedCategory == 'General') {
        affirmations = await AffirmationService.getAffirmationsByCategory(
          category: null,
          prefs: prefs,
        );
      } else {
        affirmations = await AffirmationService.getAffirmationsByCategory(
          category: _selectedCategory,
          prefs: prefs,
        );
      }
      
      // Sort: pinned first, then by creation date
      affirmations.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _affirmations = affirmations;
          _loading = false;
          if (_selectedCategory == null) {
            _selectedCategory = 'All';
          }
          // Ensure current index is valid
          if (_currentIndex >= _affirmations.length) {
            _currentIndex = 0;
          }
          _saveRotationState();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load affirmations: ${e.toString()}')),
        );
      }
    }
  }

  void _onFlip() {
    if (_affirmations.isEmpty) return;
    
    final current = _affirmations[_currentIndex];
    
    // If pinned, don't rotate - both sides show same
    if (current.isPinned) {
      return;
    }
    
    // Rotate to next affirmation
    setState(() {
      _currentIndex = (_currentIndex + 1) % _affirmations.length;
      _saveRotationState();
    });
  }

  Affirmation? get _currentAffirmation {
    if (_affirmations.isEmpty) return null;
    return _affirmations[_currentIndex];
  }

  Affirmation? get _nextAffirmation {
    if (_affirmations.isEmpty) return null;
    final current = _affirmations[_currentIndex];
    
    // If pinned, show same on both sides
    if (current.isPinned) {
      return current;
    }
    
    // Otherwise show next affirmation
    final nextIndex = (_currentIndex + 1) % _affirmations.length;
    return _affirmations[nextIndex];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Affirmations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Manage affirmations',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const AffirmationManagementScreen(),
                ),
              );
              await _reload();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_categories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final cat in _categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(cat),
                                selected: _selectedCategory == cat,
                                onSelected: (selected) async {
                                  setState(() {
                                    _selectedCategory = cat;
                                    _currentIndex = 0;
                                  });
                                  await _reload();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: _affirmations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome_outlined,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No affirmations yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Add your first affirmation to get started. Affirmations are organized by categories from your vision boards.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => const AffirmationManagementScreen(),
                                    ),
                                  );
                                  await _reload();
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Affirmation'),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: AffirmationCard(
                              frontAffirmation: _currentAffirmation,
                              backAffirmation: _nextAffirmation,
                              onFlip: _onFlip,
                              showPinIndicator: true,
                            ),
                          ),
                        ),
                ),
                if (_affirmations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${_currentIndex + 1} of ${_affirmations.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
      floatingActionButton: _affirmations.isNotEmpty
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const AffirmationManagementScreen(),
                  ),
                );
                await _reload();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
