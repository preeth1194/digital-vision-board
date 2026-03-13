import 'package:flutter/material.dart';

import '../../models/action_step_template.dart';
import '../../models/habit_action_step.dart';

class GenericPresetEditorScreen extends StatefulWidget {
  final ActionStepTemplate template;

  const GenericPresetEditorScreen({super.key, required this.template});

  @override
  State<GenericPresetEditorScreen> createState() =>
      _GenericPresetEditorScreenState();
}

class _GenericPresetEditorScreenState extends State<GenericPresetEditorScreen> {
  late final TextEditingController _nameController;
  late List<HabitActionStep> _steps;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.name);
    _steps = widget.template.steps
        .map(
          (step) => step.copyWith(
            id: step.id,
            title: step.title,
            iconCodePoint: step.iconCodePoint,
            order: step.order,
            stepLabel: step.stepLabel,
            productType: step.productType,
            productName: step.productName,
            notes: step.notes,
            plannerDay: step.plannerDay,
            plannerWeek: step.plannerWeek,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _steps = [
        ..._steps,
        HabitActionStep(
          id: '${widget.template.id}-custom-${DateTime.now().microsecondsSinceEpoch}',
          title: '',
          iconCodePoint: Icons.check_circle_outline.codePoint,
          order: _steps.length,
        ),
      ];
    });
  }

  void _removeStep(int index) {
    setState(() {
      final next = List<HabitActionStep>.from(_steps)..removeAt(index);
      _steps = [
        for (int i = 0; i < next.length; i++) next[i].copyWith(order: i),
      ];
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final cleaned = <HabitActionStep>[];
    for (int i = 0; i < _steps.length; i++) {
      final title = _steps[i].title.trim();
      if (title.isEmpty) continue;
      cleaned.add(
        _steps[i].copyWith(
          title: title,
          order: i,
          stepLabel: '${i + 1}',
          productName: _steps[i].productName ?? title,
        ),
      );
    }
    if (name.isEmpty || cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preset name and at least one step are required.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      ActionStepTemplate(
        id: widget.template.id,
        name: name,
        category: widget.template.category,
        schemaVersion: widget.template.schemaVersion,
        templateVersion: widget.template.templateVersion,
        setKey: widget.template.setKey,
        isOfficial: widget.template.isOfficial,
        status: widget.template.status,
        createdByUserId: widget.template.createdByUserId,
        steps: cleaned,
        metadata: widget.template.metadata,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Preset'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Preset name'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Steps', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _steps.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(width: 28, child: Text('${i + 1}')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: _steps[i].title,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Step title',
                        ),
                        onChanged: (value) {
                          _steps[i] = _steps[i].copyWith(title: value);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove step',
                      onPressed: () => _removeStep(i),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
