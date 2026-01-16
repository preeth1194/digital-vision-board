import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/grid_template.dart';
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
            title: const Text('Goal Canvas (Canva-style)'),
            subtitle: const Text('Add goal images, crop, resize, reorder layers, track habits'),
            onTap: () => Navigator.of(context).pop(VisionBoardInfo.layoutGoalCanvas),
          ),
          ListTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: const Text('Grid Layout'),
            subtitle: const Text('Structured, scrollable grid tiles'),
            onTap: () => Navigator.of(context).pop(VisionBoardInfo.layoutGrid),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Import from Physical Vision Board'),
            subtitle: const Text('Scan and import your physical vision board'),
            onTap: () => Navigator.of(context).pop('import_physical'),
          ),
        ],
      ),
    ),
  );
}

Future<GridTemplate?> showGridTemplateSelectorSheet(BuildContext context) {
  return showModalBottomSheet<GridTemplate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pick a layout',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose a template first, then fill in the blanks.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: GridTemplates.all.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final template = GridTemplates.all[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pop(template),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: _GridTemplatePreview(template: template),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${template.tiles.length} tiles',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GridTemplatePreview extends StatelessWidget {
  final GridTemplate template;
  const _GridTemplatePreview({required this.template});

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      const Color(0xFFEEF2FF),
      const Color(0xFFE0F2FE),
      const Color(0xFFECFDF5),
      const Color(0xFFFFF7ED),
      const Color(0xFFF3E8FF),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Container(
        color: Colors.black12.withOpacity(0.08),
        padding: const EdgeInsets.all(4),
        child: StaggeredGrid.count(
          crossAxisCount: 4,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (int i = 0; i < template.tiles.length; i++)
              StaggeredGridTile.count(
                crossAxisCellCount: template.tiles[i].crossAxisCount,
                mainAxisCellCount: template.tiles[i].mainAxisCount,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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

