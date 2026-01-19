import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/core_value.dart';
import '../../models/grid_template.dart';

class NewBoardConfig {
  final String title;
  final String coreValueId;

  const NewBoardConfig({
    required this.title,
    required this.coreValueId,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              title: Text('Choose a template', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Two quick ways to start'),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Browse templates'),
                subtitle: const Text('Pick a pre-filled board'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop('browse_templates'),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Create Dream Board (Wizard)'),
                subtitle: const Text('Step-by-step: goals, categories, habits/tasks, then grid'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop('create_wizard'),
              ),
            ),
          ],
        ),
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
  String _selectedCoreValueId = CoreValues.growthMindset;

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

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(
      NewBoardConfig(
        title: text,
        coreValueId: _selectedCoreValueId,
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
            const Text(
              'Core value',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pick one major focus for this board.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCoreValueId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: [
                for (final cv in CoreValues.all)
                  DropdownMenuItem<String>(
                    value: cv.id,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: cv.tileColor,
                          child: Icon(cv.icon, size: 16, color: Colors.black87),
                        ),
                        const SizedBox(width: 10),
                        Text(cv.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedCoreValueId = v);
              },
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

