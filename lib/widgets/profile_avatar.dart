import 'package:flutter/material.dart';

import 'profile_avatar_web.dart' if (dart.library.io) 'profile_avatar_io.dart' as impl;
import '../utils/app_typography.dart';

/// Reusable profile avatar: shows image if path exists, else CircleAvatar with initial.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initial,
    this.imagePath,
    this.radius = 28,
    this.onTap,
  });

  final String? initial;
  final String? imagePath;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = radius * 2;
    final imageWidget = impl.buildProfileImageWidget(imagePath, size);

    Widget child;
    if (imageWidget != null) {
      child = imageWidget;
    } else {
      child = CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          (initial ?? '?').toUpperCase(),
          style: AppTypography.heading2(context).copyWith(
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    if (onTap != null) {
      child = GestureDetector(
        onTap: onTap,
        child: child,
      );
    }

    return child;
  }
}
