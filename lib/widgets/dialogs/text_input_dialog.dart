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
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 600;
    final insetBottom = MediaQuery.viewInsetsOf(context).bottom;

    final field = TextField(
      controller: _controller,
      maxLines: isCompact ? null : 5,
      minLines: 3,
      textCapitalization: TextCapitalization.sentences,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Type something...',
        border: OutlineInputBorder(),
      ),
    );

    if (isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(widget.title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              TextButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insetBottom),
              child: field,
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: AnimatedPadding(
        padding: EdgeInsets.only(bottom: insetBottom),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: field,
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

