import 'package:flutter/material.dart';

class TextEditorResult {
  final String text;
  final TextStyle style;

  const TextEditorResult({required this.text, required this.style});
}

Future<TextEditorResult?> showTextEditorDialog(
  BuildContext context, {
  required String initialText,
  required TextStyle initialStyle,
}) async {
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => _TextEditorDialog(
      initialText: initialText,
      initialStyle: initialStyle,
    ),
  );
  if (result == null) return null;
  return TextEditorResult(
    text: result['text'] as String,
    style: result['style'] as TextStyle,
  );
}

class _TextEditorDialog extends StatefulWidget {
  final String initialText;
  final TextStyle initialStyle;

  const _TextEditorDialog({
    required this.initialText,
    required this.initialStyle,
  });

  @override
  State<_TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<_TextEditorDialog> {
  late final TextEditingController _textController;
  late double _fontSize;
  late Color _textColor;
  late FontWeight _fontWeight;
  late TextAlign _textAlign;
  late final VoidCallback _textListener;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _fontSize = widget.initialStyle.fontSize ?? 28;
    _textColor = widget.initialStyle.color ?? Colors.black;
    _fontWeight = widget.initialStyle.fontWeight ?? FontWeight.w600;
    _textAlign = TextAlign.left;

    _textListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _textController.addListener(_textListener);
  }

  @override
  void dispose() {
    _textController.removeListener(_textListener);
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final style = TextStyle(
      fontSize: _fontSize,
      color: _textColor,
      fontWeight: _fontWeight,
    );

    Navigator.of(context).pop({'text': text, 'style': style, 'textAlign': _textAlign});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Text Editor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  _textController.text.isEmpty ? 'Preview' : _textController.text,
                  style: TextStyle(fontSize: _fontSize, color: _textColor, fontWeight: _fontWeight),
                  textAlign: _textAlign,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Type something...',
                  border: OutlineInputBorder(),
                ),
                autofocus: widget.initialText.isEmpty,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Font Size: '),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 72,
                      divisions: 30,
                      label: _fontSize.round().toString(),
                      onChanged: (value) => setState(() => _fontSize = value),
                    ),
                  ),
                  Text('${_fontSize.round()}'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const ValueKey('formatting_dropdown'),
                    initiallyExpanded: false,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 8),
                    title: const Text('Formatting'),
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<FontWeight>(
                          segments: const [
                            ButtonSegment(
                              value: FontWeight.w300,
                              label: Icon(Icons.format_size),
                              tooltip: 'Light',
                            ),
                            ButtonSegment(
                              value: FontWeight.normal,
                              label: Icon(Icons.text_fields),
                              tooltip: 'Normal',
                            ),
                            ButtonSegment(
                              value: FontWeight.w600,
                              label: Icon(Icons.format_bold),
                              tooltip: 'Bold',
                            ),
                          ],
                          selected: {_fontWeight},
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onSelectionChanged: (newSelection) =>
                              setState(() => _fontWeight = newSelection.first),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<TextAlign>(
                          segments: const [
                            ButtonSegment(
                              value: TextAlign.left,
                              label: Icon(Icons.format_align_left),
                              tooltip: 'Left',
                            ),
                            ButtonSegment(
                              value: TextAlign.center,
                              label: Icon(Icons.format_align_center),
                              tooltip: 'Center',
                            ),
                            ButtonSegment(
                              value: TextAlign.right,
                              label: Icon(Icons.format_align_right),
                              tooltip: 'Right',
                            ),
                          ],
                          selected: {_textAlign},
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onSelectionChanged: (newSelection) =>
                              setState(() => _textAlign = newSelection.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: [
                  const Text('Color: '),
                  ..._colorOptions.map((color) {
                    return InkWell(
                      onTap: () => setState(() => _textColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _textColor == color ? Colors.blue : Colors.grey,
                            width: _textColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<Color> _colorOptions = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.amber,
  ];
}

