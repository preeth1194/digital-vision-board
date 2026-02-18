import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';

// --- ADDON TOOLS SECTION ---
class AddonToolsSection extends StatelessWidget {
  final Color habitColor;
  final bool remindersAdded;
  final ValueChanged<bool> onRemindersToggle;
  final bool timerAdded;
  final ValueChanged<bool> onTimerToggle;
  final bool playSongsAdded;
  final ValueChanged<bool> onPlaySongsToggle;
  final int durationMinutes;
  /// Called when user taps to configure Play Songs. Receives sheet context to pop it first.
  final void Function(BuildContext sheetContext)? onConfigurePlaySongs;

  const AddonToolsSection({
    super.key,
    required this.habitColor,
    required this.remindersAdded,
    required this.onRemindersToggle,
    required this.timerAdded,
    required this.onTimerToggle,
    required this.playSongsAdded,
    required this.onPlaySongsToggle,
    required this.durationMinutes,
    this.onConfigurePlaySongs,
  });

  int get _activeCount =>
      (remindersAdded ? 1 : 0) + (timerAdded ? 1 : 0) + (playSongsAdded ? 1 : 0);

  void _showAddonSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        var localReminders = remindersAdded;
        var localTimer = timerAdded;
        var localPlaySongs = playSongsAdded;
        final canEnablePlaySongs = timerAdded && durationMinutes > 10;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Addon Tools',
                          style: AppTypography.body(context).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AddonToggleRow(
                      icon: Icons.notifications_outlined,
                      activeIcon: Icons.notifications_active_rounded,
                      title: 'Reminders',
                      subtitle: 'Location triggers',
                      isActive: localReminders,
                      accentColor: habitColor,
                      onChanged: (v) {
                        setSheetState(() => localReminders = v);
                        onRemindersToggle(v);
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    _AddonToggleRow(
                      icon: Icons.timer_outlined,
                      activeIcon: Icons.timer_rounded,
                      title: 'Timer',
                      subtitle: 'Start time & duration',
                      isActive: localTimer,
                      accentColor: habitColor,
                      onChanged: (v) {
                        setSheetState(() => localTimer = v);
                        onTimerToggle(v);
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    _AddonToggleRow(
                      icon: Icons.music_note_outlined,
                      activeIcon: Icons.music_note_rounded,
                      title: 'Play Songs',
                      subtitle: 'Playlist or number of songs',
                      isActive: localPlaySongs,
                      accentColor: habitColor,
                      onChanged: (v) {
                        if (v && !canEnablePlaySongs) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Play Songs requires Timer to be enabled and duration greater than 10 minutes.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        setSheetState(() => localPlaySongs = v);
                        onPlaySongsToggle(v);
                      },
                      onRowTap: localPlaySongs && onConfigurePlaySongs != null
                          ? () => onConfigurePlaySongs!(ctx)
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = _activeCount;
    final subtitleText = count == 0
        ? 'None active'
        : '$count active';

    return CupertinoListSection.insetGrouped(
      header: Text(
        'Addon Tools',
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: habitSectionDecoration(colorScheme),
      separatorColor: habitSectionSeparatorColor(colorScheme),
      children: [
        CupertinoListTile.notched(
          leading: Icon(
            Icons.build_outlined,
            color: count > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 24,
          ),
          title: Text(
            subtitleText,
            style: AppTypography.body(context),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            size: 20,
          ),
          onTap: () => _showAddonSheet(context),
        ),
      ],
    );
  }
}

class _AddonToggleRow extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final String subtitle;
  final bool isActive;
  final Color accentColor;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onRowTap;

  const _AddonToggleRow({
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.accentColor,
    required this.onChanged,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final labelPart = Row(
      children: [
        Icon(
          isActive ? activeIcon : icon,
          size: 24,
          color: isActive ? accentColor : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.body(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption(context).copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: onRowTap != null
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onRowTap,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: labelPart,
                      ),
                    ),
                  )
                : labelPart,
          ),
          CupertinoSwitch(
            value: isActive,
            activeTrackColor: accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
