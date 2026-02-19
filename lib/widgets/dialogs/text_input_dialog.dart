import 'package:flutter/material.dart';

/// Simple text input dialog that returns the entered text (or null).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String initialText,
  String? subtitle,
  String hintText = 'Type something...',
  String cancelText = 'Cancel',
  String saveText = 'Save',
  bool confirmDiscardIfDirty = true,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      initialText: initialText,
      subtitle: subtitle,
      hintText: hintText,
      cancelText: cancelText,
      saveText: saveText,
      confirmDiscardIfDirty: confirmDiscardIfDirty,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String initialText;
  final String hintText;
  final String cancelText;
  final String saveText;
  final bool confirmDiscardIfDirty;

  const _TextInputDialog({
    required this.title,
    required this.initialText,
    required this.subtitle,
    required this.hintText,
    required this.cancelText,
    required this.saveText,
    required this.confirmDiscardIfDirty,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _dirty = _controller.text != widget.initialText;
    _controller.addListener(() {
      final nextDirty = _controller.text != widget.initialText;
      if (nextDirty == _dirty) return;
      if (!mounted) return;
      setState(() => _dirty = nextDirty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  Future<bool> _maybeConfirmDiscard() async {
    if (!widget.confirmDiscardIfDirty) return true;
    if (!_dirty) return true;
    final colorScheme = Theme.of(context).colorScheme;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return res == true;
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  Future<void> _cancel() async {
    final ok = await _maybeConfirmDiscard();
    if (!ok) return;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _clear() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final insetBottom = MediaQuery.viewInsetsOf(context).bottom;

    return WillPopScope(
      onWillPop: () async => await _maybeConfirmDiscard(),
      child: AlertDialog(
        // Keep the dialog above the keyboard without injecting large blank
        // padding into the content (which can look like an empty sheet).
        insetPadding: EdgeInsets.fromLTRB(24, 24, 24, 24 + insetBottom),
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if ((widget.subtitle ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  widget.subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: const OutlineInputBorder(),
                suffixIcon: _hasText
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: _clear,
                      )
                    : null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancel,
            child: Text(widget.cancelText),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.saveText),
          ),
        ],
      ),
    );
  }
}

