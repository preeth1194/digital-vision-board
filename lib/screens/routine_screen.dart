import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine.dart';
import '../services/routine_storage_service.dart';
import '../services/sun_times_service.dart';
import '../utils/app_colors.dart';
import '../widgets/routine/routine_calendar_header.dart';
import '../widgets/routine/sun_times_header.dart';
import 'routine_timer_screen.dart';
import 'routine_editor_screen.dart';

/// Full-featured routine screen with calendar header, sun/moon arc, timeline, and FAB.
/// Features:
/// - Calendar header with greeting, month selector, Today button, and week selector
/// - Interactive sun/moon arc visualization based on time of day
/// - Timeline list of routines for selected date
/// - FAB for adding new routines
class RoutineScreen extends StatefulWidget {
  /// If true, shows as a standalone screen with its own Scaffold.
  /// If false (default), returns just the body content for embedding in parent Scaffold.
  final bool standalone;
  
  const RoutineScreen({
    super.key,
    this.standalone = false,
  });

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> with TickerProviderStateMixin {
  bool _loading = true;
  SharedPreferences? _prefs;
  List<Routine> _routines = [];
  late DateTime _selectedDate;

  // Sun times
  DateTime? _sunrise;
  DateTime? _sunset;
  Timer? _currentTimeTimer;
  DateTime _currentTime = DateTime.now();

  // Timeline scroll state
  late ScrollController _timelineScrollController;
  DateTime? _timelinePreviewTime;
  static const double _hourHeight = 70.0;
  static const double _totalTimelineHeight = _hourHeight * 24;
  double _viewportHeight = 0;
  int _lastCrossedHour = -1;
  
  // Animation controller for current time indicator
  late AnimationController _currentTimeIndicatorController;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _normalizeDate();
    _init();
    
    // Initialize timeline scroll controller with listener
    _timelineScrollController = ScrollController();
    _timelineScrollController.addListener(_onTimelineScroll);
    
    // Initialize current time indicator animation
    _currentTimeIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
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
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    _currentTimeIndicatorController.dispose();
    super.dispose();
  }

  void _onTimelineScroll() {
    if (!_timelineScrollController.hasClients) return;
    
    final scrollOffset = _timelineScrollController.offset;
    final centerOffset = scrollOffset + _viewportHeight / 2;
    final centerHour = (centerOffset / _hourHeight).clamp(0.0, 23.99);
    
    // Calculate preview time from scroll position
    final previewTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      centerHour.floor(),
      ((centerHour % 1) * 60).toInt(),
    );
    
    // Haptic feedback when crossing hour boundaries
    final currentCrossedHour = centerHour.floor();
    if (currentCrossedHour != _lastCrossedHour && _lastCrossedHour != -1) {
      HapticFeedback.selectionClick();
    }
    _lastCrossedHour = currentCrossedHour;
    
