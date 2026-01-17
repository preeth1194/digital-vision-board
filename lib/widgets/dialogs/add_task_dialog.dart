import 'package:flutter/material.dart';

import '../../models/cbt_enhancements.dart';

final class TaskCreateResult {
  final String title;
  final CbtEnhancements? cbtEnhancements;
  const TaskCreateResult({required this.title, required this.cbtEnhancements});
}

Future<TaskCreateResult?> showAddTaskDialog(
  BuildContext context, {
  String dialogTitle = 'Add task',
  String primaryActionText = 'Add',
}) {
  return showDialog<TaskCreateResult?>(
    context: context,
    builder: (ctx) => _TaskDialog(
      dialogTitle: dialogTitle,
      primaryActionText: primaryActionText,
      initialTitle: '',
      initialCbt: null,
    ),
  );
}

Future<TaskCreateResult?> showEditTaskDialog(
  BuildContext context, {
  String dialogTitle = 'Edit task',
  String primaryActionText = 'Save',
  required String initialTitle,
  required CbtEnhancements? initialCbt,
}) {
  return showDialog<TaskCreateResult?>(
    context: context,
    builder: (ctx) => _TaskDialog(
      dialogTitle: dialogTitle,
      primaryActionText: primaryActionText,
      initialTitle: initialTitle,
      initialCbt: initialCbt,
    ),
  );
}

class _TaskDialog extends StatefulWidget {
  final String dialogTitle;
  final String primaryActionText;
  final String initialTitle;
  final CbtEnhancements? initialCbt;

  const _TaskDialog({
    required this.dialogTitle,
    required this.primaryActionText,
    required this.initialTitle,
    required this.initialCbt,
  });

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _title;
  late final TextEditingController _micro;
  late final TextEditingController _obstacle;
  late final TextEditingController _ifThen;
  late final TextEditingController _reward;

  late bool _addCbt;
  late double _confidence;

  @override
  void initState() {
    super.initState();
    final cbt = widget.initialCbt;
    _title = TextEditingController(text: widget.initialTitle);
    _micro = TextEditingController(text: cbt?.microVersion ?? '');
    _obstacle = TextEditingController(text: cbt?.predictedObstacle ?? '');
    _ifThen = TextEditingController(text: cbt?.ifThenPlan ?? '');
    _reward = TextEditingController(text: cbt?.reward ?? '');
    _confidence = (cbt?.confidenceScore ?? 8).clamp(0, 10).toDouble();
    _addCbt = cbt != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _micro.dispose();
    _obstacle.dispose();
    _ifThen.dispose();
    _reward.dispose();
    super.dispose();
  }

  static bool _hasCbt(CbtEnhancements cbt) {
    return (cbt.microVersion ?? '').trim().isNotEmpty ||
        (cbt.predictedObstacle ?? '').trim().isNotEmpty ||
        (cbt.ifThenPlan ?? '').trim().isNotEmpty ||
        (cbt.reward ?? '').trim().isNotEmpty;
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(null);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    final cbt = CbtEnhancements(
      microVersion: _micro.text.trim().isEmpty ? null : _micro.text.trim(),
      predictedObstacle: _obstacle.text.trim().isEmpty ? null : _obstacle.text.trim(),
      ifThenPlan: _ifThen.text.trim().isEmpty ? null : _ifThen.text.trim(),
      confidenceScore: _confidence.round(),
      reward: _reward.text.trim().isEmpty ? null : _reward.text.trim(),
    );
    final CbtEnhancements? cbtOut = (_addCbt && _hasCbt(cbt)) ? cbt : null;

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(TaskCreateResult(title: title, cbtEnhancements: cbtOut));
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    // In fullscreen dialogs, the Scaffold resizes for the keyboard already.
    final insetBottom = isCompact ? 0.0 : MediaQuery.viewInsetsOf(context).bottom;

    final body = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insetBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Task title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add CBT (optional)'),
            value: _addCbt,
            onChanged: (v) => setState(() => _addCbt = v),
          ),
          if (_addCbt) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _micro,
              decoration: const InputDecoration(
                labelText: 'Micro version',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _obstacle,
              decoration: const InputDecoration(
                labelText: 'Predicted obstacle',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ifThen,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'If-Then plan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Confidence: ${_confidence.round()}/10',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Slider(
              value: _confidence,
              min: 0,
              max: 10,
              divisions: 10,
              label: _confidence.round().toString(),
              onChanged: (v) => setState(() => _confidence = v),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reward,
              decoration: const InputDecoration(
                labelText: 'Reward',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );

    if (isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(widget.dialogTitle),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancel,
            ),
            actions: [
              TextButton(
                onPressed: _submit,
                child: Text(widget.primaryActionText),
              ),
            ],
          ),
          body: SafeArea(child: body),
        ),
      );
    }

    return AlertDialog(
      scrollable: true,
      title: Text(widget.dialogTitle),
      content: body,
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.primaryActionText)),
      ],
    );
  }
}

