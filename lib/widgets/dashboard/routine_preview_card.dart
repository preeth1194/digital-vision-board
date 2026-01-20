import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/routine.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_typography.dart';

/// Widget that displays a preview card for a routine.
class RoutinePreviewCard extends StatelessWidget {
  final Routine routine;
  final String? activeRoutineId;
  final SharedPreferences? prefs;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RoutinePreviewCard({
    super.key,
    required this.routine,
    this.activeRoutineId,
    this.prefs,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  double _getCompletionPercentage() {
    if (routine.todos.isEmpty) return 0.0;
    if (prefs == null) return 0.0;
    final logicalDate = LogicalDateService.getLogicalDateSync(prefs: prefs!);
    final completed = routine.todos
        .where((todo) => todo.isCompletedOnDate(logicalDate))
        .length;
    return completed / routine.todos.length;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = routine.id == activeRoutineId;
    final tileColor = Color(routine.tileColorValue);
    final icon = IconData(routine.iconCodePoint, fontFamily: 'MaterialIcons');
    final progress = _getCompletionPercentage();
    final completedCount = routine.todos
        .where((todo) => todo.isCompletedOnDate(
              LogicalDateService.getLogicalDateSync(prefs: prefs),
            ))
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: isActive ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Stack(
        children: [
          // Background with icon
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tileColor,
                  tileColor.withOpacity(0.7),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 64,
                color: tileColor.computeLuminance() < 0.45
                    ? Colors.white.withOpacity(0.3)
                    : Colors.black.withOpacity(0.2),
              ),
            ),
          ),
          // Tap area
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Container(),
              ),
            ),
          ),
          // Content overlay at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              routine.title,
                              style: AppTypography.heading3(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${routine.todos.length} todos • ${completedCount} completed',
                              style: AppTypography.caption(context).copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            if (isActive)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Active',
                                  style: AppTypography.caption(context).copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Action buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              tooltip: 'Edit',
                              onPressed: onEdit,
                              iconSize: 20,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              tooltip: 'Delete',
                              onPressed: onDelete,
                              iconSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      minHeight: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
