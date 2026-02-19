import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/affirmation.dart';

/// A flippable card widget that displays affirmations
class AffirmationCard extends StatefulWidget {
  final Affirmation? frontAffirmation;
  final Affirmation? backAffirmation;
  final VoidCallback? onFlip;
  final VoidCallback? onSettings;
  final Color? cardColor;
  final bool showPinIndicator;
  final bool showCategory;

  const AffirmationCard({
    super.key,
    this.frontAffirmation,
    this.backAffirmation,
    this.onFlip,
    this.onSettings,
    this.cardColor,
    this.showPinIndicator = true,
    this.showCategory = true,
  });

  @override
  State<AffirmationCard> createState() => _AffirmationCardState();
}

class _AffirmationCardState extends State<AffirmationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_controller.isAnimating) return;
    
    // Set up listener before starting animation
    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _controller.removeStatusListener(statusListener);
        widget.onFlip?.call();
      }
    }
    _controller.addStatusListener(statusListener);
    
    if (_isFlipped) {
      _controller.reverse();
      _isFlipped = false;
    } else {
      _controller.forward();
      _isFlipped = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardColor = widget.cardColor ?? colorScheme.surfaceContainerHighest;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * math.pi;
          final isFrontVisible = angle < math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFrontVisible
                ? _buildCardSide(
                    widget.frontAffirmation,
                    cardColor,
                    colorScheme,
                    theme,
                    isFront: true,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildCardSide(
                      widget.backAffirmation ?? widget.frontAffirmation,
                      cardColor,
                      colorScheme,
                      theme,
                      isFront: false,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardSide(
    Affirmation? affirmation,
    Color cardColor,
    ColorScheme colorScheme,
    ThemeData theme, {
    required bool isFront,
  }) {
    if (affirmation == null) {
      return _buildEmptyCard(cardColor, colorScheme, theme);
    }

    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.showPinIndicator && affirmation.isPinned) ...[
                        Align(
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.push_pin,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Expanded(
                        child: Center(
                          child: Text(
                            affirmation.text,
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                      if (widget.showCategory && affirmation.category != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            affirmation.category!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Tap to flip',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onSettings != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: widget.onSettings,
                      child: Icon(
                        Icons.settings,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(Color cardColor, ColorScheme colorScheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No affirmations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first affirmation to get started',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
