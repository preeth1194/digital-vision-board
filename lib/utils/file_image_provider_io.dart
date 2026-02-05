import 'dart:io';

import 'package:flutter/widgets.dart';

Future<bool> fileExists(String path) async {
  final p = path.trim();
  if (p.isEmpty) return false;
  return File(p).exists();
}

ImageProvider? fileImageProviderFromPath(String path) {
  final p = path.trim();
  if (p.isEmpty) return null;
  final lower = p.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return NetworkImage(p);
  }
  return FileImage(File(p));
}

