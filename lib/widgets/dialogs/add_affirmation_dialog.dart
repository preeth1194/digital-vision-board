import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/affirmation.dart';
import '../../services/affirmation_service.dart';

/// Dialog for adding or editing an affirmation
Future<Affirmation?> showAddAffirmationDialog(
  BuildContext context, {
  Affirmation? initialAffirmation,
  List<String>? availableCategories,
}) async {
  return showDialog<Affirmation?>(
    context: context,
    builder: (ctx) => _AddAffirmationDialog(
      initialAffirmation: initialAffirmation,
      availableCategories: availableCategories,
    ),
  );
}

class _AddAffirmationDialog extends StatefulWidget {
  final Affirmation? initialAffirmation;
  final List<String>? availableCategories;

  const _AddAffirmationDialog({
    this.initialAffirmation,
    this.availableCategories,
  });

  @override
  State<_AddAffirmationDialog> createState() => _AddAffirmationDialogState();
}

class _AddAffirmationDialogState extends State<_AddAffirmationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  String? _selectedCategory;
  bool _isPinned = false;
  List<String> _categories = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialAffirmation != null) {
      _textController.text = widget.initialAffirmation!.text;
      _selectedCategory = widget.initialAffirmation!.category;
      _isPinned = widget.initialAffirmation!.isPinned;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> categories;
      if (widget.availableCategories != null) {
        categories = widget.availableCategories!;
      } else {
        categories = await AffirmationService.getCategoriesFromBoards(prefs: prefs);
      }
      // Add "General" as default option
      if (!categories.contains('General')) {
        categories.insert(0, 'General');
      }
      if (_selectedCategory != null && !categories.contains(_selectedCategory)) {
        categories.add(_selectedCategory!);
      }
      if (mounted) {
        setState(() {
          _categories = categories;
          _loadingCategories = false;
          if (_selectedCategory == null && categories.isNotEmpty) {
            _selectedCategory = 'General';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categories = ['General'];
          _loadingCategories = false;
          _selectedCategory = 'General';
        });
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final affirmation = Affirmation(
      id: widget.initialAffirmation?.id ?? '',
      category: _selectedCategory == 'General' ? null : _selectedCategory,
      text: text,
      isPinned: _isPinned,
      isCustom: true,
    );

    Navigator.of(context).pop(affirmation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.initialAffirmation != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Affirmation' : 'Add Affirmation'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _textController,
                maxLength: 500,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: const InputDecoration(
                  labelText: 'Affirmation text',
                  hintText: 'Enter your affirmation...',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                maxLines: 4,
                minLines: 2,
                autofocus: !isEditing,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an affirmation';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_loadingCategories)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Pin this affirmation'),
                subtitle: const Text('Pinned affirmations show the same text on both sides when flipped'),
                value: _isPinned,
                onChanged: (value) {
                  setState(() => _isPinned = value ?? false);
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
