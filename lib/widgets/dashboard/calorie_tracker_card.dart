import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/calorie_entry.dart';
import '../../services/calorie_storage_service.dart';
import '../../utils/app_typography.dart';
import 'glass_card.dart';

/// Dashboard card for tracking daily calorie intake.
///
/// Shows today's calories vs. goal with quick-add presets (+100, +200, +500)
/// and a custom-entry bottom sheet. Users can long-press the goal to edit it.
class CalorieTrackerCard extends StatefulWidget {
  const CalorieTrackerCard({super.key});

  @override
  State<CalorieTrackerCard> createState() => _CalorieTrackerCardState();
}

class _CalorieTrackerCardState extends State<CalorieTrackerCard> {
  CalorieEntry? _entry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = await CalorieStorageService.loadToday();
    if (mounted) setState(() => _entry = entry);
  }

  Future<void> _add(int amount) async {
    if (_saving) return;
    setState(() => _saving = true);
    final updated = await CalorieStorageService.addCalories(amount);
    if (mounted) setState(() {
      _entry = updated;
      _saving = false;
    });
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Today'),
        content: const Text('Clear all calories logged today?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final updated = await CalorieStorageService.resetToday();
      if (mounted) setState(() => _entry = updated);
    }
  }

  void _showCustomEntry() {
    final ctrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: const Color(0xFFFF7043),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add Calories',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Calories (kcal)',
                    hintText: 'e.g. 350',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixText: 'kcal',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final v = int.tryParse(ctrl.text.trim());
                      if (v != null && v > 0) {
                        Navigator.pop(ctx);
                        _add(v);
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGoalEditor() {
    final current = _entry?.goal ?? 2000;
    final ctrl = TextEditingController(text: current.toString());

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily Calorie Goal'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Goal (kcal)',
            suffixText: 'kcal',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v >= 500) {
                Navigator.pop(ctx);
                final updated = await CalorieStorageService.updateGoal(v);
                if (mounted) setState(() => _entry = updated);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entry = _entry;
    final calories = entry?.calories ?? 0;
    final goal = entry?.goal ?? 2000;
    final progress = goal > 0 ? (calories / goal).clamp(0.0, 1.0) : 0.0;
    final isOver = calories > goal;
    final isDone = calories >= goal && !isOver;

    const accent = Color(0xFFFF7043);        // deep-orange-400
    const accentDone = Color(0xFF43A047);    // green-600 (goal met)
    const accentOver = Color(0xFFE53935);    // red-600 (over limit)

    final barColor = isOver ? accentOver : (isDone ? accentDone : accent);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: barColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Calories',
                    style: AppTypography.heading3(context).copyWith(
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Goal chip + reset button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _showGoalEditor,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_formatKcal(goal)} goal',
                            style: AppTypography.caption(context).copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.edit_outlined,
                            size: 11,
                            color:
                                cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                    if (calories > 0) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _reset,
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Count display ────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatKcal(calories),
                        style: AppTypography.heading3(context).copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: barColor,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Text(
                          '/ ${_formatKcal(goal)}',
                          style: AppTypography.caption(context).copyWith(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOver
                        ? '${_formatKcal(calories - goal)} kcal over'
                        : isDone
                            ? 'Goal reached! 🎯'
                            : '${_formatKcal(goal - calories)} kcal remaining',
                    style: AppTypography.caption(context).copyWith(
                      color: isOver
                          ? accentOver
                          : isDone
                              ? accentDone
                              : cs.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Progress bar ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),

            const SizedBox(height: 14),

            // ── Quick-add row ────────────────────────────────────────────
            Row(
              children: [
                for (final amount in [100, 200, 500]) ...[
                  if (amount != 100) const SizedBox(width: 6),
                  Expanded(
                    child: _QuickAddButton(
                      label: '+$amount',
                      bgColor: accent.withValues(alpha: 0.12),
                      textColor: accent,
                      enabled: !_saving,
                      onTap: () => _add(amount),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                // Custom entry button
                _QuickAddButton(
                  label: '+ ✏️',
                  bgColor: cs.surfaceContainerHighest,
                  textColor: cs.onSurfaceVariant,
                  enabled: !_saving,
                  onTap: _showCustomEntry,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatKcal(int v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.truncateToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return '$v';
  }
}

class _QuickAddButton extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final bool enabled;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.4,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
