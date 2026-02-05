import 'package:flutter/material.dart';

import '../../models/vision_components.dart';
import '../../utils/component_label_utils.dart';

Future<VisionComponent?> showGoalPickerSheet(
  BuildContext context, {
  required List<VisionComponent> components,
  String title = 'Select a goal',
}) {
  return showModalBottomSheet<VisionComponent?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _GoalPickerSheet(
      title: title,
      components: components,
    ),
  );
}

bool _isGoalLikeComponent(VisionComponent c) {
  if (c is ImageComponent) return c.goal != null;
  return false;
}

class _GoalPickerSheet extends StatefulWidget {
  final String title;
  final List<VisionComponent> components;

  const _GoalPickerSheet({
    required this.title,
    required this.components,
  });

  @override
  State<_GoalPickerSheet> createState() => _GoalPickerSheetState();
}

class _GoalPickerSheetState extends State<_GoalPickerSheet> {
  String _query = '';

  static String _labelFor(VisionComponent c) {
    return ComponentLabelUtils.categoryOrTitleOrId(c);
  }

  static bool _looksLikeInternalTileId(String s) {
    return s.trim().toLowerCase().startsWith('tile_');
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final q = _query.trim().toLowerCase();

    final goals = widget.components.where(_isGoalLikeComponent).toList();
    final sorted = [...goals]
      ..sort((a, b) => _labelFor(a).toLowerCase().compareTo(_labelFor(b).toLowerCase()));
    final filtered = q.isEmpty ? sorted : sorted.where((c) => _labelFor(c).toLowerCase().contains(q)).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search goals…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No goals found', style: TextStyle(color: Colors.grey))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final c = filtered[i];
                      final label = _labelFor(c);
                      final showIdSubtitle = !_looksLikeInternalTileId(c.id) && label != c.id;
                      return ListTile(
                        title: Text(label),
                        subtitle: showIdSubtitle
                            ? Text(c.id, style: const TextStyle(color: Colors.black54))
                            : null,
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

