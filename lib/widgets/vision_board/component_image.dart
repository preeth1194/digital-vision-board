import 'package:flutter/material.dart';

import '../../utils/file_image_provider.dart';

/// Renders an image from either a URL or a local file path.
Widget componentImageForPath(BuildContext context, String path) {
  final colorScheme = Theme.of(context).colorScheme;
  final lower = path.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return Image.network(path, fit: BoxFit.cover);
  }

  final provider = fileImageProviderFromPath(path);
  if (provider != null) {
    return Image(image: provider, fit: BoxFit.cover);
  }

  return Container(
    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined),
  );
}

