import 'dart:math' as math;

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

class _WaterIntakeCardState extends State<WaterIntakeCard>
    with SingleTickerProviderStateMixin {
  WaterIntakeEntry? _entry;
  bool _saving = false;
  bool _showSplash = false;
  double _countScale = 1.0;
  int _animToken = 0;
  AnimationController? _waveController;

  @override
  void initState() {
    super.initState();
    _ensureWaveController();
    _load();
  }

  void _ensureWaveController() {
    _waveController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entry = await WaterIntakeStorageService.loadToday();
    if (mounted) setState(() => _entry = entry);
  }

  Future<void> _add(int delta) async {
    if (_saving) return;
    setState(() => _saving = true);
    final updated = await WaterIntakeStorageService.addGlass(delta);
    if (!mounted) return;
    setState(() {
      _entry = updated;
      _saving = false;
      _showSplash = true;
      _countScale = 1.08;
      _animToken++;
    });
    final token = _animToken;
    Future.delayed(const Duration(milliseconds: 360), () {
      if (!mounted || token != _animToken) return;
      setState(() => _countScale = 1.0);
    });
    Future.delayed(const Duration(milliseconds: 760), () {
      if (!mounted || token != _animToken) return;
      setState(() => _showSplash = false);
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
    _ensureWaveController();
    final cs = Theme.of(context).colorScheme;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final entry = _entry;
    final glasses = entry?.glasses ?? 0;
    final goal = entry?.goal ?? 8;
    final progress = goal > 0 ? (glasses / goal).clamp(0.0, 1.0) : 0.0;
    final isDone = glasses >= goal;

    final accentColor = isDarkTheme
        ? const Color(0xFF29B6F6)
        : const Color(0xFF039BE5);
    final accentDark = isDarkTheme
        ? const Color(0xFF0288D1)
        : const Color(0xFF01579B);

    return GlassCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Background fill animation based on water progress.
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progress),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOutCubic,
                  builder: (context, animatedProgress, child) {
                    return FractionallySizedBox(
                      heightFactor: animatedProgress,
                      widthFactor: 1,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedBuilder(
                        animation: _waveController!,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _WaterWavePainter(
                              phase: _waveController!.value,
                              topColor: accentColor.withValues(
                                alpha: isDarkTheme ? 0.16 : 0.28,
                              ),
                              deepColor: accentColor.withValues(
                                alpha: isDarkTheme ? 0.28 : 0.48,
                              ),
                              crestColor: accentDark.withValues(
                                alpha: isDarkTheme ? 0.18 : 0.24,
                              ),
                            ),
                            child: const SizedBox.expand(),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 420),
                opacity: _showSplash ? 1.0 : 0.0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Icon(
                      Icons.water_drop_rounded,
                      size: 14,
                      color: accentColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
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
                      AnimatedScale(
                        scale: _countScale,
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeInOutCubic,
                        child: Text(
                          '$glasses',
                          style: AppTypography.heading3(context).copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: isDone ? accentDark : cs.onSurface,
                            height: 1,
                          ),
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
                ],
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
          ],
        ),
      ),
    );
  }
}

class _WaterWavePainter extends CustomPainter {
  final double phase;
  final Color topColor;
  final Color deepColor;
  final Color crestColor;

  const _WaterWavePainter({
    required this.phase,
    required this.topColor,
    required this.deepColor,
    required this.crestColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, deepColor],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final waveY = size.height * 0.18;
    final amplitude = math.max(2.0, size.height * 0.045);
    final waveLength = math.max(40.0, size.width * 0.5);
    // One smooth horizontal cycle per controller loop.
    final shift = phase * 2 * math.pi;

    final path = Path()..moveTo(0, waveY);
    for (double x = 0; x <= size.width; x += 2) {
      final y = waveY + amplitude * math.sin((x / waveLength) * 2 * math.pi + shift);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    final wavePaint = Paint()..color = crestColor;
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _WaterWavePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.topColor != topColor ||
        oldDelegate.deepColor != deepColor ||
        oldDelegate.crestColor != crestColor;
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
