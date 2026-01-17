import 'package:flutter/material.dart';

import '../../models/cbt_enhancements.dart';

final class ChecklistItemCreateResult {
  final String text;
  /// Optional due date (YYYY-MM-DD)
  final String? dueDate;
  final CbtEnhancements? cbtEnhancements;
  const ChecklistItemCreateResult({
    required this.text,
    required this.dueDate,
    required this.cbtEnhancements,
  });
}

Future<ChecklistItemCreateResult?> showAddChecklistItemDialog(
  BuildContext context, {
  String dialogTitle = 'Add checklist item',
  String primaryActionText = 'Add',
}) {
  return showDialog<ChecklistItemCreateResult?>(
    context: context,
    builder: (ctx) => _ChecklistItemDialog(
      dialogTitle: dialogTitle,
      primaryActionText: primaryActionText,
      initialText: '',
      initialDueDate: null,
      initialCbt: null,
    ),
  );
}

Future<ChecklistItemCreateResult?> showEditChecklistItemDialog(
  BuildContext context, {
  String dialogTitle = 'Edit checklist item',
  String primaryActionText = 'Save',
  required String initialText,
  required String? initialDueDate,
  required CbtEnhancements? initialCbt,
}) {
  return showDialog<ChecklistItemCreateResult?>(
    context: context,
    builder: (ctx) => _ChecklistItemDialog(
      dialogTitle: dialogTitle,
      primaryActionText: primaryActionText,
      initialText: initialText,
      initialDueDate: initialDueDate,
      initialCbt: initialCbt,
    ),
  );
}

class _ChecklistItemDialog extends StatefulWidget {
  final String dialogTitle;
  final String primaryActionText;
  final String initialText;
  final String? initialDueDate;
  final CbtEnhancements? initialCbt;

  const _ChecklistItemDialog({
    required this.dialogTitle,
    required this.primaryActionText,
    required this.initialText,
    required this.initialDueDate,
    required this.initialCbt,
  });

  @override
  State<_ChecklistItemDialog> createState() => _ChecklistItemDialogState();
}

class _ChecklistItemDialogState extends State<_ChecklistItemDialog> {
  late final TextEditingController _text;
  late final TextEditingController _micro;
  late final TextEditingController _obstacle;
  late final TextEditingController _ifThen;
  late final TextEditingController _reward;

  String? _dueDate;
  late bool _addCbt;
  late double _confidence;

  @override
  void initState() {
    super.initState();
    final cbt = widget.initialCbt;
    _text = TextEditingController(text: widget.initialText);
    _micro = TextEditingController(text: cbt?.microVersion ?? '');
    _obstacle = TextEditingController(text: cbt?.predictedObstacle ?? '');
    _ifThen = TextEditingController(text: cbt?.ifThenPlan ?? '');
    _reward = TextEditingController(text: cbt?.reward ?? '');
    _confidence = (cbt?.confidenceScore ?? 8).clamp(0, 10).toDouble();
    _addCbt = cbt != null;
    _dueDate = widget.initialDueDate;
  }

  @override
  void dispose() {
    _text.dispose();
    _micro.dispose();
    _obstacle.dispose();
    _ifThen.dispose();
    _reward.dispose();
    super.dispose();
  }

  static String _toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static bool _hasCbt(CbtEnhancements cbt) {
    return (cbt.microVersion ?? '').trim().isNotEmpty ||
        (cbt.predictedObstacle ?? '').trim().isNotEmpty ||
        (cbt.ifThenPlan ?? '').trim().isNotEmpty ||
        (cbt.reward ?? '').trim().isNotEmpty;
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _dueDate = _toIsoDate(picked));
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(null);
  }

  void _submit() {
    final label = _text.text.trim();
    if (label.isEmpty) return;

    final cbt = CbtEnhancements(
      microVersion: _micro.text.trim().isEmpty ? null : _micro.text.trim(),
      predictedObstacle: _obstacle.text.trim().isEmpty ? null : _obstacle.text.trim(),
      ifThenPlan: _ifThen.text.trim().isEmpty ? null : _ifThen.text.trim(),
      confidenceScore: _confidence.round(),
      reward: _reward.text.trim().isEmpty ? null : _reward.text.trim(),
    );
    final CbtEnhancements? cbtOut = (_addCbt && _hasCbt(cbt)) ? cbt : null;

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      ChecklistItemCreateResult(text: label, dueDate: _dueDate, cbtEnhancements: cbtOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final insetBottom = isCompact ? 0.0 : MediaQuery.viewInsetsOf(context).bottom;

    final body = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insetBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _text,
            decoration: const InputDecoration(
              labelText: 'Item',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_dueDate == null ? 'Due date (optional)' : 'Due $_dueDate'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Clear',
                onPressed: _dueDate == null ? null : () => setState(() => _dueDate = null),
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

