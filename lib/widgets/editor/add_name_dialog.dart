import 'package:flutter/material.dart';

Future<String?> showAddNameDialog(
  BuildContext context, {
  required String title,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _AddNameDialog(title: title),
  );
}

class _AddNameDialog extends StatefulWidget {
  final String title;
  const _AddNameDialog({required this.title});

  @override
  State<_AddNameDialog> createState() => _AddNameDialogState();
}

class _AddNameDialogState extends State<_AddNameDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _nameController.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(hintText: 'e.g. Fitness'),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Set Name'),
        ),
      ],
    );
  }
}

