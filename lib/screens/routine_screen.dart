import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine.dart';
import '../services/routine_storage_service.dart';
import '../services/sun_times_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_typography.dart';
import '../widgets/routine/routine_date_selector.dart';
import '../widgets/routine/sun_times_header.dart';
import '../widgets/routine/routine_timeline_item.dart';
import 'routine_timer_screen.dart';
import 'routine_editor_screen.dart';

/// Full-featured routine screen with date selection, timeline, and sun times.
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  bool _loading = true;
  SharedPreferences? _prefs;
  List<Routine> _routines = [];
  late DateTime _selectedDate;

  // Sun times
  DateTime? _sunrise;
  DateTime? _sunset;
  Timer? _currentTimeTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _normalizeDate();
    _init();
    // Update current time every minute for the sun position
    _currentTimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  void _normalizeDate() {
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
  }

  @override
  void dispose() {
    _currentTimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadRoutines();
    await _loadSunTimes();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRoutines() async {
    final routines = await RoutineStorageService.loadRoutines(prefs: _prefs);
    if (mounted) {
      setState(() {
        _routines = routines;
      });
    }
  }

  Future<void> _loadSunTimes() async {
    final sunTimes = await SunTimesService.getSunTimes(
      date: _selectedDate,
      prefs: _prefs,
    );

    if (sunTimes != null && mounted) {
      setState(() {
        _sunrise = sunTimes.sunrise;
        _sunset = sunTimes.sunset;
      });
    } else if (mounted) {
      // Use defaults if location not available
      final defaults = SunTimesService.getDefaultSunTimes(_selectedDate);
      setState(() {
        _sunrise = defaults.sunrise;
        _sunset = defaults.sunset;
      });
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
    _loadSunTimes();
  }

  List<Routine> get _routinesForSelectedDate {
    return _routines.where((r) => r.occursOnDate(_selectedDate)).toList()
      ..sort((a, b) {
        final aTime = a.getStartTimeMinutes() ?? 0;
        final bTime = b.getStartTimeMinutes() ?? 0;
        return aTime.compareTo(bTime);
      });
  }

  void _openRoutineTimer(Routine routine) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoutineTimerScreen(
          routine: routine,
          onComplete: () => _loadRoutines(),
        ),
      ),
    ).then((_) => _loadRoutines());
  }

  void _openRoutineEditor([Routine? routine]) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineEditorScreen(routine: routine),
      ),
    ).then((saved) {
      if (saved == true) {
        _loadRoutines();
      }
    });
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Routine'),
        content: Text('Are you sure you want to delete "${routine.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final updatedRoutines = _routines.where((r) => r.id != routine.id).toList();
    await RoutineStorageService.saveRoutines(updatedRoutines, prefs: _prefs);
    
    if (mounted) {
      setState(() {
        _routines = updatedRoutines;
      });
      
      HapticFeedback.mediumImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${routine.title}" deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.schedule_outlined,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No routines for this day',
              style: AppTypography.heading3(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a routine and set its occurrence to see it here',
              style: AppTypography.secondary(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openRoutineEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Create Routine'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routinesForDate = _routinesForSelectedDate;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Date selector
        RoutineDateSelector(
          selectedDate: _selectedDate,
          onDateSelected: _onDateSelected,
          routines: _routines,
        ),
        const SizedBox(height: 8),
        // Sun times header
        if (_sunrise != null && _sunset != null)
          SunTimesHeader(
            sunrise: _sunrise!,
            sunset: _sunset!,
            currentTime: _currentTime,
          ),
        // Timeline or empty state
        Expanded(
          child: routinesForDate.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadRoutines,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: routinesForDate.length,
                    itemBuilder: (context, index) {
                      final routine = routinesForDate[index];
                      return _SwipeableRoutineItem(
                        routine: routine,
                        onEdit: () => _openRoutineEditor(routine),
                        onDelete: () => _deleteRoutine(routine),
                        child: RoutineTimelineItem(
                          routine: routine,
                          selectedDate: _selectedDate,
                          isFirst: index == 0,
                          isLast: index == routinesForDate.length - 1,
                          onTap: () => _openRoutineTimer(routine),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// Swipeable wrapper for routine items with edit (left swipe) and delete (right swipe) actions
class _SwipeableRoutineItem extends StatefulWidget {
  final Routine routine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  const _SwipeableRoutineItem({
    required this.routine,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });

  @override
  State<_SwipeableRoutineItem> createState() => _SwipeableRoutineItemState();
}

class _SwipeableRoutineItemState extends State<_SwipeableRoutineItem> {
  double _dragExtent = 0;
  static const double _actionThreshold = 80;
  static const double _maxDrag = 100;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.delta.dx;
      _dragExtent = _dragExtent.clamp(-_maxDrag, _maxDrag);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() >= _actionThreshold) {
      if (_dragExtent > 0) {
        // Swiped right - Delete
        HapticFeedback.mediumImpact();
        widget.onDelete();
      } else {
        // Swiped left - Edit
        HapticFeedback.mediumImpact();
        widget.onEdit();
      }
    }
    // Reset position
    setState(() {
      _dragExtent = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragExtent.abs() / _actionThreshold).clamp(0.0, 1.0);
    final isRightSwipe = _dragExtent > 0;

    return Stack(
      children: [
        // Background action indicators
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  // Delete action (right swipe reveals left side)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: isRightSwipe ? progress : 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 150),
                          scale: isRightSwipe ? 0.8 + (progress * 0.2) : 0.8,
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Edit action (left swipe reveals right side)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: !isRightSwipe && _dragExtent != 0 ? progress : 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 150),
                          scale: !isRightSwipe ? 0.8 + (progress * 0.2) : 0.8,
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Draggable card
        GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: AnimatedContainer(
            duration: _dragExtent == 0
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragExtent, 0, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
