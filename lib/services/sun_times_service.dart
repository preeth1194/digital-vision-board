import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for calculating sunrise and sunset times based on location.
class SunTimesService {
  static const String _latKey = 'sun_times_lat';
  static const String _lngKey = 'sun_times_lng';
  static const String _locationNameKey = 'sun_times_location_name';

  /// Cached location
  static double? _cachedLat;
  static double? _cachedLng;
  static String? _cachedLocationName;

  /// Get current location and cache it
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('SunTimesService: Location services are disabled');
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('SunTimesService: Location permissions denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('SunTimesService: Location permissions permanently denied');
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      // Cache the location
      _cachedLat = position.latitude;
      _cachedLng = position.longitude;

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, position.latitude);
      await prefs.setDouble(_lngKey, position.longitude);

      return position;
    } catch (e) {
      debugPrint('SunTimesService: Error getting location: $e');
      return null;
    }
  }

  /// Get cached or stored location
  static Future<({double lat, double lng})?> getStoredLocation({SharedPreferences? prefs}) async {
    if (_cachedLat != null && _cachedLng != null) {
      return (lat: _cachedLat!, lng: _cachedLng!);
    }

    prefs ??= await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);

    if (lat != null && lng != null) {
      _cachedLat = lat;
      _cachedLng = lng;
      return (lat: lat, lng: lng);
    }

    return null;
  }

  /// Clear cached location to force a refresh
  static void clearCachedLocation() {
    _cachedLat = null;
    _cachedLng = null;
  }

  /// Force refresh location and get new sun times
  static Future<({DateTime sunrise, DateTime sunset})?> refreshLocationAndGetSunTimes({
    required DateTime date,
    SharedPreferences? prefs,
  }) async {
    // Clear cache to force fresh location
    clearCachedLocation();
    
    // Get fresh location
    final position = await getCurrentLocation();
    
    if (position == null) {
      // Try stored location as fallback
      final stored = await getStoredLocation(prefs: prefs);
      if (stored != null) {
        return calculateSunTimes(
          date: date,
          latitude: stored.lat,
          longitude: stored.lng,
        );
      }
      return null;
    }
    
    return calculateSunTimes(
      date: date,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Get stored location name
  static Future<String?> getStoredLocationName({SharedPreferences? prefs}) async {
    if (_cachedLocationName != null) {
      return _cachedLocationName;
    }

    prefs ??= await SharedPreferences.getInstance();
    _cachedLocationName = prefs.getString(_locationNameKey);
    return _cachedLocationName;
  }

  /// Set location name
  static Future<void> setLocationName(String name, {SharedPreferences? prefs}) async {
    _cachedLocationName = name;
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_locationNameKey, name);
  }

  /// Calculate sunrise and sunset times for a given date and location
  /// Returns (sunrise, sunset) as DateTime objects
  static ({DateTime sunrise, DateTime sunset}) calculateSunTimes({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    // Algorithm based on NOAA Solar Calculator
    // https://www.esrl.noaa.gov/gmd/grad/solcalc/

    final dayOfYear = _dayOfYear(date);
    final year = date.year;

    // Fractional year (gamma) in radians
    final gamma = (2 * math.pi / 365) * (dayOfYear - 1 + (12 - 12) / 24);

    // Equation of time (in minutes)
    final eqTime = 229.18 * (0.000075 + 0.001868 * math.cos(gamma) - 
        0.032077 * math.sin(gamma) - 0.014615 * math.cos(2 * gamma) - 
        0.040849 * math.sin(2 * gamma));

    // Solar declination (in radians)
    final decl = 0.006918 - 0.399912 * math.cos(gamma) + 
        0.070257 * math.sin(gamma) - 0.006758 * math.cos(2 * gamma) + 
        0.000907 * math.sin(2 * gamma) - 0.002697 * math.cos(3 * gamma) + 
        0.00148 * math.sin(3 * gamma);

    // Hour angle for sunrise/sunset
    final latRad = latitude * math.pi / 180;
    final zenith = 90.833 * math.pi / 180; // Official zenith

    final cosHA = (math.cos(zenith) / (math.cos(latRad) * math.cos(decl))) - 
        (math.tan(latRad) * math.tan(decl));

    // Clamp to valid range for acos
    final clampedCosHA = cosHA.clamp(-1.0, 1.0);
    final ha = math.acos(clampedCosHA) * 180 / math.pi;

    // Calculate sunrise and sunset times in minutes from midnight UTC
    final sunriseMinutesUTC = 720 - 4 * (longitude + ha) - eqTime;
    final sunsetMinutesUTC = 720 - 4 * (longitude - ha) - eqTime;

    // Convert to local time
    final localOffset = date.timeZoneOffset.inMinutes;
    var sunriseMinutesLocal = sunriseMinutesUTC + localOffset;
    var sunsetMinutesLocal = sunsetMinutesUTC + localOffset;

    // Normalize to 0-1440 range (handle day boundary crossings)
    sunriseMinutesLocal = sunriseMinutesLocal % 1440;
    if (sunriseMinutesLocal < 0) sunriseMinutesLocal += 1440;
    sunsetMinutesLocal = sunsetMinutesLocal % 1440;
    if (sunsetMinutesLocal < 0) sunsetMinutesLocal += 1440;

    // Create DateTime objects
    final sunriseHour = (sunriseMinutesLocal ~/ 60).clamp(0, 23);
    final sunriseMin = (sunriseMinutesLocal % 60).round().clamp(0, 59);
    final sunsetHour = (sunsetMinutesLocal ~/ 60).clamp(0, 23);
    final sunsetMin = (sunsetMinutesLocal % 60).round().clamp(0, 59);

    final sunrise = DateTime(year, date.month, date.day, sunriseHour, sunriseMin);
    final sunset = DateTime(year, date.month, date.day, sunsetHour, sunsetMin);

    return (sunrise: sunrise, sunset: sunset);
  }

  /// Get sunrise/sunset for a date using stored or provided location
  static Future<({DateTime sunrise, DateTime sunset})?> getSunTimes({
    required DateTime date,
    SharedPreferences? prefs,
  }) async {
    final location = await getStoredLocation(prefs: prefs);
    
    if (location == null) {
      // Try to get current location
      final position = await getCurrentLocation();
      if (position == null) {
        // Return default times (6:00 AM / 6:00 PM) if no location available
        return (
          sunrise: DateTime(date.year, date.month, date.day, 6, 0),
          sunset: DateTime(date.year, date.month, date.day, 18, 0),
        );
      }
      return calculateSunTimes(
        date: date,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }

    return calculateSunTimes(
      date: date,
      latitude: location.lat,
      longitude: location.lng,
    );
  }

  /// Get default sun times without location (fallback)
  static ({DateTime sunrise, DateTime sunset}) getDefaultSunTimes(DateTime date) {
    return (
      sunrise: DateTime(date.year, date.month, date.day, 6, 0),
      sunset: DateTime(date.year, date.month, date.day, 18, 0),
    );
  }

  /// Calculate day of year (1-365/366)
  static int _dayOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    return date.difference(firstDay).inDays + 1;
  }

  /// Format time as string (e.g., "6:45 AM")
  static String formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final isPM = hour >= 12;
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    final ampm = isPM ? 'PM' : 'AM';
    return '$hour12:$minuteStr $ampm';
  }

  /// Calculate day progress (0.0 to 1.0) between sunrise and sunset
  static double getDayProgress({
    required DateTime currentTime,
    required DateTime sunrise,
    required DateTime sunset,
  }) {
    if (currentTime.isBefore(sunrise)) return 0.0;
    if (currentTime.isAfter(sunset)) return 1.0;

    final totalMinutes = sunset.difference(sunrise).inMinutes;
    final elapsedMinutes = currentTime.difference(sunrise).inMinutes;

    if (totalMinutes <= 0) return 0.5;
    return (elapsedMinutes / totalMinutes).clamp(0.0, 1.0);
  }
}
