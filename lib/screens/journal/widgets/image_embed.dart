import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../utils/app_typography.dart';
import 'editor_spacing.dart';

/// Custom embed builder for rendering images inline in the Quill editor.
/// Images are stored as BlockEmbed.image with JSON data containing path & width.
class JournalImageEmbedBuilder extends quill.EmbedBuilder {
  final void Function(String imagePath)? onImageDeleted;

  JournalImageEmbedBuilder({this.onImageDeleted});

  @override
  String get key => quill.BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final rawData = embedContext.node.value.data;
    String imagePath;
    double imageWidth;

    // Parse the embed data - supports JSON format {"path": ..., "width": ...}
    // or plain string path for backward compatibility
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      imagePath = data['path'] as String;
      imageWidth = (data['width'] as num?)?.toDouble() ?? 300.0;
    } catch (_) {
      // Fallback: treat data as plain image path
      imagePath = rawData as String;
      imageWidth = 300.0;
    }

    final isReadOnly = embedContext.readOnly;

    return _ResizableInlineImage(
      imagePath: imagePath,
      initialWidth: imageWidth,
      isReadOnly: isReadOnly,
      onResize: isReadOnly
          ? null
          : (double newWidth) {
              // Replace the embed with updated width
              final offset = embedContext.node.documentOffset;
              final newData = jsonEncode({'path': imagePath, 'width': newWidth});
              final newEmbed = quill.BlockEmbed.image(newData);
              embedContext.controller.replaceText(
                offset,
                1,
                newEmbed,
                null,
              );
            },
      onDelete: isReadOnly
          ? null
          : () {
              final offset = embedContext.node.documentOffset;
              embedContext.controller.replaceText(offset, 1, '', null);
              onImageDeleted?.call(imagePath);
            },
    );
  }
}

/// A resizable inline image widget with corner handles (matching reference design).
class _ResizableInlineImage extends StatefulWidget {
  final String imagePath;
  final double initialWidth;
  final bool isReadOnly;
  final void Function(double newWidth)? onResize;
  final VoidCallback? onDelete;

  const _ResizableInlineImage({
    required this.imagePath,
    required this.initialWidth,
    this.isReadOnly = false,
    this.onResize,
    this.onDelete,
  });

  @override
  State<_ResizableInlineImage> createState() => _ResizableInlineImageState();
}

class _ResizableInlineImageState extends State<_ResizableInlineImage>
    with SingleTickerProviderStateMixin {
  bool _isSelected = false;
  late double _currentWidth;
  double _startWidth = 0;
  Offset _startPosition = Offset.zero;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    _currentWidth = widget.initialWidth;
  }

  @override
  void didUpdateWidget(covariant _ResizableInlineImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWidth != widget.initialWidth) {
      _currentWidth = widget.initialWidth;
    }
  }

  double get _maxWidth {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth - (EditorSpacing.contentPadding * 2) - 32;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clampedWidth = _currentWidth.clamp(100.0, _maxWidth);

    return GestureDetector(
      onTap: widget.isReadOnly
          ? () => _showFullImage()
          : () => setState(() => _isSelected = !_isSelected),
      onLongPress: widget.isReadOnly ? null : _showImageMenu,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main image container
              AnimatedContainer(
                duration: _isResizing
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: clampedWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _isSelected
                          ? colorScheme.primary.withOpacity(0.2)
                          : colorScheme.shadow.withValues(alpha: isDark ? 0.3 : 0.1),
                      offset: const Offset(0, 4),
                      blurRadius: _isSelected ? 12 : 8,
                    ),
                    if (!isDark)
                      BoxShadow(
                        color: colorScheme.surface.withValues(alpha: 0.8),
                        offset: const Offset(-2, -2),
                        blurRadius: 6,
                      ),
                  ],
                  border: _isSelected
                      ? Border.all(
                          color: colorScheme.primary.withOpacity(0.4),
                          width: 1.5,
                        )
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.imagePath),
                    width: clampedWidth,
                    fit: BoxFit.fitWidth,
                    errorBuilder: (_, __, ___) => Container(
                      width: clampedWidth,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 32,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Image not found',
                            style: AppTypography.caption(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Corner handles (visible when selected)
              if (_isSelected && !widget.isReadOnly) ...[
                // Top-left handle
                _buildCornerHandle(
                  top: -5,
                  left: -5,
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                // Top-right handle
                _buildCornerHandle(
                  top: -5,
                  right: -5,
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                // Bottom-left handle
                _buildCornerHandle(
                  bottom: -5,
                  left: -5,
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
                // Bottom-right resize handle
                Positioned(
                  bottom: -5,
                  right: -5,
                  child: GestureDetector(
                    onPanStart: (details) {
                      _startWidth = _currentWidth;
                      _startPosition = details.globalPosition;
                      setState(() => _isResizing = true);
                    },
                    onPanUpdate: (details) {
                      if (_isResizing) {
                        final dx =
                            details.globalPosition.dx - _startPosition.dx;
                        final newWidth =
                            (_startWidth + dx).clamp(100.0, _maxWidth);
                        setState(() => _currentWidth = newWidth);
                      }
                    },
                    onPanEnd: (_) {
                      setState(() => _isResizing = false);
                      widget.onResize?.call(_currentWidth);
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? colorScheme.surface
                              : colorScheme.surface,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        size: 10,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
                // Delete button (top-right, offset)
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? colorScheme.surface
                              : colorScheme.surface,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: colorScheme.onError,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerHandle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }

  void _showImageMenu() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.fullscreen_rounded,
                    color: colorScheme.primary),
                title: Text('View Full Size', style: AppTypography.body(context)),
                onTap: () {
                  Navigator.pop(context);
                  _showFullImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: colorScheme.error),
                title: Text(
                  'Delete Image',
                  style: AppTypography.error(context),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete?.call();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage() {
    final colorScheme = Theme.of(context).colorScheme;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: colorScheme.onSurface,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(imagePath: widget.imagePath);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

/// Full screen image viewer with zoom
class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;

  const FullScreenImageViewer({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Image with interactive viewer for zoom
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: colorScheme.onPrimary),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
