import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/mood_entry.dart';
import '../../screens/mood_detail_screen.dart';
import '../../services/mood_storage_service.dart';

class MoodTrackerCard extends StatefulWidget {
  const MoodTrackerCard({super.key});

  @override
  State<MoodTrackerCard> createState() => _MoodTrackerCardState();
}

class _MoodTrackerCardState extends State<MoodTrackerCard>
    with SingleTickerProviderStateMixin {
  int? _todayMood;
  bool _loaded = false;

  final _cardKey = GlobalKey();
  OverlayEntry? _pickerOverlay;
  late AnimationController _pickerAnim;

  @override
  void initState() {
    super.initState();
    _pickerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _load();
  }

  @override
  void dispose() {
    _removeOverlay();
    _pickerAnim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final moods = await MoodStorageService.getMoodsForRange(start, end);
    final todayEntry = moods.where((e) => e.dateKey == todayKey).toList();
    if (mounted) {
      setState(() {
        _todayMood = todayEntry.isNotEmpty ? todayEntry.first.value : null;
        _loaded = true;
      });
    }
  }

  Future<void> _onMoodSelected(int value) async {
    final now = DateTime.now();
    final entry = MoodEntry(
      id: 'mood_${now.millisecondsSinceEpoch}',
      date: DateTime(now.year, now.month, now.day),
      value: value,
    );
    await MoodStorageService.saveMood(entry);
    _removeOverlay();
    if (mounted) {
      setState(() => _todayMood = value);
    }
  }

  void _openMoodDetail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MoodDetailScreen()),
    );
    _load();
  }

  void _onCardTap() {
    if (_todayMood != null) {
      _openMoodDetail();
    } else {
      _showPicker();
    }
  }

  // ─── Semi-circle overlay ──────────────────────────────────────────────────

  void _showPicker() {
    if (_pickerOverlay != null) {
      _removeOverlay();
      return;
    }

    final renderBox =
        _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final cardSize = renderBox.size;
    final cardPos = renderBox.localToGlobal(Offset.zero);

    final centerX = cardPos.dx + cardSize.width / 2;
    final anchorY = cardPos.dy;

    _pickerOverlay = OverlayEntry(
      builder: (context) => _SemiCirclePickerOverlay(
        centerX: centerX,
        anchorY: anchorY,
        animation: _pickerAnim,
        onMoodSelected: _onMoodSelected,
        onDismiss: _removeOverlay,
      ),
    );

    Overlay.of(context).insert(_pickerOverlay!);
    _pickerAnim.forward(from: 0);
  }

  void _removeOverlay() {
    _pickerOverlay?.remove();
    _pickerOverlay = null;
    if (_pickerAnim.isAnimating) _pickerAnim.stop();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: _cardKey,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _onCardTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.mood_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mood',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!_loaded)
                SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    backgroundColor:
                        colorScheme.onPrimary.withValues(alpha: 0.3),
                  ),
                )
              else if (_todayMood != null) ...[
                Icon(
                  iconForMood(_todayMood!),
                  size: 52,
                  color: colorForMood(_todayMood!),
                ),
                const SizedBox(height: 8),
                Text(
                  labelForMood(_todayMood!),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  "Today's mood",
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.7),
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.mood_rounded,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
                  size: 52,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to check in',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Semi-circle picker overlay widget ──────────────────────────────────────

class _SemiCirclePickerOverlay extends StatelessWidget {
  final double centerX;
  final double anchorY;
  final Animation<double> animation;
  final ValueChanged<int> onMoodSelected;
  final VoidCallback onDismiss;

  const _SemiCirclePickerOverlay({
    required this.centerX,
    required this.anchorY,
    required this.animation,
    required this.onMoodSelected,
    required this.onDismiss,
  });

  static const _radius = 90.0;
  static const _emojiSize = 44.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        ...List.generate(moodOptions.length, (i) {
          final mood = moodOptions[i];
          // Spread 5 items evenly across the top half arc (pi to 0)
          final angle =
              math.pi - (i * math.pi / (moodOptions.length - 1));
          final dx = centerX + _radius * math.cos(angle) - _emojiSize / 2;
          final dy = anchorY - _radius * math.sin(angle) - _emojiSize / 2 - 8;

          final staggerStart = i * 0.1;
          final staggerEnd = (staggerStart + 0.6).clamp(0.0, 1.0);
          final curved = CurvedAnimation(
            parent: animation,
            curve: Interval(staggerStart, staggerEnd, curve: Curves.elasticOut),
          );

          return Positioned(
            left: dx,
            top: dy,
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, child) {
                final scale = curved.value;
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: scale.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: () => onMoodSelected(mood.value),
                child: Container(
                  width: _emojiSize,
                  height: _emojiSize,
                  decoration: BoxDecoration(
                    color: mood.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: mood.color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    mood.icon,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
