import 'package:flutter/material.dart';

import '../../models/mood_entry.dart';
import '../../utils/app_typography.dart';
import '../../screens/mood_detail_screen.dart';
import '../../services/mood_storage_service.dart';
import 'glass_card.dart';

class MoodTrackerCard extends StatefulWidget {
  const MoodTrackerCard({super.key});

  @override
  State<MoodTrackerCard> createState() => _MoodTrackerCardState();
}

class _MoodTrackerCardState extends State<MoodTrackerCard> {
  int? _todayMood;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
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

  void _openMoodDetail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MoodDetailScreen()),
    );
    _load();
  }

  void _onCardTap() {
    _openMoodDetail();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
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
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mood',
                    style: AppTypography.heading3(context).copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
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
                      colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                ),
              )
            else if (_todayMood != null) ...[
              Image.asset(
                assetForMood(_todayMood!),
                width: 52,
                height: 52,
              ),
              const SizedBox(height: 8),
              Text(
                labelForMood(_todayMood!),
                style: AppTypography.heading3(context).copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                "Today's mood",
                style: AppTypography.caption(context).copyWith(
                  color: colorScheme.onPrimaryContainer
                      .withValues(alpha: 0.7),
                ),
              ),
            ] else ...[
              Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/moods/okay.png',
                  width: 52,
                  height: 52,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to check in',
                style: AppTypography.bodySmall(context).copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
