import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'editor_spacing.dart';

/// Available font options for the journal editor.
enum EditorFont {
  inter('Inter', 'Sans Serif'),
  merriweather('Merriweather', 'Serif'),
  caveat('Caveat', 'Handwritten'),
  jetBrainsMono('JetBrains Mono', 'Monospace'),
  playfairDisplay('Playfair Display', 'Elegant');

  final String fontFamily;
  final String displayName;

  const EditorFont(this.fontFamily, this.displayName);

  TextStyle getTextStyle({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double height = 1.8,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    switch (this) {
      case EditorFont.inter:
        return GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          fontStyle: fontStyle,
        );
      case EditorFont.merriweather:
        return GoogleFonts.merriweather(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          fontStyle: fontStyle,
        );
      case EditorFont.caveat:
        return GoogleFonts.caveat(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          fontStyle: fontStyle,
        );
      case EditorFont.jetBrainsMono:
        return GoogleFonts.jetBrainsMono(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          fontStyle: fontStyle,
        );
      case EditorFont.playfairDisplay:
        return GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
          fontStyle: fontStyle,
        );
    }
  }

  /// Get title style (larger, bolder)
  TextStyle getTitleStyle({Color? color}) {
    return getTextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.3,
    );
  }
}

/// Font picker bottom sheet with neumorphic design
class FontPickerSheet extends StatelessWidget {
  final EditorFont selectedFont;
  final void Function(EditorFont) onFontSelected;

  const FontPickerSheet({
    required this.selectedFont,
    required this.onFontSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: EdgeInsets.all(EditorSpacing.elementGap),
                child: Text(
                  'Choose Font',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              // Font options - scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    EditorSpacing.elementGap,
                    0,
                    EditorSpacing.elementGap,
                    EditorSpacing.elementGap,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: EditorFont.values.map((font) {
                      final isSelected = font == selectedFont;
                      return Padding(
                        padding: EdgeInsets.only(bottom: EditorSpacing.smallGap),
                        child: _FontOptionTile(
                          font: font,
                          isSelected: isSelected,
                          onTap: () => onFontSelected(font),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual font option tile with neumorphic styling
class _FontOptionTile extends StatefulWidget {
  final EditorFont font;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontOptionTile({
    required this.font,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FontOptionTile> createState() => _FontOptionTileState();
}

class _FontOptionTileState extends State<_FontOptionTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(EditorSpacing.elementGap),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? colorScheme.primaryContainer
              : (isDark ? colorScheme.surfaceContainer : colorScheme.surface),
          borderRadius: BorderRadius.circular(EditorSpacing.cardRadius),
          border: Border.all(
            color: widget.isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withOpacity(0.3),
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(isDark ? 0.3 : 0.08),
                    offset: const Offset(2, 2),
                    blurRadius: 6,
                  ),
                  if (!isDark)
                    BoxShadow(
                      color: colorScheme.surface.withOpacity(0.8),
                      offset: const Offset(-2, -2),
                      blurRadius: 6,
                    ),
                ],
        ),
        transform: _isPressed
            ? Matrix4.translationValues(0, 1, 0)
            : Matrix4.identity(),
        child: Row(
          children: [
            // Font preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.font.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: EditorSpacing.tinyGap),
                  Text(
                    'The quick brown fox jumps over the lazy dog',
                    style: widget.font.getTextStyle(
                      fontSize: 14,
                      color: widget.isSelected
                          ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                          : colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Selection indicator
            if (widget.isSelected)
              Container(
                padding: EdgeInsets.all(EditorSpacing.smallGap),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: colorScheme.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
