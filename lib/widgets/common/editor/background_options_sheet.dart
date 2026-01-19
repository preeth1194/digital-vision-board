import 'package:flutter/material.dart';

Future<void> showBackgroundOptionsSheet(
  BuildContext context, {
  required VoidCallback onPickBackgroundImage,
  required ValueChanged<Color> onPickColor,
  required VoidCallback onClearBackgroundImage,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final colors = <Color>[
        const Color(0xFFF7F7FA),
        Colors.white,
        const Color(0xFF111827),
        const Color(0xFF0EA5E9),
        const Color(0xFF10B981),
        const Color(0xFFF59E0B),
        const Color(0xFFEF4444),
        const Color(0xFF8B5CF6),
      ];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Background',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onPickBackgroundImage();
                },
                icon: const Icon(Icons.image_outlined),
                label: const Text('Upload background image'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: colors
                    .map(
                      (c) => InkWell(
                        onTap: () => onPickColor(c),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onClearBackgroundImage();
                },
                icon: const Icon(Icons.hide_image_outlined),
                label: const Text('Clear background image'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

