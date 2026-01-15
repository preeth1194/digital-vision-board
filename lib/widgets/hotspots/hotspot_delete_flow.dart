import 'package:flutter/material.dart';

import '../../models/hotspot_model.dart';

Future<bool> confirmDeleteHotspot(BuildContext context, HotspotModel hotspot) async {
  final bool? shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete Hotspot'),
        content: const Text('Delete this hotspot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
        ],
      );
    },
  );
  return shouldDelete == true;
}

