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

  void _showFilterMenu() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Filter by Category',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                    title: Text(category),
                    selected: isSelected,
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() {
                        _selectedCategory = category;
                        _currentIndex = 0;
                      });
                      await _reload();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const AffirmationManagementScreen(),
      ),
    );
    await _reload();
  }

  Future<void> _openManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const AffirmationManagementScreen(),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
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
      ),
      floatingActionButton: _affirmations.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Filter FAB (smaller)
                FloatingActionButton.small(
                  heroTag: 'filter',
                  onPressed: _showFilterMenu,
                  backgroundColor: _selectedCategory != null && _selectedCategory != 'All'
                      ? colorScheme.primaryContainer
                      : null,
                  foregroundColor: _selectedCategory != null && _selectedCategory != 'All'
                      ? colorScheme.onPrimaryContainer
                      : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.filter_list),
                      if (_selectedCategory != null && _selectedCategory != 'All')
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Settings FAB (smaller)
                FloatingActionButton.small(
                  heroTag: 'settings',
                  onPressed: _openSettings,
                  child: const Icon(Icons.settings),
                ),
                const SizedBox(height: 12),
                // Add FAB (main, larger)
                FloatingActionButton(
                  heroTag: 'add',
                  onPressed: _openManagement,
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
