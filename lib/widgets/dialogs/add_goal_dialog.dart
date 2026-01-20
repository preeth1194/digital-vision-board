import 'package:flutter/material.dart';

import '../../models/goal_metadata.dart';
import '../../utils/app_typography.dart';

/// Result returned from the add goal dialog
class AddGoalResult {
  final String name;
  final String? category;
  final String? whyImportant;
  final String? deadline; // ISO-8601 date string (yyyy-mm-dd)

  const AddGoalResult({
    required this.name,
    this.category,
    this.whyImportant,
    this.deadline,
  });
}

/// Shows a unified add/edit goal dialog that matches the wizard screen style.
/// 
/// This dialog provides a consistent UI for adding goals across the app.
/// It includes fields for name, category, why important, and optional deadline.
/// 
/// [initialName] - Pre-filled goal name (for editing)
/// [initialCategory] - Pre-filled category
/// [initialWhyImportant] - Pre-filled "why important" text
/// [initialDeadline] - Pre-filled deadline (ISO-8601 date string)
/// [categorySuggestions] - List of suggested categories for autocomplete
/// [showWhyImportant] - Whether to show the "why important" field (default: true)
/// [showDeadline] - Whether to show the deadline field (default: true)
Future<AddGoalResult?> showAddGoalDialog(
  BuildContext context, {
  String? initialName,
  String? initialCategory,
  String? initialWhyImportant,
  String? initialDeadline,
  List<String> categorySuggestions = const <String>[],
  bool showWhyImportant = true,
  bool showDeadline = true,
}) async {
  final nameC = TextEditingController(text: initialName ?? '');
  final whyC = TextEditingController(text: initialWhyImportant ?? '');
  String category = initialCategory ?? '';
  String? deadline = initialDeadline;
  final suggestions = categorySuggestions
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final res = await showModalBottomSheet<AddGoalResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      initialName == null ? 'Add goal' : 'Edit goal',
                      style: AppTypography.heading3(ctx),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'Goal name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    if (suggestions.isNotEmpty || category.isNotEmpty)
                      Autocomplete<String>(
                        initialValue: category.isEmpty ? null : TextEditingValue(text: category),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final q = textEditingValue.text.trim().toLowerCase();
                          if (suggestions.isEmpty) return const Iterable<String>.empty();
                          if (q.isEmpty) return suggestions;
                          return suggestions.where((s) => s.toLowerCase().contains(q));
                        },
                        onSelected: (v) => setLocal(() => category = v),
                        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                          if (category.isNotEmpty && textController.text.isEmpty) {
                            textController.text = category;
                          }
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (v) => setLocal(() => category = v),
                          );
                        },
                      )
                    else
                      TextField(
                        onChanged: (v) => setLocal(() => category = v),
                        decoration: const InputDecoration(
                          labelText: 'Category (optional)',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    if (showWhyImportant) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: whyC,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Why is this important to you?',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                    if (showDeadline) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event_outlined),
                        label: Text(deadline == null ? 'Add deadline (optional)' : 'Deadline: $deadline'),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime(now.year, now.month, now.day),
                            lastDate: DateTime(now.year + 10),
                            initialDate: deadline != null
                                ? DateTime.parse(deadline!)
                                : DateTime(now.year, now.month, now.day),
                          );
                          if (picked != null) {
                            final yyyy = picked.year.toString().padLeft(4, '0');
                            final mm = picked.month.toString().padLeft(2, '0');
                            final dd = picked.day.toString().padLeft(2, '0');
                            setLocal(() => deadline = '$yyyy-$mm-$dd');
                          }
                        },
                      ),
                      if (deadline != null)
                        TextButton(
                          onPressed: () => setLocal(() => deadline = null),
                          child: const Text('Clear deadline'),
                        ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () {
                        final nm = nameC.text.trim();
                        if (nm.isEmpty) return;
                        Navigator.of(ctx).pop(
                          AddGoalResult(
                            name: nm,
                            category: category.trim().isEmpty ? null : category.trim(),
                            whyImportant: showWhyImportant
                                ? (whyC.text.trim().isEmpty ? null : whyC.text.trim())
                                : null,
                            deadline: deadline,
                          ),
                        );
                      },
                      child: Text(initialName == null ? 'Add goal' : 'Save goal'),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );

  return res;
}