    setState(() {
      _timelinePreviewTime = previewTime;
    });
  }

  void _scrollToCurrentTime({bool animate = true}) {
    if (!_timelineScrollController.hasClients) return;
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final targetOffset = (currentMinutes / 60) * _hourHeight - _viewportHeight / 2;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _totalTimelineHeight - _viewportHeight,
    );
    
    if (animate) {
      _timelineScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _timelineScrollController.jumpTo(clampedOffset);
    }
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

  bool _isRefreshingLocation = false;

  Future<void> _refreshLocation() async {
    if (_isRefreshingLocation) return;

    setState(() {
      _isRefreshingLocation = true;
    });

    try {
      final sunTimes = await SunTimesService.refreshLocationAndGetSunTimes(
        date: _selectedDate,
        prefs: _prefs,
      );

      if (mounted) {
        if (sunTimes != null) {
          setState(() {
            _sunrise = sunTimes.sunrise;
            _sunset = sunTimes.sunset;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location updated'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get location. Check permissions.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingLocation = false;
        });
      }
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Calendar header with month selector and week view
        RoutineCalendarHeader(
          selectedDate: _selectedDate,
          onDateSelected: _onDateSelected,
          routines: _routines,
        ),
        // Sun/Moon times header with interactive arc (STATIC - does not scroll)
        if (_sunrise != null && _sunset != null)
          SunTimesHeader(
            sunrise: _sunrise!,
            sunset: _sunset!,
            currentTime: _currentTime,
            previewTime: _timelinePreviewTime,
            onRefreshLocation: _refreshLocation,
          ),
        // 24-Hour Timeline (SCROLLABLE)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewportHeight = constraints.maxHeight;
              
              // Auto-scroll to current time on first build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_timelineScrollController.hasClients && 
                    _timelineScrollController.offset == 0 &&
                    _lastCrossedHour == -1) {
                  _scrollToCurrentTime(animate: false);
                }
              });
              
              return _build24HourTimeline();
            },
          ),
        ),
      ],
    );
  }

  Widget _build24HourTimeline() {
    final routinesForDate = _routinesForSelectedDate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      onRefresh: _loadRoutines,
      child: SingleChildScrollView(
        controller: _timelineScrollController,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          height: _totalTimelineHeight,
          child: Stack(
            children: [
              // Hour lines and labels (background layer)
              ..._buildHourLines(isDark),
              
              // Current time indicator with pulse animation
              _buildCurrentTimeIndicator(isDark),
              
              // Routine cards positioned at their times
              ..._buildPositionedRoutineCards(routinesForDate, isDark),
              
              // Empty state hint (shows in center when no routines)
              if (routinesForDate.isEmpty)
                Positioned(
                  top: _totalTimelineHeight / 2 - 60,
                  left: 56,
                  right: 16,
                  child: _buildEmptyTimelineHint(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTimelineHint() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 40,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No routines scheduled',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to create your first routine',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHourLines(bool isDark) {
    final List<Widget> hourWidgets = [];
    final scrollOffset = _timelineScrollController.hasClients 
        ? _timelineScrollController.offset 
        : 0.0;
    
    for (int hour = 0; hour < 24; hour++) {
      final yPosition = hour * _hourHeight;
      final hourLabel = _formatHourLabel(hour);
      
      // Calculate opacity based on distance from viewport center
      final distanceFromCenter = (yPosition - (scrollOffset + _viewportHeight / 2)).abs();
      final opacity = (1.0 - (distanceFromCenter / _viewportHeight * 0.8)).clamp(0.4, 1.0);
      
      // Check if this is the current hour
      final now = DateTime.now();
      final isCurrentHour = now.hour == hour && 
          _selectedDate.year == now.year && 
          _selectedDate.month == now.month && 
          _selectedDate.day == now.day;
      
      hourWidgets.add(
        Positioned(
          top: yPosition,
          left: 0,
          right: 0,
          height: _hourHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hour label
              SizedBox(
                width: 56,
                child: Padding(
                  padding: const EdgeInsets.only(top: 0, left: 8),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: opacity,
                    child: Text(
                      hourLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrentHour ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrentHour 
                            ? AppColors.medium 
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
              ),
              // Dotted line
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, right: 16),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: opacity * 0.5,
                    child: CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DottedLinePainter(
                        color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return hourWidgets;
  }

  Widget _buildCurrentTimeIndicator(bool isDark) {
    final now = DateTime.now();
    
    // Only show if viewing today
    if (_selectedDate.year != now.year || 
        _selectedDate.month != now.month || 
        _selectedDate.day != now.day) {
      return const SizedBox.shrink();
    }
    
    final currentMinutes = now.hour * 60 + now.minute;
    final yPosition = (currentMinutes / 60) * _hourHeight;
    
    return Positioned(
      top: yPosition - 6,
      left: 48,
      right: 16,
      child: AnimatedBuilder(
        animation: _currentTimeIndicatorController,
        builder: (context, child) {
          final pulseValue = _currentTimeIndicatorController.value;
          return Row(
            children: [
              // Circle indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3 + pulseValue * 0.3),
                      blurRadius: 4 + pulseValue * 4,
                      spreadRadius: pulseValue * 2,
                    ),
                  ],
                ),
              ),
              // Line
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.red.withOpacity(0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.2 + pulseValue * 0.2),
                        blurRadius: 2 + pulseValue * 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPositionedRoutineCards(List<Routine> routines, bool isDark) {
    final List<Widget> cards = [];
    final scrollOffset = _timelineScrollController.hasClients 
        ? _timelineScrollController.offset 
        : 0.0;
    
    for (int i = 0; i < routines.length; i++) {
      final routine = routines[i];
      final startMinutes = routine.getStartTimeMinutes() ?? 0;
      final duration = routine.getTotalDurationMinutes();
      final yPosition = (startMinutes / 60) * _hourHeight;
      final cardHeight = ((duration / 60) * _hourHeight).clamp(60.0, 200.0);
      
      // Calculate distance from viewport center for animations
      final cardCenter = yPosition + cardHeight / 2;
      final viewportCenter = scrollOffset + _viewportHeight / 2;
      final distanceFromCenter = (cardCenter - viewportCenter).abs();
      final normalizedDistance = (distanceFromCenter / _viewportHeight).clamp(0.0, 1.0);
      
      // Scale and opacity based on distance (micro-interaction)
      final scale = 1.0 - (normalizedDistance * 0.05);
      final opacity = 1.0 - (normalizedDistance * 0.3);
      
      cards.add(
        Positioned(
          top: yPosition,
          left: 56,
          right: 8,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: opacity.clamp(0.7, 1.0),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: scale.clamp(0.95, 1.0),
              child: _SwipeableRoutineItem(
                routine: routine,
                onEdit: () => _openRoutineEditor(routine),
                onDelete: () => _deleteRoutine(routine),
                child: _TimelineRoutineCard(
                  routine: routine,
                  selectedDate: _selectedDate,
                  height: cardHeight,
                  onTap: () => _openRoutineTimer(routine),
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return cards;
  }

  String _formatHourLabel(int hour) {
    if (hour == 0) return '12 am';
    if (hour == 12) return '12 pm';
    if (hour < 12) return '$hour am';
    return '${hour - 12} pm';
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () => _openRoutineEditor(),
      backgroundColor: AppColors.medium,
      foregroundColor: Colors.white,
      elevation: 4,
      child: const Icon(Icons.add, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If standalone, wrap in Scaffold with FAB
    if (widget.standalone) {
      return Scaffold(
        body: _buildBody(),
        floatingActionButton: _buildFAB(),
      );
    }

    // Otherwise, return just the body for embedding
    // The parent (DashboardScreen) should provide the FAB
    return Stack(
      children: [
        _buildBody(),
        // Position FAB at bottom right
        Positioned(
          right: 16,
          bottom: 16,
          child: _buildFAB(),
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

/// Custom painter for dotted horizontal lines
class _DottedLinePainter extends CustomPainter {
  final Color color;
  
  _DottedLinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(_DottedLinePainter oldDelegate) => oldDelegate.color != color;
}

/// Compact routine card for the 24-hour timeline view
class _TimelineRoutineCard extends StatelessWidget {
  final Routine routine;
  final DateTime selectedDate;
  final double height;
  final VoidCallback onTap;
  final bool isDark;

  const _TimelineRoutineCard({
    required this.routine,
    required this.selectedDate,
    required this.height,
    required this.onTap,
    required this.isDark,
  });

  String _formatTimeFromMinutes(int? minutes) {
    if (minutes == null) return '--:--';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final isPM = hours >= 12;
    final hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    return '${hour12.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')} ${isPM ? 'PM' : 'AM'}';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  @override
  Widget build(BuildContext context) {
    final tileColor = Color(routine.tileColorValue);
    final icon = IconData(routine.iconCodePoint, fontFamily: 'MaterialIcons');
    final duration = routine.getTotalDurationMinutes();
    final startTime = routine.getStartTimeMinutes();
    final endTime = startTime != null ? startTime + duration : null;
    final completion = routine.getCompletionPercentageForDate(selectedDate);
    final isCompleted = completion >= 1.0;
    final textColor = _getContrastColor(tileColor);
    final subtitleColor = textColor.withOpacity(0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height.clamp(60, 200),
          margin: const EdgeInsets.only(bottom: 4, right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tileColor.withOpacity(isDark ? 0.9 : 1.0),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: tileColor.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              // Content - clip to prevent overflow
              Expanded(
                child: ClipRect(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        routine.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 12, color: subtitleColor),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${_formatTimeFromMinutes(startTime)} - ${_formatTimeFromMinutes(endTime)}',
                              style: TextStyle(fontSize: 10, color: subtitleColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(duration),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: subtitleColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Completion indicator
              SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 2.5,
                      backgroundColor: textColor.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(textColor.withOpacity(0.2)),
                    ),
                    CircularProgressIndicator(
                      value: completion,
                      strokeWidth: 2.5,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(textColor),
                    ),
                    if (isCompleted)
                      Icon(Icons.check, size: 12, color: textColor)
                    else if (completion > 0)
                      Text(
                        '${(completion * 100).round()}',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: textColor),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? AppColors.darkest : AppColors.lightest;
  }
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
    final isDragging = _dragExtent != 0;

    return Stack(
      children: [
        // Background action indicators - only show when dragging
        if (isDragging)
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
