import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../screens/subscription_screen.dart';
import '../../utils/app_typography.dart';
import 'habit_form_constants.dart';

// --- ADDON TOOLS SECTION ---
class AddonToolsSection extends StatelessWidget {
  final Color habitColor;
  final bool remindersAdded;
  final ValueChanged<bool> onRemindersToggle;
  final bool timerAdded;
  final ValueChanged<bool> onTimerToggle;
  final bool trackerAdded;
  final ValueChanged<bool> onTrackerToggle;
  final bool isSubscribed;
  /// Whether the currently selected icon supports tracking units.
  final bool trackerAvailable;

  const AddonToolsSection({
    super.key,
    required this.habitColor,
    required this.remindersAdded,
    required this.onRemindersToggle,
    required this.timerAdded,
    required this.onTimerToggle,
    required this.trackerAdded,
    required this.onTrackerToggle,
    required this.isSubscribed,
    this.trackerAvailable = false,
  });

  int get _activeCount =>
      (remindersAdded ? 1 : 0) +
      (timerAdded ? 1 : 0) +
      (trackerAdded ? 1 : 0);

  void _showAddonSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        var localReminders = remindersAdded;
        var localTimer = timerAdded;
        var localTracker = trackerAdded;
        final sheetIsDark = colorScheme.brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
              decoration: BoxDecoration(
                color: sheetIsDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: sheetIsDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.8),
                  ),
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
                      icon: Icons.straighten_outlined,
                      activeIcon: Icons.straighten,
                      title: 'Tracker',
                      subtitle: trackerAvailable
                          ? 'Log measurements per completion'
                          : 'Select a trackable icon first',
                      isActive: localTracker,
                      accentColor: habitColor,
                      locked: !isSubscribed,
                      enabled: trackerAvailable,
                      onChanged: (v) {
                        if (!isSubscribed) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SubscriptionScreen(),
                            ),
                          );
                          return;
                        }
                        setSheetState(() => localTracker = v);
                        onTrackerToggle(v);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
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
      backgroundColor: Colors.transparent,
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
  /// Show a lock badge for non-subscribers.
  final bool locked;
  /// Whether the toggle is enabled (greyed out when icon has no tracking units).
  final bool enabled;

  const _AddonToggleRow({
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.accentColor,
    required this.onChanged,
    this.onRowTap,
    this.locked = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveAlpha = enabled ? 1.0 : 0.4;

    final labelPart = Opacity(
      opacity: effectiveAlpha,
      child: Row(
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
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTypography.body(context).copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 10,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Premium',
                              style: AppTypography.caption(context).copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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
      ),
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
          if (locked)
            GestureDetector(
              onTap: () => onChanged(true),
              child: Icon(
                Icons.lock_outline,
                size: 22,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            )
          else
            CupertinoSwitch(
              value: isActive,
              activeTrackColor: accentColor,
              onChanged: enabled ? onChanged : null,
            ),
        ],
      ),
    );
  }
}
