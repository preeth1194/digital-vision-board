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

  static AndroidNotificationDetails _getAndroidChannel({String? customSoundPath}) {
    return AndroidNotificationDetails(
      'habit_reminders',
      'Habit reminders',
      channelDescription: 'Reminders for scheduled habits',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      sound: customSoundPath != null
          ? UriAndroidNotificationSound('file://$customSoundPath')
          : null, // null means use default system sound
    );
  }

  static NotificationDetails _getPlatformDetails({String? customSoundPath}) {
    return NotificationDetails(
      android: _getAndroidChannel(customSoundPath: customSoundPath),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: customSoundPath,
        // Note: InterruptionLevel.critical requires a Critical Alerts entitlement from Apple.
        // This entitlement must be requested from Apple and requires justification.
        // Users must grant permission in iOS Settings > Notifications > [App Name] > Critical Alerts.
        // Without the entitlement, this will fall back to a lower interruption level.
        interruptionLevel: InterruptionLevel.critical,
      ),
    );
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

  static Future<void> scheduleHabitReminders(HabitItem habit) async {
    if (kIsWeb) return;
    await ensureInitialized();

    if (!habit.reminderEnabled || habit.reminderMinutes == null) {
      await cancelHabitReminders(habit);
      return;
    }

    final minutes = habit.reminderMinutes!;
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

    // Clear any older schedules first
    await cancelHabitReminders(habit);

    final customSoundPath = AppSettingsService.customAlarmSoundPath.value;
    final platformDetails = _getPlatformDetails(customSoundPath: customSoundPath);

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
    final customSoundPath = AppSettingsService.customAlarmSoundPath.value;
    final platformDetails = _getPlatformDetails(customSoundPath: customSoundPath);
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

