import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/core_value.dart';
import '../../models/grid_template.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

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
            ListTile(
              title: Text('Choose a template', style: AppTypography.heading3(context)),
              subtitle: Text('Create your vision board'),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Create Vision Board'),
                subtitle: const Text('Pick a layout and fill it with your goals'),
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
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pick a layout',
                style: AppTypography.heading3(context),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a template first, then fill in the blanks.',
                style: AppTypography.secondary(context),
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
                          border: Border.all(color: colorScheme.outlineVariant),
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
                                    style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${template.tiles.length} tiles',
                                    style: AppTypography.secondary(context),
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
      );
    },
  );
}

class _GridTemplatePreview extends StatelessWidget {
  final GridTemplate template;
  const _GridTemplatePreview({required this.template});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = <Color>[
      AppColors.pastelIndigo,
      AppColors.pastelBlue,
      AppColors.pastelGreen,
      AppColors.pastelOrange,
      AppColors.pastelPurple,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Container(
        color: colorScheme.outlineVariant.withValues(alpha: 0.08),
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
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('New Vision Board'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLength: 100,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: const InputDecoration(
                hintText: 'Board name',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Text(
              'Core value',
              style: AppTypography.heading3(context),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick one major focus for this board.',
              style: AppTypography.secondary(context),
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
                          child: Icon(cv.icon, size: 16, color: colorScheme.onSurface),
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

