import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'dv_auth_service.dart';

/// Computes the app's "logical day" using a fixed home timezone.
///
/// Home timezone source:
/// - Stored locally via `DvAuthService.setHomeTimezone(...)`
/// - Falls back to device timezone when missing/invalid.
final class LogicalDateService {
  LogicalDateService._();

  static bool _initialized = false;
  static tz.Location _homeLocation = tz.local;

  static Future<void> ensureInitialized({SharedPreferences? prefs}) async {
    tz_data.initializeTimeZones();
    final p = prefs ?? await SharedPreferences.getInstance();
    await reloadHomeTimezone(prefs: p);
    _initialized = true;
  }

  static Future<void> reloadHomeTimezone({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final homeTz = await DvAuthService.getHomeTimezone(prefs: p);
    if (homeTz != null) {
      try {
        _homeLocation = tz.getLocation(homeTz);
        return;
      } catch (_) {
        // fallthrough
      }
    }
    _homeLocation = tz.local;
  }

  static tz.Location get homeLocation => _homeLocation;

  static DateTime now() {
    return tz.TZDateTime.now(_homeLocation);
  }

  static DateTime today() {
    final n = tz.TZDateTime.now(_homeLocation);
    return tz.TZDateTime(_homeLocation, n.year, n.month, n.day);
  }

  static String isoToday() {
    final d = today();
    return toIsoDate(d);
  }

  static String toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static DateTime parseIsoDate(String iso) {
    // ISO date-only parses in local time; we only use year/month/day.
    final d = DateTime.parse(iso);
    return DateTime(d.year, d.month, d.day);
  }
}

