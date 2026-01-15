import 'package:flutter/material.dart';

/// Simple multiline text editor dialog that returns the entered text (or null).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String initialText,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      initialText: initialText,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String initialText;

  const _TextInputDialog({
    required this.title,
    required this.initialText,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: 5,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Type something...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

