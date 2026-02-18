import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit_item.dart';
import 'app_settings_service.dart';
import 'notification_routing_service.dart';

class NotificationsService {
  NotificationsService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (kIsWeb) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(tz.local.name));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;

    // Handle cold-start: app was killed, user tapped a notification to launch.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      // Delay slightly so the navigator is mounted before we try to show a sheet.
      Future.delayed(const Duration(milliseconds: 600), () {
        _onNotificationTap(launchDetails.notificationResponse!);
      });
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == 'geofence_completion') {
        NotificationRoutingService.handleGeofenceCompletionTap(
          boardId: data['boardId'] as String,
          componentId: data['componentId'] as String,
          habitId: data['habitId'] as String,
        );
      }
    } catch (e) {
      debugPrint('Notification tap payload error: $e');
    }
  }

  static Future<bool> requestPermissionsIfNeeded() async {
    if (kIsWeb) return false;
    await ensureInitialized();

    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    bool ok = true;
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
      ok = ok && (granted ?? false);
    }
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      ok = ok && (granted ?? false);
    }
    return ok;
  }

  static int _stableId(String s) {
    // Deterministic 31-bit hash
    int h = 0;
    for (final unit in s.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return math.max(1, h);
  }

  static int _habitReminderId(HabitItem habit, {int? weekday}) {
    // If weekday provided, keep separate schedule per weekday.
    return _stableId('habit:${habit.id}:w:${weekday ?? 0}');
  }

  static int _habitSnoozeId(HabitItem habit, String isoDate) {
    return _stableId('habit:${habit.id}:snooze:$isoDate');
  }

  static List<int>? _vibrationPatternForType(String? vibrationType) {
    switch (vibrationType) {
      case 'none':
        return null;
      case 'short':
        return [0, 100];
      case 'long':
        return [0, 500, 200, 500];
      case 'default':
      default:
        return null; // platform default
    }
  }

  static AndroidNotificationDetails _getAndroidChannel({
    String? customSoundPath,
    String? vibrationType,
  }) {
    final enableVibration = vibrationType != 'none';
    final pattern = _vibrationPatternForType(vibrationType);
    return AndroidNotificationDetails(
      'habit_reminders',
      'Habit reminders',
      channelDescription: 'Reminders for scheduled habits',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: enableVibration,
      vibrationPattern: pattern != null ? Int64List.fromList(pattern) : null,
      playSound: true,
      sound: customSoundPath != null
          ? UriAndroidNotificationSound('file://$customSoundPath')
          : null,
    );
  }

  static NotificationDetails _getPlatformDetails({
    String? customSoundPath,
    String? vibrationType,
  }) {
    return NotificationDetails(
      android: _getAndroidChannel(
        customSoundPath: customSoundPath,
        vibrationType: vibrationType,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: customSoundPath,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );
  }

  /// Resolves the effective sound path for a habit.
  /// Per-habit sound takes priority, then global setting, then null (system default).
  static String? _resolveSoundPath(HabitItem habit) {
    final perHabit = habit.timeBound?.notificationSound;
    if (perHabit == 'none') return null;
    // Built-in preset ids are short names; file paths contain slashes
    if (perHabit != null && perHabit.contains('/')) return perHabit;
    // For built-in presets we don't have actual audio files bundled yet,
    // so fall through to global custom sound or system default.
    return AppSettingsService.customAlarmSoundPath.value;
  }

  static tz.TZDateTime _nextInstanceForTimeTodayOrTomorrow(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextInstanceForWeekday(TimeOfDay time, int weekday) {
    // weekday: DateTime.monday..DateTime.sunday
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> cancelHabitReminders(HabitItem habit) async {
    if (kIsWeb) return;
    await ensureInitialized();
    // Cancel daily (weekday null -> id uses 0) and weekly variants.
    await _plugin.cancel(_habitReminderId(habit));
    for (int wd = DateTime.monday; wd <= DateTime.sunday; wd++) {
      await _plugin.cancel(_habitReminderId(habit, weekday: wd));
    }
  }

  /// Whether this habit should have a scheduled notification.
  /// True when either a manual reminder is enabled, or the timer addon has a
  /// start time (notification sound != 'none').
  static bool shouldSchedule(HabitItem habit) {
    if (habit.reminderEnabled && habit.reminderMinutes != null) return true;
    if (habit.startTimeMinutes != null &&
        habit.timeBound != null &&
        habit.timeBound!.enabled &&
        habit.timeBound!.notificationSound != 'none') {
      return true;
    }
    return false;
  }

  static Future<void> scheduleHabitReminders(HabitItem habit) async {
    if (kIsWeb) return;
    await ensureInitialized();

    if (!shouldSchedule(habit)) {
      await cancelHabitReminders(habit);
      return;
    }

    // Determine the notification time: explicit reminder time, or start time
    final int minutes;
    if (habit.reminderEnabled && habit.reminderMinutes != null) {
      minutes = habit.reminderMinutes!;
    } else if (habit.startTimeMinutes != null) {
      minutes = habit.startTimeMinutes!;
    } else {
      await cancelHabitReminders(habit);
      return;
    }
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

    // Clear any older schedules first
    await cancelHabitReminders(habit);

    final customSoundPath = _resolveSoundPath(habit);
    final vibrationType = habit.timeBound?.vibrationType;
    final platformDetails = _getPlatformDetails(
      customSoundPath: customSoundPath,
      vibrationType: vibrationType,
    );

    final freq = (habit.frequency ?? '').trim().toLowerCase();
    if (freq == 'weekly' && habit.weeklyDays.isNotEmpty) {
      for (final wd in habit.weeklyDays.toSet()) {
        final when = _nextInstanceForWeekday(time, wd);
        await _plugin.zonedSchedule(
          _habitReminderId(habit, weekday: wd),
          'Habit reminder',
          habit.name,
          when,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return;
    }

    // Default: daily reminder
    final when = _nextInstanceForTimeTodayOrTomorrow(time);
    await _plugin.zonedSchedule(
      _habitReminderId(habit),
      'Habit reminder',
      habit.name,
      when,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleSnoozeForToday(HabitItem habit, TimeOfDay time) async {
    if (kIsWeb) return;
    await ensureInitialized();
    final now = tz.TZDateTime.now(tz.local);
    final iso = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (when.isBefore(now)) return;
    final customSoundPath = _resolveSoundPath(habit);
    final vibrationType = habit.timeBound?.vibrationType;
    final platformDetails = _getPlatformDetails(
      customSoundPath: customSoundPath,
      vibrationType: vibrationType,
    );
    await _plugin.zonedSchedule(
      _habitSnoozeId(habit, iso),
      'Habit reminder',
      habit.name,
      when,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ---------------------------------------------------------------------------
  // Geofence auto-completion notifications
  // ---------------------------------------------------------------------------

  static NotificationDetails _geofenceCompletionDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'geofence_completions',
        'Location completions',
        channelDescription: 'Notifications when a habit is auto-completed by location',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  static Future<void> showGeofenceCompletionNotification({
    required String habitId,
    required String habitName,
    required String boardId,
    required String componentId,
  }) async {
    debugPrint('[Notification] showGeofenceCompletionNotification: habitName=$habitName');
    if (kIsWeb) return;
    await ensureInitialized();

    final payload = jsonEncode({
      'type': 'geofence_completion',
      'habitId': habitId,
      'boardId': boardId,
      'componentId': componentId,
    });

    await _plugin.show(
      _stableId('geofence:$habitId'),
      'You completed "$habitName"!',
      'Tell us how it went.',
      _geofenceCompletionDetails(),
      payload: payload,
    );
  }
}

