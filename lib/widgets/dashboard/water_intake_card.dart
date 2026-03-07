import 'package:flutter/material.dart';

import '../../models/water_intake_entry.dart';
import '../../services/water_intake_storage_service.dart';
import '../../utils/app_typography.dart';
import 'glass_card.dart';

/// Dashboard card for tracking daily water intake.
///
/// Shows today's glass count vs. goal with + / - controls. Users can also
/// long-press the goal text to edit their daily target.
class WaterIntakeCard extends StatefulWidget {
  const WaterIntakeCard({super.key});

  @override
  State<WaterIntakeCard> createState() => _WaterIntakeCardState();
}

class _WaterIntakeCardState extends State<WaterIntakeCard> {
  WaterIntakeEntry? _entry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = await WaterIntakeStorageService.loadToday();
    if (mounted) setState(() => _entry = entry);
  }

  Future<void> _add(int delta) async {
    if (_saving) return;
    setState(() => _saving = true);
    final updated = await WaterIntakeStorageService.addGlass(delta);
    if (mounted) setState(() {
      _entry = updated;
      _saving = false;
    });
  }

  void _showGoalEditor() {
    final current = _entry?.goal ?? 8;
    int tempGoal = current;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Daily Water Goal'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: tempGoal > 1
                    ? () => setLocal(() => tempGoal--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$tempGoal glasses',
                  style: Theme.of(ctx).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: tempGoal < 30
                    ? () => setLocal(() => tempGoal++)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = await WaterIntakeStorageService.updateGoal(tempGoal);
                if (mounted) setState(() => _entry = updated);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entry = _entry;
    final glasses = entry?.glasses ?? 0;
    final goal = entry?.goal ?? 8;
    final progress = goal > 0 ? (glasses / goal).clamp(0.0, 1.0) : 0.0;
    final isDone = glasses >= goal;

    // Blue/teal accent regardless of theme
    const accentColor = Color(0xFF29B6F6); // light-blue-400
    const accentDark = Color(0xFF0288D1);  // light-blue-700

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
                  Icons.water_drop_rounded,
                  size: 16,
                  color: isDone ? accentDark : accentColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Water',
                    style: AppTypography.heading3(context).copyWith(
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Goal edit chip
                GestureDetector(
                  onTap: _showGoalEditor,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Goal: $goal',
                        style: AppTypography.caption(context).copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.edit_outlined,
                        size: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
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
                        '$glasses',
                        style: AppTypography.heading3(context).copyWith(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: isDone ? accentDark : cs.onSurface,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 4),
                        child: Text(
                          '/ $goal',
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
                    isDone ? 'Goal reached! 💧' : 'glasses today',
                    style: AppTypography.caption(context).copyWith(
                      color: isDone
                          ? accentDark
                          : cs.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Glass dots indicator ─────────────────────────────────────
            _GlassDots(glasses: glasses, goal: goal, accentColor: accentColor),

            const SizedBox(height: 12),

            // ── Progress bar ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: accentColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDone ? accentDark : accentColor,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── +/- controls ─────────────────────────────────────────────
            Row(
              children: [
                // Remove one glass
                Expanded(
                  child: _ControlButton(
                    icon: Icons.remove_rounded,
                    label: '-1',
                    color: cs.onSurfaceVariant,
                    bgColor: cs.surfaceContainerHighest,
                    enabled: !_saving && glasses > 0,
                    onTap: () => _add(-1),
                  ),
                ),
                const SizedBox(width: 8),
                // Add one glass
                Expanded(
                  flex: 2,
                  child: _ControlButton(
                    icon: Icons.add_rounded,
                    label: '+1 glass',
                    color: Colors.white,
                    bgColor: isDone ? accentDark : accentColor,
                    enabled: !_saving && glasses < goal,
                    onTap: () => _add(1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glass dot row (up to 10 visible, then "..." indicator) ────────────────────

class _GlassDots extends StatelessWidget {
  final int glasses;
  final int goal;
  final Color accentColor;

  const _GlassDots({
    required this.glasses,
    required this.goal,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const maxDots = 10;
    final showDots = goal <= maxDots;

    if (!showDots) {
      // Fallback: plain fraction text for large goals
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: List.generate(goal, (i) {
        final filled = i < glasses;
        return Icon(
          filled ? Icons.water_drop_rounded : Icons.water_drop_outlined,
          size: 14,
          color: filled
              ? accentColor
              : cs.onSurfaceVariant.withValues(alpha: 0.25),
        );
      }),
    );
  }
}

// ── Shared control button ─────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final bool enabled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
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
