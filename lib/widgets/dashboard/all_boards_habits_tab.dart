import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';
import '../../services/notifications_service.dart';
import '../../services/logical_date_service.dart';
import '../../services/sync_service.dart';
import '../../screens/habit_timer_screen.dart';
import '../../screens/rhythmic_timer_screen.dart';
import '../../services/habit_geofence_tracking_service.dart';
import '../../utils/component_label_utils.dart';
import '../dialogs/add_habit_dialog.dart';
import '../dialogs/goal_picker_sheet.dart';
import '../dialogs/completion_feedback_sheet.dart';

class AllBoardsHabitsTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final Map<String, List<VisionComponent>> componentsByBoardId;
  final Future<void> Function(String boardId, List<VisionComponent> updated) onSaveBoardComponents;

  const AllBoardsHabitsTab({
    super.key,
    required this.boards,
    required this.componentsByBoardId,
    required this.onSaveBoardComponents,
  });

  static String _toIsoDate(DateTime d) => LogicalDateService.toIsoDate(d);

  @override
  Widget build(BuildContext context) {
    final boardIds = boards.map((b) => b.id).toList();
    return StatefulBuilder(
      builder: (context, setLocal) {
        Future<VisionBoardInfo?> pickBoard() async {
          if (boards.isEmpty) return null;
          return showModalBottomSheet<VisionBoardInfo?>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => SafeArea(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: boards.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final b = boards[i];
                  return ListTile(
                    title: Text(b.title),
                    onTap: () => Navigator.of(ctx).pop(b),
                  );
                },
              ),
            ),
          );
        }

        Future<void> addHabitGlobal() async {
          final board = await pickBoard();
          if (board == null) return;
          final components = componentsByBoardId[board.id] ?? const <VisionComponent>[];
          final selected = await showGoalPickerSheet(
            context,
            components: components,
            title: 'Select goal for habit',
          );
          if (selected == null) return;

          final goalDeadline = selected is ImageComponent
              ? selected.goal?.deadline
              : (selected is GoalOverlayComponent ? selected.goal.deadline : null);

          final req = await showAddHabitDialog(
            context,
            initialName: null,
            suggestedGoalDeadline: goalDeadline,
            existingHabits: selected.habits,
          );
          if (req == null) return;

          final newHabit = HabitItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: req.name,
            frequency: req.frequency,
            weeklyDays: req.weeklyDays,
            deadline: req.deadline,
            afterHabitId: req.afterHabitId,
            timeOfDay: req.timeOfDay,
            reminderMinutes: req.reminderMinutes,
            reminderEnabled: req.reminderEnabled,
            chaining: req.chaining,
            cbtEnhancements: req.cbtEnhancements,
            timeBound: req.timeBound,
            locationBound: req.locationBound,
            completedDates: const [],
          );

          final nextComponents = components.map((c) {
            if (c.id != selected.id) return c;
            return c.copyWithCommon(habits: [...c.habits, newHabit]);
          }).toList();

          await onSaveBoardComponents(board.id, nextComponents);
          setLocal(() => componentsByBoardId[board.id] = nextComponents);

          Future<void>(() async {
            // Keep location tracking in sync when new location-based habits are added.
            await HabitGeofenceTrackingService.instance.configureForComponent(
              boardId: board.id,
              componentId: selected.id,
              habits: nextComponents.where((c) => c.id == selected.id).first.habits,
            );
          });

          Future<void>(() async {
            if (!newHabit.reminderEnabled || newHabit.reminderMinutes == null) return;
            final ok = await NotificationsService.requestPermissionsIfNeeded();
            if (!ok) return;
            await NotificationsService.scheduleHabitReminders(newHabit);
          });
        }

        Future<void> toggleHabitForBoard({
          required String boardId,
          required String boardTitle,
          required List<VisionComponent> components,
          required VisionComponent component,
          required HabitItem habit,
        }) async {
          final now = LogicalDateService.now();
          if (!habit.isScheduledOnDate(now)) return;
          final wasDone = habit.isCompletedForCurrentPeriod(now);
          final toggled = habit.toggleForDate(now);
          final updatedHabits = component.habits.map((h) => h.id == habit.id ? toggled : h).toList();
          final updatedComponent = component.copyWithCommon(habits: updatedHabits);
          final updatedComponents = components.map((c) => c.id == component.id ? updatedComponent : c).toList();
          await onSaveBoardComponents(boardId, updatedComponents);
          setLocal(() {
            componentsByBoardId[boardId] = updatedComponents;
          });

          // Outbox: completion toggle.
          final iso = _toIsoDate(now);
          Future<void>(() async {
            await SyncService.enqueueHabitCompletion(
              boardId: boardId,
              componentId: component.id,
              habitId: habit.id,
              logicalDate: iso,
              deleted: wasDone,
            );
          });

          // Prompt for completion feedback on marking complete.
          if (!wasDone) {
            if (!toggled.feedbackByDate.containsKey(iso)) {
              final res = await showCompletionFeedbackSheet(
                context,
                title: 'How did it go?',
                subtitle: '${habit.name} • $boardTitle',
              );
              if (res == null) return;

              final nextFeedback = Map<String, HabitCompletionFeedback>.from(toggled.feedbackByDate);
              nextFeedback[iso] = HabitCompletionFeedback(rating: res.rating, note: res.note);
              final withFeedback = toggled.copyWith(feedbackByDate: nextFeedback);

              final updatedHabits2 = component.habits.map((h) => h.id == habit.id ? withFeedback : h).toList();
              final updatedComponent2 = component.copyWithCommon(habits: updatedHabits2);
              final updatedComponents2 = components.map((c) => c.id == component.id ? updatedComponent2 : c).toList();
              await onSaveBoardComponents(boardId, updatedComponents2);
              setLocal(() {
                componentsByBoardId[boardId] = updatedComponents2;
              });

              Future<void>(() async {
                await SyncService.enqueueHabitCompletion(
                  boardId: boardId,
                  componentId: component.id,
                  habitId: habit.id,
                  logicalDate: iso,
                  rating: res.rating,
                  note: res.note,
                  deleted: false,
                );
              });
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Spacer(),
                FilledButton.icon(
                  onPressed: addHabitGlobal,
                  icon: const Icon(Icons.add),
                  label: const Text('Add habit'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...boardIds.map((id) {
              final board = boards.firstWhere((b) => b.id == id);
              final components = componentsByBoardId[id] ?? const <VisionComponent>[];
              final componentsWithHabits = components.where((c) => c.habits.isNotEmpty).toList();
              if (componentsWithHabits.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      board.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...componentsWithHabits.map((component) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              ComponentLabelUtils.categoryOrTitleOrId(component),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          ...component.habits.map((habit) {
                            final now = LogicalDateService.now();
                            final scheduledToday = habit.isScheduledOnDate(now);
                            final isCompleted = scheduledToday && habit.isCompletedForCurrentPeriod(now);
                            return CheckboxListTile(
                              value: isCompleted,
                              onChanged: scheduledToday
                                  ? (_) async {
                                  await toggleHabitForBoard(
                                    boardId: id,
                                    boardTitle: board.title,
                                    components: components,
                                    component: component,
                                    habit: habit,
                                  );
                                }
                                  : null,
                              title: Text(habit.name),
                              subtitle: scheduledToday ? null : const Text('Not scheduled today'),
                              tileColor: (habit.locationBound?.enabled == true) ? Colors.green.shade200 : null,
                              secondary: (habit.timeBound?.enabled == true || habit.locationBound?.enabled == true)
                                  ? IconButton(
                                      tooltip: 'Timer',
                                      icon: const Icon(Icons.timer_outlined),
                                      onPressed: () async {
                                        final isSongBased = habit.timeBound?.isSongBased ?? false;
                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => isSongBased
                                                ? RhythmicTimerScreen(
                                                    habit: habit,
                                                    onMarkCompleted: () async {
                                                      final latestComponents = componentsByBoardId[id] ?? const <VisionComponent>[];
                                                      final latestComponent = latestComponents
                                                          .where((c) => c.id == component.id)
                                                          .cast<VisionComponent?>()
                                                          .firstWhere((_) => true, orElse: () => null);
                                                      if (latestComponent == null) return;
                                                      final latestHabit = latestComponent.habits
                                                          .where((h) => h.id == habit.id)
                                                          .cast<HabitItem?>()
                                                          .firstWhere((_) => true, orElse: () => null);
                                                      if (latestHabit == null) return;
                                                      final now2 = LogicalDateService.now();
                                                      if (!latestHabit.isScheduledOnDate(now2)) return;
                                                      if (latestHabit.isCompletedForCurrentPeriod(now2)) return;
                                                      await toggleHabitForBoard(
                                                        boardId: id,
                                                        boardTitle: board.title,
                                                        components: latestComponents,
                                                        component: latestComponent,
                                                        habit: latestHabit,
                                                      );
                                                    },
                                                  )
                                                : HabitTimerScreen(
                                                    habit: habit,
                                                    onMarkCompleted: () async {
                                                      final latestComponents = componentsByBoardId[id] ?? const <VisionComponent>[];
                                                      final latestComponent = latestComponents
                                                          .where((c) => c.id == component.id)
                                                          .cast<VisionComponent?>()
                                                          .firstWhere((_) => true, orElse: () => null);
                                                      if (latestComponent == null) return;
                                                      final latestHabit = latestComponent.habits
                                                          .where((h) => h.id == habit.id)
                                                          .cast<HabitItem?>()
                                                          .firstWhere((_) => true, orElse: () => null);
                                                      if (latestHabit == null) return;
                                                      final now2 = LogicalDateService.now();
                                                      if (!latestHabit.isScheduledOnDate(now2)) return;
                                                      if (latestHabit.isCompletedForCurrentPeriod(now2)) return;
                                                      await toggleHabitForBoard(
                                                        boardId: id,
                                                        boardTitle: board.title,
                                                        components: latestComponents,
                                                        component: latestComponent,
                                                        habit: latestHabit,
                                                      );
                                                    },
                                                  ),
                                          ),
                                        );
                                      },
                                    )
                                  : null,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}

