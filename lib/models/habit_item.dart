import 'cbt_enhancements.dart';
import 'habit_action_step.dart';

final class HabitTimeBoundSpec {
  final bool enabled;
  /// Duration amount in the selected unit.
  final int duration;
  /// 'minutes' | 'hours'
  final String unit;
  /// Per-habit notification sound identifier.
  /// Built-in: 'default', 'chime', 'bell', 'gentle', 'alert', 'none'.
  /// Custom: a file path string.
  final String? notificationSound;
  /// Per-habit vibration type: 'none', 'default', 'short', 'long'.
  final String? vibrationType;

  const HabitTimeBoundSpec({
    required this.enabled,
    required this.duration,
    required this.unit,
    this.notificationSound,
    this.vibrationType,
  });

  int get durationMinutes {
    final u = unit.trim().toLowerCase();
    final d = duration < 0 ? 0 : duration;
    if (u == 'hours') return d * 60;
    return d;
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'duration': duration,
        'unit': unit,
        'notificationSound': notificationSound,
        'vibrationType': vibrationType,
      };

  factory HabitTimeBoundSpec.fromJson(Map<String, dynamic> json) {
    final enabled = (json['enabled'] as bool?) ?? false;
    final duration = (json['duration'] as num?)?.toInt() ?? 0;
    final unit = (json['unit'] as String?) ?? 'minutes';
    final notificationSound = json['notificationSound'] as String?;
    final vibrationType = json['vibrationType'] as String?;
    return HabitTimeBoundSpec(
      enabled: enabled,
      duration: duration,
      unit: unit,
      notificationSound: notificationSound,
      vibrationType: vibrationType,
    );
  }

  HabitTimeBoundSpec copyWith({
    bool? enabled,
    int? duration,
    String? unit,
    String? notificationSound,
    String? vibrationType,
  }) {
    return HabitTimeBoundSpec(
      enabled: enabled ?? this.enabled,
      duration: duration ?? this.duration,
      unit: unit ?? this.unit,
      notificationSound: notificationSound ?? this.notificationSound,
      vibrationType: vibrationType ?? this.vibrationType,
    );
  }
}

final class HabitLocationBoundSpec {
  final bool enabled;
  final double lat;
  final double lng;
  final int radiusMeters;
  /// 'arrival' | 'dwell' | 'both'
  final String triggerMode;
  /// Used when triggerMode is 'dwell' or 'both'
  final int? dwellMinutes;
  /// Human-readable address resolved via geocoding.
  final String? address;

