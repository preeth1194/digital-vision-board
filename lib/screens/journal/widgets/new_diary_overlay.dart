import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'editor_spacing.dart';
import 'journal_browse.dart';

// ---------------------------------------------------------------------------
// Result model — returned when the user chooses an action on the overlay.
// ---------------------------------------------------------------------------

enum NewDiaryAction { write, voice }

class NewDiaryResult {
  final String title;
  final Set<String> tags;
  final NewDiaryAction action;

  const NewDiaryResult({
    required this.title,
    required this.tags,
    required this.action,
  });
}

// ---------------------------------------------------------------------------
// NewDiaryOverlay — paper-style creation screen with title, tags & actions.
// ---------------------------------------------------------------------------

class NewDiaryOverlay extends StatefulWidget {
  final List<String> existingTags;

  const NewDiaryOverlay({super.key, required this.existingTags});

  @override
  State<NewDiaryOverlay> createState() => _NewDiaryOverlayState();
}

class _NewDiaryOverlayState extends State<NewDiaryOverlay>
    with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final Set<String> _selectedTags = {};

  // Entrance animations
  late final AnimationController _entranceController;
  late final Animation<double> _paperSlide;
  late final Animation<double> _paperFade;
  late final Animation<double> _contentFade;

  // Decorative line painting animation
  late final AnimationController _linesController;
  late final Animation<double> _linesProgress;

  @override
  void initState() {
    super.initState();

    // Paper entrance
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _paperSlide = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _paperFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );

    // Decorative lines drawing in
    _linesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _linesProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _linesController, curve: Curves.easeOutCubic),
    );

    // Start animations
    _entranceController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _linesController.forward();
    });

    // Auto-focus the title field after the entrance animation settles
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.dispose();
    _entranceController.dispose();
    _linesController.dispose();
    super.dispose();
  }

  void _submit(NewDiaryAction action) {
    Navigator.of(context).pop(
      NewDiaryResult(
        title: _titleController.text.trim(),
        tags: Set<String>.from(_selectedTags),
        action: action,
      ),
    );
  }

  void _showAddTagDialog() {
    final tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'New tag',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: tagController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tag name'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) {
            final t = tagController.text.trim();
            if (t.isNotEmpty) {
              setState(() => _selectedTags.add(t));
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final t = tagController.text.trim();
              if (t.isNotEmpty) {
                setState(() => _selectedTags.add(t));
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ---- Formatting helpers ----

  String _formatDate(DateTime dt) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final paperColor = isDark
        ? colorScheme.surfaceContainerHigh
        : const Color(0xFFFFFDF7); // warm ivory
    final lineColor = isDark
        ? colorScheme.outlineVariant.withOpacity(0.15)
        : const Color(0xFFD6CFC3).withOpacity(0.45);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _entranceController,
        builder: (context, child) {
          return Stack(
            children: [
              // Semi-transparent scrim
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  color: Colors.black.withOpacity(0.35 * _paperFade.value),
                ),
              ),
              // Paper card
              Positioned.fill(
                top: topPadding + 12,
                left: 16,
                right: 16,
                bottom: bottomPadding + 12,
                child: Transform.translate(
                  offset: Offset(0, _paperSlide.value),
                  child: Opacity(
                    opacity: _paperFade.value,
                    child: _buildPaperCard(
                      context,
                      paperColor: paperColor,
                      lineColor: lineColor,
                      isDark: isDark,
                      colorScheme: colorScheme,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaperCard(
    BuildContext context, {
    required Color paperColor,
    required Color lineColor,
    required bool isDark,
    required ColorScheme colorScheme,
  }) {
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(EditorSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EditorSpacing.cardRadius),
        child: Stack(
          children: [
            // Animated ruled lines
            AnimatedBuilder(
              animation: _linesProgress,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _OverlayLinesPainter(
                  lineColor: lineColor,
                  progress: _linesProgress.value,
                ),
              ),
            ),

            // Red margin line (like a notebook)
            Positioned(
              left: 48,
              top: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _linesProgress,
                builder: (context, _) {
                  return Opacity(
                    opacity: _linesProgress.value,
                    child: Container(
                      width: 1.2,
                      color: (isDark
                              ? Colors.redAccent.withOpacity(0.25)
                              : Colors.redAccent.withOpacity(0.18)),
                    ),
                  );
                },
              ),
            ),

            // Content
            FadeTransition(
              opacity: _contentFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Close button & date
                    _buildTopRow(context, colorScheme, now),
                    const SizedBox(height: 32),

                    // Title input
                    _buildTitleField(colorScheme, isDark),
                    const SizedBox(height: 28),

                    // Tags section
                    _buildTagsSection(colorScheme, isDark),

                    const Spacer(),

                    // Action buttons
                    _buildActionButtons(colorScheme, isDark),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(
    BuildContext context,
    ColorScheme colorScheme,
    DateTime now,
  ) {
    return Row(
      children: [
        // Close button
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Date
        Expanded(
          child: Text(
            _formatDate(now),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleField(ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Entry',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary.withOpacity(0.7),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          focusNode: _titleFocus,
          style: GoogleFonts.merriweather(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            height: 1.35,
          ),
          decoration: InputDecoration(
            hintText: "What's on your mind?",
            hintStyle: GoogleFonts.merriweather(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withOpacity(0.2),
              height: 1.35,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildTagsSection(ColorScheme colorScheme, bool isDark) {
    // Combine existing tags + any newly added tags (not yet in existingTags)
    final allAvailable = <String>{
      ...widget.existingTags,
      ..._selectedTags,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withOpacity(0.45),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in allAvailable)
              NeumorphicFilterChip(
                label: tag,
                selected: _selectedTags.contains(tag),
                onSelected: () {
                  setState(() {
                    if (_selectedTags.contains(tag)) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
              ),
            // Add-tag button
            GestureDetector(
              onTap: _showAddTagDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add tag',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme, bool isDark) {
    return Column(
      children: [
        // Start Writing — primary action
        SizedBox(
          width: double.infinity,
          height: 52,
          child: _ActionButton(
            label: 'Start Writing',
            icon: Icons.edit_rounded,
            isPrimary: true,
            colorScheme: colorScheme,
            isDark: isDark,
            onTap: () => _submit(NewDiaryAction.write),
          ),
        ),
        const SizedBox(height: 12),
        // Record Voice — secondary action
        SizedBox(
          width: double.infinity,
          height: 52,
          child: _ActionButton(
            label: 'Record Voice',
            icon: Icons.mic_rounded,
            isPrimary: false,
            colorScheme: colorScheme,
            isDark: isDark,
            onTap: () => _submit(NewDiaryAction.voice),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action button with press animation
// ---------------------------------------------------------------------------

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.colorScheme,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final bg = widget.isPrimary
        ? cs.primary
        : (widget.isDark
            ? cs.surfaceContainerHighest
            : Colors.white);
    final fg = widget.isPrimary
        ? cs.onPrimary
        : cs.onSurface;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.isPrimary
                ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 20, color: fg),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom painter — ruled lines that draw-in with animation
// ---------------------------------------------------------------------------

class _OverlayLinesPainter extends CustomPainter {
  final Color lineColor;
  final double progress; // 0..1

  _OverlayLinesPainter({required this.lineColor, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = lineColor.withOpacity(lineColor.opacity * progress)
      ..strokeWidth = 0.5;

    const spacing = EditorSpacing.lineHeight;
    const marginTop = 100.0;
    const marginH = 24.0;

    final maxWidth = (size.width - marginH * 2) * progress;

    for (double y = marginTop; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(marginH, y),
        Offset(marginH + maxWidth, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayLinesPainter old) =>
      lineColor != old.lineColor || progress != old.progress;
}
