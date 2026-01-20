import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../services/rhythmic_timer_state_service.dart' show RhythmicTimerState, RhythmicTimerStateService;
import '../services/logical_date_service.dart';

/// Compact widget displaying rhythmic timer state (for embedding in habit tracker).
class RhythmicTimerWidget extends StatelessWidget {
  final HabitItem habit;
  final SharedPreferences prefs;

  const RhythmicTimerWidget({
    super.key,
    required this.habit,
    required this.prefs,
  });

  bool get _isSongBased => habit.timeBound?.isSongBased ?? false;

  @override
  Widget build(BuildContext context) {
    if (!_isSongBased) {
      // Time-based mode is handled by existing timer UI
      return const SizedBox.shrink();
    }

    return FutureBuilder<RhythmicTimerState>(
      future: RhythmicTimerStateService.getState(
        prefs: prefs,
        habitId: habit.id,
        logicalDate: LogicalDateService.today(),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final state = snapshot.data!;
        if (state.totalSongs == 0) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${state.songsRemaining} / ${state.totalSongs} songs remaining',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                if (state.currentSongTitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Now: ${state.currentSongTitle}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: state.totalSongs > 0
                      ? 1.0 - (state.songsRemaining / state.totalSongs)
                      : 0.0,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
