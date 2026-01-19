import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/goal_metadata.dart';
import '../../models/vision_components.dart';
import '../../utils/component_label_utils.dart';
import '../dialogs/goal_details_dialog.dart';
import '../goal_details_sheet.dart';

class HabitTrackerHeader extends StatelessWidget {
  final VisionComponent component;
  final VoidCallback onClose;
  final ValueChanged<GoalMetadata>? onEditGoalDetails;
  final void Function(String microHabit, String? frequency, List<int> weeklyDays)? onCreateHabitFromActionPlan;

  const HabitTrackerHeader({
    super.key,
    required this.component,
    required this.onClose,
    this.onEditGoalDetails,
    this.onCreateHabitFromActionPlan,
  });

  @override
  Widget build(BuildContext context) {
    final link = component is ZoneComponent ? (component as ZoneComponent).link : null;
    final hasLink = link != null && link.isNotEmpty;
    final goalCarrier = component is ImageComponent
        ? (component as ImageComponent)
        : (component is GoalOverlayComponent ? (component as GoalOverlayComponent) : null);
    final goal = goalCarrier is ImageComponent
        ? goalCarrier.goal
        : (goalCarrier is GoalOverlayComponent ? goalCarrier.goal : null);
    final displayTitle = ComponentLabelUtils.categoryOrTitleOrId(component);
    final goalTitle = (goal?.title ?? '').trim();
    final dialogGoalTitle = goalTitle.isNotEmpty ? goalTitle : displayTitle;
    final microHabit = goal?.actionPlan?.microHabit?.trim();
    final frequency = goal?.actionPlan?.frequency?.trim();
    final weeklyDays = goal?.actionPlan?.weeklyDays ?? const <int>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (hasLink)
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        final url = Uri.parse(link);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open link: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open Link'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          if (goal != null && onEditGoalDetails != null)
            IconButton(
              tooltip: 'CBT & goal details',
              icon: const Icon(Icons.psychology_outlined),
              onPressed: () {
                final existing = goal;
                showGoalDetailsSheet(
                  context,
                  goal: existing,
                  onEdit: onEditGoalDetails == null
                      ? null
                      : (_) async {
                          final updated = await showGoalDetailsDialog(
                            context,
                            goalTitle: dialogGoalTitle,
                            initial: existing,
                          );
                          if (updated == null) return;
                          onEditGoalDetails?.call(updated);
                        },
                );
              },
            ),
          if (goal != null &&
              microHabit != null &&
              microHabit.isNotEmpty &&
              onCreateHabitFromActionPlan != null)
            IconButton(
              tooltip: 'Create habit from action plan',
              icon: const Icon(Icons.playlist_add_check_outlined),
              onPressed: () => onCreateHabitFromActionPlan!.call(
                microHabit,
                (frequency != null && frequency.isNotEmpty) ? frequency : null,
                weeklyDays,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

