import 'dart:ui';

import 'package:flutter/material.dart';
import '../models/preset_preview_section.dart';
import '../models/preset_template_config.dart';

class PresetTemplateScreen extends StatelessWidget {
  final String presetName;
  final String habitCategory;
  final int totalSteps;
  final PresetTemplateConfig config;
  final List<PresetPreviewSection> previewSections;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onCreate;
  final double bottomInset;
  final bool showBottomNotch;

  const PresetTemplateScreen({
    super.key,
    required this.presetName,
    required this.habitCategory,
    required this.totalSteps,
    required this.config,
    required this.previewSections,
    required this.onClose,
    this.onEdit,
    this.onCreate,
    this.bottomInset = 20,
    this.showBottomNotch = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveBottomInset = bottomInset;
    const actionButtonRadius = 14.0;
    const closeButtonRadius = 18.0;
    return Padding(
      padding: EdgeInsets.only(bottom: effectiveBottomInset),
      child: ClipPath(
        clipper: showBottomNotch
            ? const _NotchedBottomClipper(
                cutoutRadius: 34,
                cutoutCenterOffset: 10,
              )
            : null,
        child: _GlassSection(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(config.icon, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        presetName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (config.allowEdit && onEdit != null)
                      IconButton(
                        tooltip: 'Edit preset',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SingleChildScrollView(
                    child: previewSections.isEmpty
                        ? Text(
                            'No preview section configured for this preset.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          )
                        : Column(
                            children: [
                              for (
                                int i = 0;
                                i < previewSections.length;
                                i++
                              ) ...[
                                _buildRoutinePreview(
                                  context,
                                  previewSections[i],
                                ),
                                if (i < previewSections.length - 1)
                                  const SizedBox(height: 8),
                              ],
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onClose,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              closeButtonRadius,
                            ),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onCreate,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              actionButtonRadius,
                            ),
                          ),
                        ),
                        child: Text(config.createButtonLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoutinePreview(
    BuildContext context,
    PresetPreviewSection section,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                section.title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${section.steps.length} ${section.steps.length == 1 ? 'step' : 'steps'}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (section.steps.isEmpty)
            Text(
              'No steps',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          for (int i = 0; i < section.steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.14,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.steps[i].displayTitle.isEmpty
                          ? 'Step ${i + 1}'
                          : section.steps[i].displayTitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _sectionLabel(PresetTemplateSection section) {
    switch (section) {
      case PresetTemplateSection.routinePreview:
        return 'Preview';
      case PresetTemplateSection.weeklyPlanner:
        return 'Weekly';
      case PresetTemplateSection.products:
        return 'Products';
      case PresetTemplateSection.notes:
        return 'Notes';
      case PresetTemplateSection.linkedHabits:
        return 'Links';
    }
  }
}

class _NotchedBottomClipper extends CustomClipper<Path> {
  final double cutoutRadius;
  final double cutoutCenterOffset;

  const _NotchedBottomClipper({
    required this.cutoutRadius,
    required this.cutoutCenterOffset,
  });

  @override
  Path getClip(Size size) {
    final rect = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height + cutoutCenterOffset),
          radius: cutoutRadius,
        ),
      );
    return Path.combine(PathOperation.difference, rect, cutout);
  }

  @override
  bool shouldReclip(covariant _NotchedBottomClipper oldClipper) {
    return cutoutRadius != oldClipper.cutoutRadius ||
        cutoutCenterOffset != oldClipper.cutoutCenterOffset;
  }
}

class _GlassSection extends StatelessWidget {
  final Widget child;
  const _GlassSection({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.60),
              width: 1.1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
