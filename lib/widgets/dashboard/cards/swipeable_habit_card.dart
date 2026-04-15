import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/logical_date_service.dart';
import '../habits_tab_models.dart';
import 'coping_plan_face.dart';

/// Tracks which gesture the user initiated during a drag.
enum DragMode { reveal, flip }

/// Swipeable wrapper for habit cards:
/// - Swipe left from main face → reveal edit & delete action icons
/// - Swipe right from main face → 3D card-flip to coping plan
/// - Swipe left from coping plan face → flip back to main
class SwipeableHabitCard extends StatefulWidget {
  final HabitEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  const SwipeableHabitCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });

  @override
  State<SwipeableHabitCard> createState() => SwipeableHabitCardState();
}

class SwipeableHabitCardState extends State<SwipeableHabitCard>
    with TickerProviderStateMixin {
  // --- Reveal (swipe-left) animation ---
  late AnimationController _revealController;
  late Animation<double> _revealAnimation;
  double _dragExtent = 0;
  bool _isRevealOpen = false;

  // --- Flip animation ---
  late AnimationController _flipController;
  bool _isFlipped = false;

  /// Whether the card is currently showing the coping plan (back) face.
  bool get isFlipped => _isFlipped;

  /// Toggle the card flip from outside (e.g. icon tap).
  void toggleFlip() {
    if (_isFlipped) {
      _flipToFront();
    } else {
      _flipToBack();
    }
  }

  // --- Gesture routing ---
  DragMode? _dragMode;

  static const double _revealWidth = 120.0;
  static const double _snapThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _revealAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic),
    );
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  // ---- Reveal helpers ----

  void _animateRevealTo(double target) {
    _revealAnimation = Tween<double>(begin: _dragExtent, end: target).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic),
    );
    _revealController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragExtent = target;
          _isRevealOpen = target != 0;
        });
      }
    });
  }

  void _closeReveal() {
    if (_dragExtent != 0) _animateRevealTo(0);
  }

  // ---- Flip helpers ----

  void _flipToBack() {
    HapticFeedback.selectionClick();
    _flipController.forward().then((_) {
      if (mounted) setState(() => _isFlipped = true);
    });
  }

  void _flipToFront() {
    HapticFeedback.selectionClick();
    _flipController.reverse().then((_) {
      if (mounted) setState(() => _isFlipped = false);
    });
  }

  // ---- Unified drag handling ----

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final dx = details.delta.dx;

    if (_dragMode == null) {
      if (_isFlipped) {
        if (dx < 0) _dragMode = DragMode.flip;
      } else if (_isRevealOpen) {
        _dragMode = DragMode.reveal;
      } else {
        if (dx > 0) {
          _dragMode = DragMode.flip;
        } else if (dx < 0) {
          _dragMode = DragMode.reveal;
        }
      }
    }

    if (_dragMode == DragMode.reveal && !_isFlipped) {
      setState(() {
        _dragExtent += dx;
        _dragExtent = _dragExtent.clamp(-_revealWidth, 0);
      });
    } else if (_dragMode == DragMode.flip) {
      final flipDelta = dx / 200.0;
      final newVal = (_flipController.value + flipDelta).clamp(0.0, 1.0);
      _flipController.value = newVal;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (_dragMode == DragMode.reveal && !_isFlipped) {
      if (velocity < -300 || _dragExtent.abs() > _snapThreshold) {
        _animateRevealTo(-_revealWidth);
      } else {
        _animateRevealTo(0);
      }
    } else if (_dragMode == DragMode.flip) {
      if (_isFlipped) {
        if (velocity < -300 || _flipController.value < 0.5) {
          _flipToFront();
        } else {
          _flipToBack();
        }
      } else {
        if (velocity > 300 || _flipController.value > 0.5) {
          _flipToBack();
        } else {
          _flipToFront();
        }
      }
    }

    _dragMode = null;
  }

  void _onEditTap() {
    HapticFeedback.mediumImpact();
    _closeReveal();
    widget.onEdit();
  }

  void _onDeleteTap() {
    HapticFeedback.mediumImpact();
    _closeReveal();
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_revealController, _flipController]),
      builder: (context, _) {
        final revealOffset = _revealController.isAnimating
            ? _revealAnimation.value
            : _dragExtent;
        final revealProgress = (revealOffset.abs() / _revealWidth).clamp(
          0.0,
          1.0,
        );
        final flipValue = _flipController.value;
        final showBack = flipValue >= 0.5;

        // 3D Y-axis rotation
        final angle = flipValue * pi;
        final flipTransform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle);

        // Mirror-correct the back face so text isn't reversed
        if (showBack) {
          flipTransform.rotateY(pi);
        }

        return Stack(
          children: [
            // Action buttons revealed on the right (only visible on front face)
            if (!showBack)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Spacer(),
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 100),
                          opacity: revealProgress.clamp(0.0, 1.0),
                          child: SizedBox(
                            width: _revealWidth,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Edit button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _onEditTap,
                                    child: Container(
                                      color: isDark
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.primary.withValues(
                                              alpha: 0.85,
                                            ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.edit_outlined,
                                        color: colorScheme.onPrimary,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                // Delete button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _onDeleteTap,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: colorScheme.error,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(24),
                                          bottomRight: Radius.circular(24),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: colorScheme.onPrimary,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Flippable card with optional reveal translate
            GestureDetector(
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              onTap: _isRevealOpen
                  ? _closeReveal
                  : (_isFlipped ? _flipToFront : null),
              child: Transform.translate(
                offset: Offset(showBack ? 0 : revealOffset, 0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: flipTransform,
                  child: showBack
                      ? CopingPlanFace(
                          habit: widget.entry.habit,
                          isCompleted: widget.entry.habit
                              .isCompletedForCurrentPeriod(
                                LogicalDateService.now(),
                              ),
                        )
                      : widget.child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
