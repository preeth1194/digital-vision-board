import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/journal_editor_models.dart';
import 'editor_spacing.dart';
import 'font_picker.dart';

/// Minimal floating app bar for the editor
class EditorAppBar extends StatelessWidget {
  final bool isEditing;
  final SaveStatus saveStatus;
  final VoidCallback onBack;
  final VoidCallback onAddImage;
  final VoidCallback onAddTag;
  final VoidCallback onSelectFont;
  final VoidCallback onRecordVoice;
  final EditorFont selectedFont;

  const EditorAppBar({
    required this.isEditing,
    required this.saveStatus,
    required this.onBack,
    required this.onAddImage,
    required this.onAddTag,
    required this.onSelectFont,
    required this.onRecordVoice,
    required this.selectedFont,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: EditorSpacing.appBarPadding,
        vertical: EditorSpacing.smallGap,
      ),
      child: Row(
        children: [
          // Back button with subtle styling
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              size: 20,
              color: colorScheme.onSurface,
            ),
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? colorScheme.surfaceContainerHigh
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EditorSpacing.smallRadius),
              ),
            ),
          ),
          const Spacer(),
          // Save status indicator
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _buildStatusIndicator(colorScheme),
          ),
          SizedBox(width: EditorSpacing.smallGap),
          // Action buttons in a pill container
          Container(
            padding: EdgeInsets.all(EditorSpacing.tinyGap),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHigh
                  : Colors.white,
              borderRadius: BorderRadius.circular(EditorSpacing.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                if (!isDark)
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 4,
                    offset: const Offset(-1, -1),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBarIconButton(
                  icon: Icons.font_download_outlined,
                  tooltip: 'Font: ${selectedFont.displayName}',
                  onTap: onSelectFont,
                ),
                AppBarIconButton(
                  icon: Icons.image_outlined,
                  tooltip: 'Add Image',
                  onTap: onAddImage,
                ),
                AppBarIconButton(
                  icon: Icons.mic_rounded,
                  tooltip: 'Voice Note',
                  onTap: onRecordVoice,
                ),
                AppBarIconButton(
                  icon: Icons.tag_rounded,
                  tooltip: 'Add Tag',
                  onTap: onAddTag,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(ColorScheme colorScheme) {
    switch (saveStatus) {
      case SaveStatus.saving:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Saving',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      case SaveStatus.saved:
        // Use a themed success color
        final successColor = Color.lerp(colorScheme.primary, Colors.green, 0.5)!;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: successColor,
            ),
            const SizedBox(width: 4),
            Text(
              'Saved',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: successColor,
              ),
            ),
          ],
        );
      case SaveStatus.error:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: colorScheme.error,
            ),
            const SizedBox(width: 4),
            Text(
              'Error',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colorScheme.error,
              ),
            ),
          ],
        );
      case SaveStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

/// Icon button for the app bar with modern interaction
class AppBarIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<AppBarIconButton> createState() => _AppBarIconButtonState();
}

class _AppBarIconButtonState extends State<AppBarIconButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(EditorSpacing.smallGap),
            decoration: BoxDecoration(
              color: _isPressed
                  ? colorScheme.primary.withOpacity(0.15)
                  : (_isHovered
                      ? colorScheme.primary.withOpacity(0.08)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(EditorSpacing.smallRadius),
            ),
            transform: _isPressed
                ? (Matrix4.identity()..scale(0.92))
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 20,
              color: _isHovered || _isPressed
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}
