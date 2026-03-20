import 'dart:ui';

import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Clip clipBehavior;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.borderRadius = AppSpacing.radiusCard,
    this.clipBehavior = Clip.antiAlias,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fillColor = isDark
        ? AppColors.cloudWhite.withValues(alpha: 0.08)
        : AppColors.cloudWhite.withValues(alpha: 0.55);

    final borderColor = isDark
        ? AppColors.cloudWhite.withValues(alpha: 0.12)
        : AppColors.cloudWhite.withValues(alpha: 0.7);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: borderColor, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : AppColors.forestDeep.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: onTap != null
                  ? InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: child,
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}
