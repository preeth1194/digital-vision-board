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

final class NameAndCategoryResult {
  final String name;
  final String? category;
  const NameAndCategoryResult({required this.name, required this.category});
}

Future<NameAndCategoryResult?> showAddNameAndCategoryDialog(
  BuildContext context, {
  required String title,
  String? categoryHint,
  List<String> categorySuggestions = const <String>[],
}) {
  return showDialog<NameAndCategoryResult>(
    context: context,
    builder: (context) => _AddNameAndCategoryDialog(
      title: title,
      categoryHint: categoryHint,
      categorySuggestions: categorySuggestions,
    ),
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
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 600;
    final insetBottom = MediaQuery.viewInsetsOf(context).bottom;

    final field = TextField(
      controller: _nameController,
      decoration: const InputDecoration(hintText: 'e.g. Fitness'),
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => _submit(),
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
          child: const Text('Set Name'),
        ),
      ],
    );
  }
}

class _AddNameAndCategoryDialog extends StatefulWidget {
  final String title;
  final String? categoryHint;
  final List<String> categorySuggestions;

  const _AddNameAndCategoryDialog({
    required this.title,
    required this.categoryHint,
    required this.categorySuggestions,
  });

  @override
  State<_AddNameAndCategoryDialog> createState() => _AddNameAndCategoryDialogState();
}

class _AddNameAndCategoryDialogState extends State<_AddNameAndCategoryDialog> {
  late final TextEditingController _nameController;
  TextEditingController? _categoryController;

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
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final rawCategory = (_categoryController?.text ?? '').trim();
    Navigator.of(context).pop(
      NameAndCategoryResult(
        name: name,
        category: rawCategory.isEmpty ? null : rawCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 600;
    final insetBottom = MediaQuery.viewInsetsOf(context).bottom;
    final suggestions = widget.categorySuggestions
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final body = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insetBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'e.g. Fitness'),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final q = textEditingValue.text.trim().toLowerCase();
                    if (suggestions.isEmpty) return const Iterable<String>.empty();
                    if (q.isEmpty) return suggestions;
                    return suggestions.where((s) => s.toLowerCase().contains(q));
                  },
                  onSelected: (v) {
                    final c = _categoryController;
                    if (c != null) c.text = v;
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    _categoryController ??= textController;
                    return TextField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: widget.categoryHint ?? 'Category (optional)',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _submit(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Pick category',
                enabled: suggestions.isNotEmpty,
                onSelected: (v) => setState(() {
                  final c = _categoryController;
                  if (c != null) c.text = v;
                }),
                itemBuilder: (ctx) => suggestions
                    .map((s) => PopupMenuItem<String>(value: s, child: Text(s)))
                    .toList(),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.arrow_drop_down),
                ),
              ),
            ],
          ),
        ],
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
          body: SafeArea(child: body),
        ),
      );
    }

    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: body,
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
