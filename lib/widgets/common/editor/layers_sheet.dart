import 'package:flutter/material.dart';

import '../../models/vision_components.dart';
import '../../utils/component_label_utils.dart';

Future<void> showLayersSheet(
  BuildContext context, {
  required List<VisionComponent> componentsTopToBottom,
  required String? selectedId,
  required ValueChanged<List<VisionComponent>> onReorder,
  required ValueChanged<String> onSelect,
  required ValueChanged<String> onDelete,
  ValueChanged<String>? onComplete,
  bool allowReorder = true,
  bool allowDelete = true,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _LayersSheet(
      components: componentsTopToBottom,
      selectedId: selectedId,
      onReorder: onReorder,
      onSelect: onSelect,
      onDelete: onDelete,
      onComplete: onComplete,
      allowReorder: allowReorder,
      allowDelete: allowDelete,
    ),
  );
}

class _LayersSheet extends StatefulWidget {
  final List<VisionComponent> components;
  final String? selectedId;
  final ValueChanged<List<VisionComponent>> onReorder;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final ValueChanged<String>? onComplete;
  final bool allowReorder;
  final bool allowDelete;

  const _LayersSheet({
    required this.components,
    required this.selectedId,
    required this.onReorder,
    required this.onSelect,
    required this.onDelete,
    required this.onComplete,
    required this.allowReorder,
    required this.allowDelete,
  });

  @override
  State<_LayersSheet> createState() => _LayersSheetState();
}

class _LayersSheetState extends State<_LayersSheet> {
  late List<VisionComponent> _list;

  static bool _looksLikeInternalTileId(String s) => s.trim().toLowerCase().startsWith('tile_');

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.components);
  }

  @override
  void didUpdateWidget(covariant _LayersSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.components != oldWidget.components) {
      _list = List.from(widget.components);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowReorder = widget.allowReorder;
    final allowDelete = widget.allowDelete;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            allowReorder ? 'Layers (Drag to Reorder)' : 'Layers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        Flexible(
          child: allowReorder
              ? ReorderableListView(
                  shrinkWrap: true,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) newIndex -= 1;
                      final item = _list.removeAt(oldIndex);
                      _list.insert(newIndex, item);
                    });
                    widget.onReorder(List<VisionComponent>.from(_list));
                  },
                  children: [
                    for (final c in _list)
                      ListTile(
                        key: ValueKey(c.id),
                        title: Text(ComponentLabelUtils.categoryOrTitleOrId(c)),
                        subtitle: _looksLikeInternalTileId(c.id) ? null : Text(c.id),
                        leading: Icon(_getIconForType(c)),
                        selected: c.id == widget.selectedId,
                        onTap: () => widget.onSelect(c.id),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onComplete != null)
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                onPressed: () => widget.onComplete?.call(c.id),
                                tooltip: 'Mark completed',
                              ),
                            if (allowDelete)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => widget.onDelete(c.id),
                                tooltip: 'Delete',
                              ),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                      ),
                  ],
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in _list)
                      ListTile(
                        key: ValueKey(c.id),
                        title: Text(ComponentLabelUtils.categoryOrTitleOrId(c)),
                        subtitle: _looksLikeInternalTileId(c.id) ? null : Text(c.id),
                        leading: Icon(_getIconForType(c)),
                        selected: c.id == widget.selectedId,
                        onTap: () => widget.onSelect(c.id),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onComplete != null)
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                onPressed: () => widget.onComplete?.call(c.id),
                                tooltip: 'Mark completed',
                              ),
                            if (allowDelete)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => widget.onDelete(c.id),
                                tooltip: 'Delete',
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  IconData _getIconForType(VisionComponent c) {
    if (c is GoalOverlayComponent) return Icons.flag_outlined;
    if (c is ImageComponent) return Icons.image;
    if (c is TextComponent) return Icons.text_fields;
    return Icons.layers;
  }
}

