import 'package:flutter/material.dart';

/// Simple multiline text editor dialog that returns the entered text (or null).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String initialText,
}) async {
  final controller = TextEditingController(text: initialText);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
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
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

