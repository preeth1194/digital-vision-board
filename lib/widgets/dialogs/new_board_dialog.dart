import 'package:flutter/material.dart';

import '../../models/vision_board_info.dart';

class NewBoardConfig {
  final String title;
  final int iconCodePoint;
  final int tileColorValue;

  const NewBoardConfig({
    required this.title,
    required this.iconCodePoint,
    required this.tileColorValue,
  });
}

Future<NewBoardConfig?> showNewBoardDialog(BuildContext context) {
  return showDialog<NewBoardConfig>(
    context: context,
    builder: (context) => const _NewBoardDialog(),
  );
}

Future<String?> showTemplatePickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          const ListTile(
            title: Text('Choose a template', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('Freeform Canvas'),
            subtitle: const Text('Drag, resize, and place items freely'),
            onTap: () => Navigator.of(context).pop(VisionBoardInfo.layoutFreeform),
          ),
          ListTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: const Text('Grid Layout'),
            subtitle: const Text('Structured, scrollable grid tiles'),
            onTap: () => Navigator.of(context).pop(VisionBoardInfo.layoutGrid),
          ),
        ],
      ),
    ),
  );
}

class _NewBoardDialog extends StatefulWidget {
  const _NewBoardDialog();

  @override
  State<_NewBoardDialog> createState() => _NewBoardDialogState();
}

class _NewBoardDialogState extends State<_NewBoardDialog> {
  late final TextEditingController _controller;
  late int _selectedIconCodePoint;
  late int _selectedTileColorValue;

  static const List<Color> _colorOptions = [
    Color(0xFFEEF2FF),
    Color(0xFFE0F2FE),
    Color(0xFFECFDF5),
    Color(0xFFFFF7ED),
    Color(0xFFFFEBEE),
    Color(0xFFF3E8FF),
    Color(0xFFFFF1F2),
    Color(0xFFF1F5F9),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _selectedIconCodePoint = Icons.dashboard_outlined.codePoint;
    _selectedTileColorValue = const Color(0xFFEEF2FF).value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      NewBoardConfig(
        title: text,
        iconCodePoint: _selectedIconCodePoint,
        tileColorValue: _selectedTileColorValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Vision Board'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Board name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            const Text('Choose icon', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kBoardIconOptions.map((icon) {
                final selected = _selectedIconCodePoint == icon.codePoint;
                return InkWell(
                  onTap: () => setState(() => _selectedIconCodePoint = icon.codePoint),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black12,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Icon(icon),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Tile color', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorOptions.map((c) {
                final selected = _selectedTileColorValue == c.value;
                return InkWell(
                  onTap: () => setState(() => _selectedTileColorValue = c.value),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black12,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

