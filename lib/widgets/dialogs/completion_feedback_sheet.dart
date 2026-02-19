import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class CompletionFeedbackResult {
  final int rating; // 1..5
  final String? note;

  const CompletionFeedbackResult({required this.rating, required this.note});
}

Future<CompletionFeedbackResult?> showCompletionFeedbackSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  int initialRating = 5,
  String? initialNote,
  String primaryActionText = 'Save',
}) async {
  return showModalBottomSheet<CompletionFeedbackResult?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CompletionFeedbackSheet(
      title: title,
      subtitle: subtitle,
      initialRating: initialRating.clamp(1, 5),
      initialNote: initialNote,
      primaryActionText: primaryActionText,
    ),
  ).then((result) {
    // Auto-save with rating 5 if dismissed without explicit save
    if (result == null) {
      return CompletionFeedbackResult(rating: 5, note: null);
    }
    return result;
  });
}

class _CompletionFeedbackSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int initialRating;
  final String? initialNote;
  final String primaryActionText;

  const _CompletionFeedbackSheet({
    required this.title,
    required this.subtitle,
    required this.initialRating,
    required this.initialNote,
    required this.primaryActionText,
  });

  @override
  State<_CompletionFeedbackSheet> createState() => _CompletionFeedbackSheetState();
}

class _CompletionFeedbackSheetState extends State<_CompletionFeedbackSheet> {
  late int _rating;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _note = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _note.text.trim();
    Navigator.of(context).pop(
      CompletionFeedbackResult(
        rating: _rating,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.subtitle!, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Rating'),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _rating.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _rating.toString(),
                  onChanged: (v) => setState(() => _rating = v.round()),
                ),
              ),
              SizedBox(width: 36, child: Text(_rating.toString(), textAlign: TextAlign.end)),
            ],
          ),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: _submit,
                child: Text(widget.primaryActionText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

