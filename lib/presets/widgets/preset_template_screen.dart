import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Extend modal background into safe area so no background shows through
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipPath(
        clipper: showBottomNotch
            ? const _NotchedBottomClipper(
                cutoutRadius: 34,
                cutoutCenterOffset: 10,
              )
            : null,
        child: Container(
          decoration: AppColors.cloudDecoration(isDark: isDark),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                habitCategory.toUpperCase(),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                presetName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.3,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$totalSteps ${totalSteps == 1 ? 'step' : 'steps'}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (config.allowEdit && onEdit != null)
                          IconButton(
                            tooltip: 'Edit preset',
                            onPressed: onEdit,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    // Steps preview
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: SingleChildScrollView(
                        child: previewSections.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No preview configured for this preset.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
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
                                    if (i < previewSections.length - 1) ...[
                                      const SizedBox(height: 8),
                                      Divider(
                                        height: 1,
                                        thickness: 0.5,
                                        color: colorScheme.outlineVariant
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ],
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: onClose,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.onSurfaceVariant,
                                side: BorderSide(
                                  color: colorScheme.outlineVariant,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: onCreate,
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(config.createButtonLabel),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Fill bottom safe area so no background bleeds through
              SizedBox(height: bottomSafeArea > 0 ? bottomSafeArea : 16),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(section.icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              section.title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const Spacer(),
            Text(
              '${section.steps.length} ${section.steps.length == 1 ? 'step' : 'steps'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
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
        for (int i = 0; i < section.steps.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 0.5,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.steps[i].title.trim().isEmpty
                        ? (section.steps[i].displayTitle.isEmpty
                              ? 'Step ${i + 1}'
                              : section.steps[i].displayTitle)
                        : section.steps[i].title.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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

/// Full-page preset detail shown via [Navigator.push] with a Hero animation.
class PresetDetailPage extends StatelessWidget {
  final String heroTag;
  final String presetName;
  final String habitCategory;
  final int totalSteps;
  final PresetTemplateConfig config;
  final List<PresetPreviewSection> previewSections;

  const PresetDetailPage({
    super.key,
    required this.heroTag,
    required this.presetName,
    required this.habitCategory,
    required this.totalSteps,
    required this.config,
    required this.previewSections,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final headerColor = AppColors.categoryBgColor(habitCategory, isDark);
    final iconColor = AppColors.categoryIconColor(habitCategory, isDark);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Preset Detail',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop('close'),
        ),
        actions: [
          if (config.allowEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => Navigator.of(context).pop('edit'),
            ),
        ],
      ),
      body: Column(
        children: [
          Hero(
            tag: heroTag,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      headerColor.withValues(alpha: 0.55),
                      headerColor,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(
                        _iconForCategory(habitCategory),
                        size: 52,
                        color: iconColor.withValues(alpha: 0.2),
                      ),
                    ),
                    // Hero flight can temporarily squeeze height to match the
                    // source card; scale down instead of overflowing.
                    Align(
                      alignment: Alignment.topLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                habitCategory.toUpperCase(),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              presetName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$totalSteps ${totalSteps == 1 ? 'step' : 'steps'}',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: previewSections.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No preview configured for this preset.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < previewSections.length; i++) ...[
                          _buildRoutinePreview(context, previewSections[i]),
                          if (i < previewSections.length - 1) ...[
                            const SizedBox(height: 8),
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop('close'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                        side: BorderSide(color: colorScheme.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: config.allowCreateHabits
                          ? () => Navigator.of(context).pop('create')
                          : null,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(config.createButtonLabel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'health':
        return Icons.favorite_outline;
      case 'fitness':
        return Icons.fitness_center;
      case 'productivity':
        return Icons.bolt_outlined;
      case 'mindfulness':
        return Icons.self_improvement_outlined;
      case 'learning':
        return Icons.menu_book_outlined;
      case 'relationships':
        return Icons.people_outline;
      case 'finance':
        return Icons.account_balance_wallet_outlined;
      case 'creativity':
        return Icons.palette_outlined;
      case 'skincare':
        return Icons.face_outlined;
      case 'workout':
        return Icons.fitness_center;
      case 'weekly meal prep':
        return Icons.calendar_month_outlined;
      default:
        return Icons.grid_view_rounded;
    }
  }

  Widget _buildRoutinePreview(
    BuildContext context,
    PresetPreviewSection section,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(section.icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              section.title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const Spacer(),
            Text(
              '${section.steps.length} ${section.steps.length == 1 ? 'step' : 'steps'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
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
        for (int i = 0; i < section.steps.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 0.5,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.steps[i].title.trim().isEmpty
                        ? (section.steps[i].displayTitle.isEmpty
                              ? 'Step ${i + 1}'
                              : section.steps[i].displayTitle)
                        : section.steps[i].title.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
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
