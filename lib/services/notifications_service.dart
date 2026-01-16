import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/habit_item.dart';

class NotificationsService {
  NotificationsService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (kIsWeb) return;

    tz.initializeTimeZones();
    // Use device local timezone as default.
    tz.setLocalLocation(tz.getLocation(tz.local.name));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(initSettings);
    _initialized = true;
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

  static const _channel = AndroidNotificationDetails(
    'habit_reminders',
    'Habit reminders',
    channelDescription: 'Reminders for scheduled habits',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _platformDetails = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );

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

    final freq = (habit.frequency ?? '').trim().toLowerCase();
    if (freq == 'weekly' && habit.weeklyDays.isNotEmpty) {
      for (final wd in habit.weeklyDays.toSet()) {
        final when = _nextInstanceForWeekday(time, wd);
        await _plugin.zonedSchedule(
          _habitReminderId(habit, weekday: wd),
          'Habit reminder',
          habit.name,
          when,
          _platformDetails,
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
      _platformDetails,
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
    await _plugin.zonedSchedule(
      _habitSnoozeId(habit, iso),
      'Habit reminder',
      habit.name,
      when,
      _platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}

