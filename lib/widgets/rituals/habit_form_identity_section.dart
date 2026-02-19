import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';

// --- STEP 1: IDENTITY (name + color in same control) ---
class Step1IdentityWithColor extends StatefulWidget {
  final GlobalKey colorSectionKey;
  final TextEditingController nameController;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final int selectedIconIndex;
  final List<(int, IconData, String)> iconsForCategory;
  final int selectedColorIndex;
  final List<(String, List<Color>)> allColors;
  final bool colorPickerExpanded;
  final bool customizeExpanded;
  final ValueChanged<bool> onColorPickerExpandedChanged;
  final ValueChanged<bool> onCustomizeExpandedChanged;
  final ValueChanged<int> onIconSelected;
  final ValueChanged<int> onColorSelected;
  final void Function(int index, Color gradientColor, Color darkColor)
  onCustomizePreset;
  final VoidCallback? onSectionExpanded;
  final String? nameError;
  final VoidCallback? onVoiceInputTap;
  final bool isSubscribed;

  const Step1IdentityWithColor({
    super.key,
    required this.colorSectionKey,
    required this.nameController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.selectedIconIndex,
    required this.iconsForCategory,
    required this.selectedColorIndex,
    required this.allColors,
    required this.colorPickerExpanded,
    required this.customizeExpanded,
    required this.onColorPickerExpandedChanged,
    required this.onCustomizeExpandedChanged,
    required this.onIconSelected,
    required this.onColorSelected,
    required this.onCustomizePreset,
    this.onSectionExpanded,
    this.nameError,
    this.onVoiceInputTap,
    this.isSubscribed = false,
  });

  @override
  State<Step1IdentityWithColor> createState() =>
      _Step1IdentityWithColorState();
}

class _Step1IdentityWithColorState extends State<Step1IdentityWithColor> {
  double _customizeHue = 0.0;
  bool _categoryIconExpanded = false;

  void _openCustomize() {
    _customizeHue = HSLColor.fromColor(
      widget.allColors[widget.selectedColorIndex].$2.first,
    ).hue;
    widget.onCustomizeExpandedChanged(true);
  }

  void _closeCustomize() {
    widget.onCustomizeExpandedChanged(false);
  }

  void _applyCustomColor() {
    final gradientColor = HSLColor.fromAHSL(
      1,
      _customizeHue,
      0.6,
      0.5,
    ).toColor();
    final darkColor = HSLColor.fromAHSL(1, _customizeHue, 0.6, 0.35).toColor();
    widget.onCustomizePreset(
      widget.selectedColorIndex,
      gradientColor,
      darkColor,
    );
    _closeCustomize();
  }

