import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Simple multiline text editor dialog that returns the entered text (or null).
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
  late final FocusNode _focus;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focus = FocusNode();
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
    _focus.dispose();
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  Future<bool> _maybeConfirmDiscard() async {
    if (!widget.confirmDiscardIfDirty) return true;
    if (!_dirty) return true;
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 600;
    final insetBottom = MediaQuery.viewInsetsOf(context).bottom;

    // Multiline editor. On compact/fullscreen layouts we want it to expand and
    // feel like a proper notes editor, not a tiny input at the top.
    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: TextInputType.multiline,
      maxLines: isCompact ? null : 5,
      minLines: isCompact ? null : 3,
      expands: isCompact,
      textCapitalization: TextCapitalization.sentences,
      autofocus: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ),
    );

    final editor = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((widget.subtitle ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              widget.subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                  color: Colors.black.withOpacity(0.05),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: InputDecorationTheme(
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_hasText)
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            const Spacer(),
            TextButton(
              onPressed: _cancel,
              child: Text(widget.cancelText),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.saveText),
            ),
          ],
        ),
      ],
    );

    final shortcuts = Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.enter, control: true): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter, meta: true): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
            _cancel();
            return null;
          }),
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _submit();
            return null;
          }),
        },
        child: const SizedBox.shrink(),
      ),
    );

    if (isCompact) {
      return WillPopScope(
        onWillPop: () async => await _maybeConfirmDiscard(),
        child: Dialog.fullscreen(
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              title: Text(widget.title),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancel,
              ),
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insetBottom),
                    child: editor,
                  ),
                  // Keyboard shortcuts handler (desktop/web).
                  shortcuts,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async => await _maybeConfirmDiscard(),
      child: AlertDialog(
        title: Text(widget.title),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        content: SizedBox(
          width: 560,
          height: 360,
          child: AnimatedPadding(
            padding: EdgeInsets.only(bottom: insetBottom),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Stack(children: [editor, shortcuts]),
          ),
        ),
      ),
    );
  }
}

