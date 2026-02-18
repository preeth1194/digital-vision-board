import 'dart:io';

import 'package:flutter/material.dart';

bool profileImageFileExists(String? path) =>
    path != null && path.isNotEmpty && File(path).existsSync();

Widget? buildProfileImageWidget(String? path, double size) {
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return ClipOval(
    child: Image.file(
      file,
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}