  const HabitLocationBoundSpec({
    required this.enabled,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.triggerMode,
    required this.dwellMinutes,
    this.address,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'lat': lat,
        'lng': lng,
        'radiusMeters': radiusMeters,
        'triggerMode': triggerMode,
        'dwellMinutes': dwellMinutes,
        'address': address,
      };

  factory HabitLocationBoundSpec.fromJson(Map<String, dynamic> json) {
    final enabled = (json['enabled'] as bool?) ?? false;
    final lat = (json['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (json['lng'] as num?)?.toDouble() ?? 0.0;
    final radiusMeters = (json['radiusMeters'] as num?)?.toInt() ??
        (json['radius_meters'] as num?)?.toInt() ??
        150;
    final triggerMode = (json['triggerMode'] as String?) ?? (json['trigger_mode'] as String?) ?? 'arrival';
    final dwellMinutes = (json['dwellMinutes'] as num?)?.toInt() ?? (json['dwell_minutes'] as num?)?.toInt();
    final address = json['address'] as String?;
    return HabitLocationBoundSpec(
      enabled: enabled,
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      triggerMode: triggerMode,
      dwellMinutes: dwellMinutes,
      address: address,
    );
  }

  HabitLocationBoundSpec copyWith({
    bool? enabled,
    double? lat,
    double? lng,
    int? radiusMeters,
    String? triggerMode,
    int? dwellMinutes,
    String? address,
    bool clearAddress = false,
  }) {
    return HabitLocationBoundSpec(
      enabled: enabled ?? this.enabled,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      triggerMode: triggerMode ?? this.triggerMode,
      dwellMinutes: dwellMinutes ?? this.dwellMinutes,
      address: clearAddress ? null : (address ?? this.address),
    );
  }
}

/// Model representing a habit item with completion tracking.

class HabitItem {
  /// Unique identifier for the habit
  final String id;

  /// Name of the habit
  final String name;

  /// Optional category (e.g. Health, Fitness, Productivity).
  final String? category;

  /// Optional frequency label. Supported values: 'Daily' (default), 'Weekly'.
  final String? frequency;

  /// If frequency is Weekly, optional weekdays schedule (1=Mon..7=Sun).
  ///
  /// - Empty => legacy weekly behavior (one completion per week).
  /// - Non-empty => scheduled weekly days; completion is tracked per day.
  final List<int> weeklyDays;

  /// Optional deadline (ISO date YYYY-MM-DD).
  final String? deadline;

  /// Optional chaining: this habit should be done after another habit (by id).
  final String? afterHabitId;

  /// Optional time-of-day label (free-form, e.g. "07:00 AM").
  final String? timeOfDay;

  /// Structured reminder time stored as minutes since midnight (local time).
  ///
  /// This is used for scheduling OS reminders reliably, while `timeOfDay` remains
  /// a display label for the UI.
  final int? reminderMinutes;

  /// When true, an OS-level reminder should be scheduled for this habit.
  final bool reminderEnabled;

  /// Optional completion feedback keyed by ISO date (YYYY-MM-DD).
  final Map<String, HabitCompletionFeedback> feedbackByDate;

  /// Optional chaining description (anchor habit + relationship).
  final HabitChaining? chaining;

  /// Optional CBT enhancements for this habit.
  final CbtEnhancements? cbtEnhancements;

  /// Optional timebound settings (timer / duration tracking).
  final HabitTimeBoundSpec? timeBound;

  /// Optional location-based settings (geofence + dwell).
  final HabitLocationBoundSpec? locationBound;

  /// Optional icon index into the global [habitIcons] list.
  /// When null, the card falls back to the first icon for the category.
  final int? iconIndex;

  /// List of dates when this habit was completed (stored as date-only, no time)
  final List<DateTime> completedDates;

  /// Ordered action steps for this habit (simplified routine steps).
  final List<HabitActionStep> actionSteps;

  /// Start time in minutes since midnight for timeline placement.
  final int? startTimeMinutes;

  /// Board this habit belongs to (null for standalone habits).
  final String? boardId;

  /// Component/tile this habit belongs to (null for standalone habits).
  final String? componentId;

  const HabitItem({
    required this.id,
    required this.name,
    this.category,
    this.frequency,
    this.weeklyDays = const [],
    this.deadline,
    this.afterHabitId,
    this.timeOfDay,
    this.reminderMinutes,
    this.reminderEnabled = false,
    this.feedbackByDate = const {},
    this.chaining,
    this.cbtEnhancements,
    this.timeBound,
    this.locationBound,
    this.iconIndex,
    this.completedDates = const [],
    this.actionSteps = const [],
    this.startTimeMinutes,
    this.boardId,
    this.componentId,
  });

  Map<String, int> get stats => {
        'streak': currentStreak,
        'total_completions': completedDates.length,
      };

  /// Creates a copy of this habit with optional field overrides.
  ///
  /// Use the `clearX` flags to explicitly set nullable fields to null
  /// (since passing null normally means "keep existing value").
  HabitItem copyWith({
    String? id,
    String? name,
    String? category,
    String? frequency,
    List<int>? weeklyDays,
    String? deadline,
    String? afterHabitId,
    String? timeOfDay,
    int? reminderMinutes,
    bool? reminderEnabled,
    Map<String, HabitCompletionFeedback>? feedbackByDate,
    HabitChaining? chaining,
    CbtEnhancements? cbtEnhancements,
    HabitTimeBoundSpec? timeBound,
    bool clearTimeBound = false,
    HabitLocationBoundSpec? locationBound,
    int? iconIndex,
    List<DateTime>? completedDates,
    List<HabitActionStep>? actionSteps,
    int? startTimeMinutes,
    bool clearStartTimeMinutes = false,
    String? boardId,
    String? componentId,
  }) {
    return HabitItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      deadline: deadline ?? this.deadline,
      afterHabitId: afterHabitId ?? this.afterHabitId,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      feedbackByDate: feedbackByDate ?? this.feedbackByDate,
      chaining: chaining ?? this.chaining,
      cbtEnhancements: cbtEnhancements ?? this.cbtEnhancements,
      timeBound: clearTimeBound ? null : (timeBound ?? this.timeBound),
      locationBound: locationBound ?? this.locationBound,
      iconIndex: iconIndex ?? this.iconIndex,
      completedDates: completedDates ?? this.completedDates,
      actionSteps: actionSteps ?? this.actionSteps,
      startTimeMinutes: clearStartTimeMinutes ? null : (startTimeMinutes ?? this.startTimeMinutes),
      boardId: boardId ?? this.boardId,
      componentId: componentId ?? this.componentId,
    );
  }

  /// Converts to a map for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'frequency': frequency,
      'weeklyDays': weeklyDays,
      'deadline': deadline,
      'afterHabitId': afterHabitId,
      'timeOfDay': timeOfDay,
      'reminderMinutes': reminderMinutes,
      'reminderEnabled': reminderEnabled,
      'feedbackByDate': feedbackByDate.map((k, v) => MapEntry(k, v.toJson())),
      'chaining': chaining?.toJson(),
      'cbtEnhancements': cbtEnhancements?.toJson(),
      'timeBound': timeBound?.toJson(),
      'locationBound': locationBound?.toJson(),
      'iconIndex': iconIndex,
      'stats': stats,
      'completedDates': completedDates
          .map((date) => date.toIso8601String().split('T')[0])
          .toList(),
      'actionSteps': actionSteps.map((s) => s.toJson()).toList(),
      'startTimeMinutes': startTimeMinutes,
      'boardId': boardId,
      'componentId': componentId,
    };
  }

