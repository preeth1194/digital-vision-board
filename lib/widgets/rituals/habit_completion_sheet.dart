import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit_item.dart';
import '../../services/coins_service.dart';

/// Result from the habit completion sheet.
class HabitCompletionResult {
  final CompletionType completionType;
  final int coinsEarned;

  const HabitCompletionResult({
    required this.completionType,
    required this.coinsEarned,
  });
}

/// Shows a bottom sheet for completing a habit with choice between
/// coping plan completion and actual habit completion.
Future<HabitCompletionResult?> showHabitCompletionSheet(
  BuildContext context, {
  required HabitItem habit,
}) {
  return showModalBottomSheet<HabitCompletionResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HabitCompletionSheet(habit: habit),
  );
}

class _HabitCompletionSheet extends StatefulWidget {
  final HabitItem habit;

  const _HabitCompletionSheet({required this.habit});

  @override
  State<_HabitCompletionSheet> createState() => _HabitCompletionSheetState();
}

class _HabitCompletionSheetState extends State<_HabitCompletionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  CompletionType? _selectedType;

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
    super.dispose();
  }

  void _selectType(CompletionType type) {
    HapticFeedback.selectionClick();
    setState(() => _selectedType = type);
  }

  void _confirm() {
    if (_selectedType == null) return;
    HapticFeedback.mediumImpact();
    
    final coins = CoinsService.getCoinsForCompletionType(_selectedType!);
    Navigator.of(context).pop(HabitCompletionResult(
      completionType: _selectedType!,
      coinsEarned: coins,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

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
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Mark as Complete',
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
              // Completion type options
              Row(
                children: [
                  Expanded(
                    child: _CompletionOption(
                      type: CompletionType.copingPlan,
                      isSelected: _selectedType == CompletionType.copingPlan,
                      onTap: () => _selectType(CompletionType.copingPlan),
                      icon: Icons.psychology_outlined,
                      title: 'Coping Plan',
                      subtitle: 'Used strategy\nwithout full habit',
                      coins: CoinsService.copingPlanCoins,
                      gradientColors: const [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CompletionOption(
                      type: CompletionType.habit,
                      isSelected: _selectedType == CompletionType.habit,
                      onTap: () => _selectType(CompletionType.habit),
                      icon: Icons.check_circle_outline,
                      title: 'Full Habit',
                      subtitle: 'Completed the\nentire habit',
                      coins: CoinsService.habitCompletionCoins,
                      gradientColors: const [Color(0xFF11998e), Color(0xFF38ef7d)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Confirm button
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _selectedType != null ? 1.0 : 0.5,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _selectedType != null ? _confirm : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Complete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_selectedType != null) ...[
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
                                const Icon(
                                  Icons.monetization_on,
                                  size: 16,
                                  color: Color(0xFFFFD700),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+${CoinsService.getCoinsForCompletionType(_selectedType!)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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

class _CompletionOption extends StatefulWidget {
  final CompletionType type;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final int coins;
  final List<Color> gradientColors;

  const _CompletionOption({
    required this.type,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.coins,
    required this.gradientColors,
  });

  @override
  State<_CompletionOption> createState() => _CompletionOptionState();
}

class _CompletionOptionState extends State<_CompletionOption>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(_CompletionOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0);
    }
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
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final bounce = Curves.elasticOut.transform(_controller.value);
          return Transform.scale(
            scale: 0.95 + (bounce * 0.05),
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isSelected ? null : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.transparent
                  : colorScheme.outlineVariant,
              width: 2,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.gradientColors[0].withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  widget.icon,
                  size: 32,
                  color: widget.isSelected
                      ? Colors.white
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.isSelected
                      ? Colors.white
                      : colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // Subtitle
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Coins badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on,
                      size: 16,
                      color: widget.isSelected
                          ? Colors.white
                          : const Color(0xFFFFAB00),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${widget.coins}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: widget.isSelected
                            ? Colors.white
                            : const Color(0xFFFFAB00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
