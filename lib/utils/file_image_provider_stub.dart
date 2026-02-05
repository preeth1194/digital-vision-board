import 'package:flutter/widgets.dart';

Future<bool> fileExists(String path) async => false;

ImageProvider? fileImageProviderFromPath(String path) {
  final p = path.trim();
  if (p.isEmpty) return null;
  final lower = p.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return NetworkImage(p);
  }
  return null;
}