  Widget _buildInlineHuePicker(ColorScheme colorScheme) {
    final gradientColor = HSLColor.fromAHSL(
      1,
      _customizeHue,
      0.6,
      0.5,
    ).toColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: gradientColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: hueSpectrumColors,
              stops: [0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1],
            ),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 0,
              overlayColor: Colors.transparent,
              thumbColor: colorScheme.surface,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _customizeHue,
              min: 0,
              max: 360,
              onChanged: (v) => setState(() => _customizeHue = v),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _applyCustomColor,
          child: const Text('Use this color'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = widget.allColors[widget.selectedColorIndex].$2;

    return CupertinoListSection.insetGrouped(
      header: Row(
        children: [
          Text(
            "Habit",
            style: AppTypography.caption(context).copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (widget.onVoiceInputTap != null)
            GestureDetector(
              onTap: widget.onVoiceInputTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mic_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Voice',
                      style: AppTypography.caption(context).copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    if (!widget.isSubscribed) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRO',
                          style: AppTypography.caption(context).copyWith(
                            color: colorScheme.tertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 8,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: habitSectionDecoration(colorScheme),
      separatorColor: habitSectionSeparatorColor(colorScheme),
      children: [
        // Name + color row
        Container(
          key: widget.colorSectionKey,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: widget.nameController,
                style: AppTypography.body(context),
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: "Add a habit (e.g., meditation)",
                  hintStyle: AppTypography.body(context).copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  errorText: widget.nameError,
                  errorStyle: AppTypography.caption(context).copyWith(
                    color: colorScheme.error,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: widget.nameError != null
                          ? colorScheme.error
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: widget.nameError != null
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      final next = !widget.colorPickerExpanded;
                      widget.onColorPickerExpandedChanged(next);
                      if (!next) widget.onCustomizeExpandedChanged(false);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.first.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.colorPickerExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: widget.allColors.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (ctx, index) => SizedBox(
                                  width: 36,
                                  child: AnimatedColorTile(
                                    colors: widget.allColors[index].$2,
                                    isSelected:
                                        widget.selectedColorIndex == index,
                                    onTap: () => widget.onColorSelected(index),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: kControlSpacing),
                            InkWell(
                              onTap: () => widget.customizeExpanded
                                  ? _closeCustomize()
                                  : _openCustomize(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.palette_outlined,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Customize color",
                                      style: AppTypography.bodySmall(context)
                                          .copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      widget.customizeExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      if (widget.customizeExpanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildInlineHuePicker(colorScheme),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Merged category + icon picker
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoListTile.notched(
              leading: Icon(
                habitIcons[widget.selectedIconIndex].$1,
                color: colors.first,
                size: 28,
              ),
              title: Text(
                widget.selectedCategory != null
                    ? '${widget.selectedCategory} / ${habitIcons[widget.selectedIconIndex].$2}'
                    : habitIcons[widget.selectedIconIndex].$2,
                style: AppTypography.body(context),
              ),
              trailing: Icon(
                _categoryIconExpanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                setState(
                    () => _categoryIconExpanded = !_categoryIconExpanded);
                if (_categoryIconExpanded) {
                  widget.onSectionExpanded?.call();
                }
              },
            ),
            if (_categoryIconExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: kHabitCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (ctx, index) {
                          final cat = kHabitCategories[index];
                          final isSelected = widget.selectedCategory == cat;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onCategoryChanged(isSelected ? null : cat);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant,
                                  width: isSelected ? 0 : 1,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: AppTypography.caption(context).copyWith(
                                  color: isSelected
                                      ? contrastColor(colorScheme.primary)
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.iconsForCategory.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, index) {
                          final entry = widget.iconsForCategory[index];
                          final globalIndex = entry.$1;
                          return SizedBox(
                            width: 50,
                            child: AnimatedIconTile(
                              icon: entry.$2,
                              label: entry.$3,
                              isSelected:
                                  widget.selectedIconIndex == globalIndex,
                              onTap: () => widget.onIconSelected(globalIndex),
                              accentColor: colors.first,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// Animated Icon Tile for carousel
class AnimatedIconTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  const AnimatedIconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  @override
  State<AnimatedIconTile> createState() => _AnimatedIconTileState();
}

class _AnimatedIconTileState extends State<AnimatedIconTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void didUpdateWidget(AnimatedIconTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = widget.isSelected
              ? _bounceAnimation.value
              : _scaleAnimation.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? (widget.accentColor ?? colorScheme.primary).withValues(
                        alpha: 0.2,
                      )
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: widget.isSelected
                    ? (widget.accentColor ?? colorScheme.primary)
                    : colorScheme.onSurfaceVariant,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Animated Color Tile
class AnimatedColorTile extends StatefulWidget {
  final List<Color> colors;
  final bool isSelected;
  final VoidCallback onTap;

  const AnimatedColorTile({
    super.key,
    required this.colors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<AnimatedColorTile> createState() => _AnimatedColorTileState();
}

class _AnimatedColorTileState extends State<AnimatedColorTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.colors),
            shape: BoxShape.circle,
            border: widget.isSelected
                ? Border.all(color: colorScheme.onSurface, width: 3)
                : null,
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withValues(alpha: 0.4),
                blurRadius: widget.isSelected ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: widget.isSelected
              ? Icon(Icons.check, color: colorScheme.onPrimary, size: 22)
              : null,
        ),
      ),
    );
  }
}

// Animated Icon Button
class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const AnimatedIconButton({super.key, required this.icon, required this.onTap});

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.9).animate(_controller),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, color: colorScheme.primary, size: 28),
        ),
      ),
    );
  }
}
