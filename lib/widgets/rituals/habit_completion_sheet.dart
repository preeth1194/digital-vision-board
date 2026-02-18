import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit_item.dart';
import '../../utils/app_colors.dart';

/// Result from the habit completion sheet.
class HabitCompletionResult {
  final int coinsEarned;
  final int? mood; // 1-5, null if not selected
  final String? note; // null/empty if not written

  const HabitCompletionResult({
    required this.coinsEarned,
    this.mood,
    this.note,
  });
}

/// Shows a bottom sheet for completing a habit with optional mood and log.
Future<HabitCompletionResult?> showHabitCompletionSheet(
  BuildContext context, {
  required HabitItem habit,
  required int coinsEarned,
}) {
  return showModalBottomSheet<HabitCompletionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HabitCompletionSheet(
      habit: habit,
      coinsEarned: coinsEarned,
    ),
  );
}

/// Mood option data.
class _MoodOption {
  final int value;
  final IconData icon;
  final String label;
  final Color color;

  const _MoodOption({
    required this.value,
    required this.icon,
    required this.label,
    required this.color,
  });
}

const _moods = <_MoodOption>[
  _MoodOption(
    value: 1,
    icon: Icons.sentiment_very_dissatisfied_rounded,
    label: 'Awful',
    color: Color(0xFFE57373),
  ),
  _MoodOption(
    value: 2,
    icon: Icons.sentiment_dissatisfied_rounded,
    label: 'Bad',
    color: Color(0xFFFFB74D),
  ),
  _MoodOption(
    value: 3,
    icon: Icons.sentiment_neutral_rounded,
    label: 'Neutral',
    color: Color(0xFFFFD54F),
  ),
  _MoodOption(
    value: 4,
    icon: Icons.sentiment_satisfied_rounded,
    label: 'Good',
    color: Color(0xFF81C784),
  ),
  _MoodOption(
    value: 5,
    icon: Icons.sentiment_very_satisfied_rounded,
    label: 'Great',
    color: Color(0xFF4DB6AC),
  ),
];

class _HabitCompletionSheet extends StatefulWidget {
  final HabitItem habit;
  final int coinsEarned;

  const _HabitCompletionSheet({
    required this.habit,
    required this.coinsEarned,
  });

  @override
  State<_HabitCompletionSheet> createState() => _HabitCompletionSheetState();
}

class _HabitCompletionSheetState extends State<_HabitCompletionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int? _selectedMood;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _selectMood(int mood) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMood = _selectedMood == mood ? null : mood;
    });
  }

  void _confirm() {
    HapticFeedback.mediumImpact();

    final noteText = _noteController.text.trim();
    Navigator.of(context).pop(HabitCompletionResult(
      coinsEarned: widget.coinsEarned,
      mood: _selectedMood,
      note: noteText.isEmpty ? null : noteText,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final keyboardInsets = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_scaleAnimation.value.clamp(0.0, 1.0) * 0.2),
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: _scaleAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInsets),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: EdgeInsets.only(bottom: bottomPadding),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  'How did it feel?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.habit.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Mood row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _moods.map((mood) {
                    final isSelected = _selectedMood == mood.value;
                    return _MoodButton(
                      mood: mood,
                      isSelected: isSelected,
                      onTap: () => _selectMood(mood.value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                // Note text field
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  minLines: 2,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write about how you feel...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Complete button — always enabled
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Complete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                size: 16,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${widget.coinsEarned}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
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
    );
  }
}

/// A single mood emoji button with bounce animation on selection.
class _MoodButton extends StatefulWidget {
  final _MoodOption mood;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodButton({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MoodButton> createState() => _MoodButtonState();
}

class _MoodButtonState extends State<_MoodButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(_MoodButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _bounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _bounceController,
        builder: (context, child) {
          final bounce =
              Curves.elasticOut.transform(_bounceController.value);
          return Transform.scale(
            scale: widget.isSelected ? 0.9 + (bounce * 0.1) : 1.0,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.mood.color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.mood.icon,
                  size: widget.isSelected ? 40 : 34,
                  color: widget.isSelected
                      ? widget.mood.color
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.mood.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isSelected
                      ? widget.mood.color
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
