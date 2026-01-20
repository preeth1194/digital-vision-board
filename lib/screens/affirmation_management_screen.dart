import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/affirmation.dart';
import '../services/affirmation_service.dart';
import '../widgets/dialogs/add_affirmation_dialog.dart';

class AffirmationManagementScreen extends StatefulWidget {
  const AffirmationManagementScreen({super.key});

  @override
  State<AffirmationManagementScreen> createState() => _AffirmationManagementScreenState();
}

class _AffirmationManagementScreenState extends State<AffirmationManagementScreen> {
  List<Affirmation> _affirmations = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    await _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs ??= prefs;
      
      final categories = await AffirmationService.getCategoriesFromBoards(prefs: prefs);
      categories.insert(0, 'General');
      categories.insert(0, 'All');
      
      final allAffirmations = await AffirmationService.getAllAffirmations(prefs: prefs);
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _affirmations = allAffirmations;
          _loading = false;
          if (_selectedCategory == null) {
            _selectedCategory = 'All';
          }
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

  List<Affirmation> get _filteredAffirmations {
    if (_selectedCategory == null || _selectedCategory == 'All') {
      return _affirmations;
    }
    if (_selectedCategory == 'General') {
      return _affirmations.where((a) => a.category == null).toList();
    }
    return _affirmations.where((a) => a.category == _selectedCategory).toList();
  }

  Future<void> _addAffirmation() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final categories = await AffirmationService.getCategoriesFromBoards(prefs: prefs);
    categories.insert(0, 'General');
    
    final affirmation = await showAddAffirmationDialog(
      context,
      availableCategories: categories,
    );
    
    if (affirmation == null) return;
    
    try {
      await AffirmationService.addAffirmation(affirmation, prefs: prefs);
      if (mounted) {
        await _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Affirmation added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add affirmation: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _editAffirmation(Affirmation affirmation) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final categories = await AffirmationService.getCategoriesFromBoards(prefs: prefs);
    categories.insert(0, 'General');
    
    final updated = await showAddAffirmationDialog(
      context,
      initialAffirmation: affirmation,
      availableCategories: categories,
    );
    
    if (updated == null) return;
    
    try {
      await AffirmationService.updateAffirmation(updated, prefs: prefs);
      if (mounted) {
        await _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Affirmation updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update affirmation: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteAffirmation(Affirmation affirmation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Affirmation'),
        content: const Text('Are you sure you want to delete this affirmation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await AffirmationService.deleteAffirmation(affirmation.id, prefs: prefs);
      if (mounted) {
        await _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Affirmation deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete affirmation: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _togglePin(Affirmation affirmation) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await AffirmationService.pinAffirmation(
        affirmation.id,
        !affirmation.isPinned,
        prefs: prefs,
      );
      if (mounted) {
        await _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update pin status: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _filteredAffirmations;
    final pinned = filtered.where((a) => a.isPinned).toList();
    final unpinned = filtered.where((a) => !a.isPinned).toList();
    final sorted = [...pinned, ...unpinned];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Affirmations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_categories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                onSelected: (selected) {
                                  setState(() => _selectedCategory = cat);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: sorted.isEmpty
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
                              Text(
                                'Tap the + button to add your first affirmation',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final affirmation = sorted[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  affirmation.text,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: affirmation.category != null
                                    ? Text(affirmation.category!)
                                    : const Text('General'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        affirmation.isPinned
                                            ? Icons.push_pin
                                            : Icons.push_pin_outlined,
                                      ),
                                      color: affirmation.isPinned
                                          ? colorScheme.primary
                                          : null,
                                      tooltip: affirmation.isPinned
                                          ? 'Unpin'
                                          : 'Pin',
                                      onPressed: () => _togglePin(affirmation),
                                    ),
                                    PopupMenuButton(
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete),
                                              SizedBox(width: 8),
                                              Text('Delete'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editAffirmation(affirmation);
                                        } else if (value == 'delete') {
                                          _deleteAffirmation(affirmation);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAffirmation,
        child: const Icon(Icons.add),
      ),
    );
  }
}
