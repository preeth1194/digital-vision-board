import 'package:flutter/material.dart';

import '../../screens/mood_detail_screen.dart';
import '../../services/mood_storage_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

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

  Future<void> _openMoodDetail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MoodDetailScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // Pill label — hidden during loading
    final String? pillLabel = !_loaded
        ? null
        : (_todayMood != null ? 'Edit →' : 'Log →');

    // Mood asset widget
    final Widget moodAsset = !_loaded
        ? const SizedBox(width: 52, height: 52)
        : _todayMood != null
            ? Image.asset(assetForMood(_todayMood!), width: 52, height: 52)
            : Image.asset(
                'assets/moods/okay.png',
                width: 52,
                height: 52,
                opacity: const AlwaysStoppedAnimation(0.5),
              );

    // Body text
    final String bodyText = !_loaded
        ? 'Loading...'
        : (_todayMood != null
            ? labelForMood(_todayMood!)
            : 'How are you feeling today?');

    return Material(
      color: Colors.transparent, // Flutter layout idiom — not a design color token
      child: InkWell(
        onTap: _openMoodDetail,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.lavenderContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                moodAsset,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mood',
                        style: AppTypography.caption(context).copyWith(
                          color: AppColors.lavenderDew,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        bodyText,
                        style: AppTypography.body(context)
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (pillLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderDew.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
                    ),
                    child: Text(
                      pillLabel,
                      style: AppTypography.caption(context).copyWith(
                        color: AppColors.lavenderDew,
                        fontWeight: FontWeight.w700,
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