  static int? _parseTimeLabelToMinutes(String? label) {
    final s = (label ?? '').trim();
    if (s.isEmpty) return null;
    // Supports "07:00", "7:00", "07:00 AM", "7:00PM"
    final re = RegExp(r'^(\d{1,2})\s*:\s*(\d{2})\s*([AaPp][Mm])?$');
    final m = re.firstMatch(s.replaceAll(' ', ''));
    if (m == null) return null;
    int h = int.tryParse(m.group(1)!) ?? 0;
    final min = int.tryParse(m.group(2)!) ?? 0;
    final ampm = m.group(3);
    if (min < 0 || min > 59) return null;
    if (h < 0 || h > 23) return null;
    if (ampm != null) {
      final lower = ampm.toLowerCase();
      final isPm = lower == 'pm';
      if (h == 12) {
        h = isPm ? 12 : 0;
      } else {
        h = isPm ? (h + 12) : h;
      }
    }
    if (h < 0 || h > 23) return null;
    return (h * 60) + min;
  }

  /// Creates from a map (for deserialization)
  factory HabitItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> datesJson = json['completedDates'] as List<dynamic>? ?? [];
    final List<DateTime> dates = datesJson
        .map((dateStr) => DateTime.parse(dateStr as String))
        .toList();

    final rawFreq = json['frequency'] as String?;
    final parsedWeeklyDays = (json['weeklyDays'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
        .toList();
    final normalizedFrequency = _normalizeFrequency(rawFreq, parsedWeeklyDays);
    final normalizedWeeklyDays = _normalizeWeeklyDays(rawFreq, parsedWeeklyDays);

    final timeLabel = (json['timeOfDay'] as String?) ?? (json['time_of_day'] as String?);
    final reminderMinutes = (json['reminderMinutes'] as num?)?.toInt() ??
        (json['reminder_minutes'] as num?)?.toInt() ??
        _parseTimeLabelToMinutes(timeLabel);
    final reminderEnabled = (json['reminderEnabled'] as bool?) ??
        (json['reminder_enabled'] as bool?) ??
        false;
    final feedbackRaw = (json['feedbackByDate'] as Map<String, dynamic>?) ??
        (json['feedback_by_date'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final feedbackByDate = <String, HabitCompletionFeedback>{};
    for (final entry in feedbackRaw.entries) {
      if (entry.value is Map<String, dynamic>) {
        feedbackByDate[entry.key] =
            HabitCompletionFeedback.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    final timeBoundRaw = (json['timeBound'] as Map<String, dynamic>?) ??
        (json['time_bound'] as Map<String, dynamic>?);
    final locationBoundRaw = (json['locationBound'] as Map<String, dynamic>?) ??
        (json['location_bound'] as Map<String, dynamic>?);
    final iconIndex = (json['iconIndex'] as num?)?.toInt() ??
        (json['icon_index'] as num?)?.toInt();

    final actionStepsRaw = json['actionSteps'] as List<dynamic>? ??
        json['action_steps'] as List<dynamic>? ??
        const [];
    final actionSteps = actionStepsRaw
        .whereType<Map<String, dynamic>>()
        .map((e) => HabitActionStep.fromJson(e))
        .toList();

    final startTimeMinutes = (json['startTimeMinutes'] as num?)?.toInt() ??
        (json['start_time_minutes'] as num?)?.toInt();
    
    return HabitItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      frequency: normalizedFrequency,
      weeklyDays: normalizedWeeklyDays,
      deadline: json['deadline'] as String?,
      afterHabitId: json['afterHabitId'] as String?,
      timeOfDay: timeLabel,
      reminderMinutes: reminderMinutes,
      reminderEnabled: reminderEnabled,
      feedbackByDate: feedbackByDate,
      chaining: (json['chaining'] is Map<String, dynamic>)
          ? HabitChaining.fromJson(json['chaining'] as Map<String, dynamic>)
          : null,
      cbtEnhancements: (json['cbtEnhancements'] is Map<String, dynamic>)
          ? CbtEnhancements.fromJson(json['cbtEnhancements'] as Map<String, dynamic>)
          : (json['cbt_enhancements'] is Map<String, dynamic>)
              ? CbtEnhancements.fromJson(json['cbt_enhancements'] as Map<String, dynamic>)
              : null,
      timeBound: (timeBoundRaw != null) ? HabitTimeBoundSpec.fromJson(timeBoundRaw) : null,
      locationBound: (locationBoundRaw != null) ? HabitLocationBoundSpec.fromJson(locationBoundRaw) : null,
      iconIndex: iconIndex,
      completedDates: dates,
      actionSteps: actionSteps,
      startTimeMinutes: startTimeMinutes,
      boardId: json['boardId'] as String?,
      componentId: json['componentId'] as String?,
    );
  }

  static String? _normalizeFrequency(String? raw, List<int> weeklyDays) {
    final f = (raw ?? '').trim();
    if (f.isEmpty) return null;
    final lower = f.toLowerCase();
    if (lower == 'weekly' && weeklyDays.toSet().length >= 7) return 'Daily';
    if (lower == 'daily') return 'Daily';
    if (lower == 'weekly') return 'Weekly';
    return f;
  }

  static List<int> _normalizeWeeklyDays(String? rawFrequency, List<int> weeklyDays) {
    final f = (rawFrequency ?? '').trim().toLowerCase();
    final unique = weeklyDays.toSet();
    if (f == 'weekly' && unique.length >= 7) return const <int>[];
    return weeklyDays;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _weekStartMonday(DateTime date) {
    final d = _dateOnly(date);
    final delta = d.weekday - DateTime.monday; // monday=1
    return d.subtract(Duration(days: delta));
  }

  bool get isWeekly => (frequency ?? '').toLowerCase().trim() == 'weekly';

  bool get hasWeeklySchedule => isWeekly && weeklyDays.isNotEmpty;

  bool isScheduledOnDate(DateTime date) {
    if (!hasWeeklySchedule) return true;
    return weeklyDays.contains(_dateOnly(date).weekday);
  }

  /// Get the current streak count (consecutive days from today backwards)
  int get currentStreak {
    if (completedDates.isEmpty) return 0;

    // Legacy weekly behavior (once per week)
    if (isWeekly && !hasWeeklySchedule) {
      // Normalize to week-start anchors (Monday).
      final uniqueWeeks = completedDates.map(_weekStartMonday).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      if (uniqueWeeks.isEmpty) return 0;

      final today = DateTime.now();
      final thisWeek = _weekStartMonday(today);
      final prevWeek = thisWeek.subtract(const Duration(days: 7));

      int streak = 0;
      DateTime check = thisWeek;
      if (uniqueWeeks.contains(check)) {
        streak = 1;
        check = check.subtract(const Duration(days: 7));
      } else if (uniqueWeeks.contains(prevWeek)) {
        streak = 1;
        check = prevWeek.subtract(const Duration(days: 7));
      } else {
        return 0;
      }

      while (uniqueWeeks.contains(check)) {
        streak++;
        check = check.subtract(const Duration(days: 7));
      }
      return streak;
    }

    // Daily + scheduled-weekly: Normalize all dates to date-only (remove time component)
    final List<DateTime> normalizedDates = completedDates.map(_dateOnly).toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending (most recent first)

    // Remove duplicates
    final List<DateTime> uniqueDates = normalizedDates.toSet().toList()..sort((a, b) => b.compareTo(a));

    if (uniqueDates.isEmpty) return 0;

    DateTime prevScheduled(DateTime from) {
      var d = _dateOnly(from).subtract(const Duration(days: 1));
      if (!hasWeeklySchedule) return d;
      while (!isScheduledOnDate(d)) {
        d = d.subtract(const Duration(days: 1));
      }
      return d;
    }

    DateTime curr = _dateOnly(DateTime.now());
    if (hasWeeklySchedule && !isScheduledOnDate(curr)) {
      // If today isn't scheduled, move to the most recent scheduled day.
      while (!isScheduledOnDate(curr)) {
        curr = curr.subtract(const Duration(days: 1));
      }
    }

    // Allow a one-day miss equivalent: "current scheduled day" or "previous scheduled day"
    int streak = 0;
    DateTime start = curr;
    if (!uniqueDates.contains(start)) {
      final prev = prevScheduled(start);
      if (!uniqueDates.contains(prev)) return 0;
      start = prev;
    }

    streak = 1;
    DateTime check = prevScheduled(start);
    while (uniqueDates.contains(check)) {
      streak++;
      check = prevScheduled(check);
    }
    return streak;
  }

  /// Check if the habit was completed on a specific date (date-only comparison)
  bool isCompletedOnDate(DateTime date) {
    final DateTime normalizedDate = _dateOnly(date);
    if (isWeekly && !hasWeeklySchedule) {
      // For weekly habits, treat completion as the week-start anchor day only
      // (so calendar/insights don't count it on every day of that week).
      final weekStart = _weekStartMonday(normalizedDate);
      return normalizedDate == weekStart &&
          completedDates.map(_weekStartMonday).toSet().contains(weekStart);
    }

    return completedDates.any((completedDate) => _dateOnly(completedDate) == normalizedDate);
  }

  /// Toggle completion for today (adds if not present, removes if present)
  HabitItem toggleForDate(DateTime date) {
    final normalized = _dateOnly(date);
    final iso = normalized.toIso8601String().split('T')[0];
    final updatedDates = List<DateTime>.from(completedDates);
    final nextFeedback = Map<String, HabitCompletionFeedback>.from(feedbackByDate);

    if (isWeekly && !hasWeeklySchedule) {
      final weekStart = _weekStartMonday(normalized);
      final exists = updatedDates.map(_weekStartMonday).toSet().contains(weekStart);
      updatedDates.removeWhere((d) => _weekStartMonday(d) == weekStart);
      if (!exists) updatedDates.add(weekStart);
      if (exists) nextFeedback.remove(iso);
      return copyWith(completedDates: updatedDates, feedbackByDate: nextFeedback);
    }

    final exists = updatedDates.any((d) => _dateOnly(d) == normalized);
    updatedDates.removeWhere((d) => _dateOnly(d) == normalized);
    if (!exists) updatedDates.add(normalized);
    if (exists) nextFeedback.remove(iso);
    return copyWith(completedDates: updatedDates, feedbackByDate: nextFeedback);
  }

  /// For checkbox UI: "done this period?"
  bool isCompletedForCurrentPeriod(DateTime date) {
    final normalized = _dateOnly(date);
    if (isWeekly && !hasWeeklySchedule) {
      final weekStart = _weekStartMonday(normalized);
      return completedDates.map(_weekStartMonday).toSet().contains(weekStart);
    }
    return completedDates.any((d) => _dateOnly(d) == normalized);
  }

  @override
  String toString() {
    return 'HabitItem(id: $id, name: $name, completedDates: ${completedDates.length})';
  }
}

final class HabitCompletionFeedback {
  final int rating; // 1..5
  final String? note;
  /// Total coins awarded for this completion (base + step bonus + media bonus).
  /// Stored so we can deduct the exact amount on uncheck.
  final int? coinsEarned;
  const HabitCompletionFeedback({required this.rating, required this.note, this.coinsEarned});

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'note': note,
        if (coinsEarned != null) 'coinsEarned': coinsEarned,
      };

  factory HabitCompletionFeedback.fromJson(Map<String, dynamic> json) => HabitCompletionFeedback(
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        note: json['note'] as String?,
        coinsEarned: (json['coinsEarned'] as num?)?.toInt(),
      );
}

final class HabitChaining {
  final String? anchorHabit;
  final String? relationship;

  const HabitChaining({this.anchorHabit, this.relationship});

  Map<String, dynamic> toJson() => {
        'anchorHabit': anchorHabit,
        'relationship': relationship,
      };

  factory HabitChaining.fromJson(Map<String, dynamic> json) => HabitChaining(
        anchorHabit: (json['anchorHabit'] as String?) ?? (json['anchor_habit'] as String?),
        relationship: json['relationship'] as String?,
      );
}

/// Result of the add/edit habit flow; used to create or update a [HabitItem].
final class HabitCreateRequest {
  final String name;
  final String? category;
  final String? frequency; // null | 'Daily' | 'Weekly'
  final List<int> weeklyDays; // 1=Mon..7=Sun
  final String? deadline; // YYYY-MM-DD
  final String? afterHabitId;
  final String? timeOfDay; // free-form, e.g. "07:00 AM"
  final int? reminderMinutes;
  final bool reminderEnabled;
  final HabitChaining? chaining;
  final CbtEnhancements? cbtEnhancements;
  final HabitTimeBoundSpec? timeBound;
  final HabitLocationBoundSpec? locationBound;
  final int? iconIndex;
  final List<HabitActionStep> actionSteps;
  final int? startTimeMinutes;
  final String? notificationSound;
  final String? vibrationType;

  const HabitCreateRequest({
    required this.name,
    this.category,
    required this.frequency,
    required this.weeklyDays,
    required this.deadline,
    required this.afterHabitId,
    required this.timeOfDay,
    required this.reminderMinutes,
    required this.reminderEnabled,
    required this.chaining,
    required this.cbtEnhancements,
    required this.timeBound,
    required this.locationBound,
    this.iconIndex,
    this.actionSteps = const [],
    this.startTimeMinutes,
    this.notificationSound,
    this.vibrationType,
  });
}
