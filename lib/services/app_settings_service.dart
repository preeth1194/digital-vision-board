import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MeasurementUnit { metric, imperial }

final class AppSettingsService {
  AppSettingsService._();

  static const String _themeModeKey = 'dv_theme_mode_v1'; // system|light|dark
  static const String _customAlarmSoundKey = 'dv_custom_alarm_sound_v1';
  static const String _measurementUnitKey = 'dv_measurement_unit_v1'; // metric|imperial

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final ValueNotifier<String?> customAlarmSoundPath = ValueNotifier<String?>(null);
  static final ValueNotifier<MeasurementUnit> measurementUnit =
      ValueNotifier<MeasurementUnit>(MeasurementUnit.metric);

  static ThemeMode _parseThemeMode(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static MeasurementUnit _parseMeasurementUnit(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'imperial':
        return MeasurementUnit.imperial;
      default:
        return MeasurementUnit.metric;
    }
  }

  static String _serializeMeasurementUnit(MeasurementUnit unit) {
    switch (unit) {
      case MeasurementUnit.metric:
        return 'metric';
      case MeasurementUnit.imperial:
        return 'imperial';
    }
  }

  static MeasurementUnit getMeasurementUnit() => measurementUnit.value;

  static Future<void> setMeasurementUnit(MeasurementUnit unit, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_measurementUnitKey, _serializeMeasurementUnit(unit));
    measurementUnit.value = unit;
  }

  static Future<void> load({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_themeModeKey) ?? 'system';
    themeMode.value = _parseThemeMode(raw);
    
    // Load custom alarm sound path
    final soundPath = p.getString(_customAlarmSoundKey);
    customAlarmSoundPath.value = (soundPath != null && File(soundPath).existsSync()) ? soundPath : null;

    // Load measurement unit preference
    final unitRaw = p.getString(_measurementUnitKey) ?? 'metric';
    measurementUnit.value = _parseMeasurementUnit(unitRaw);
  }

  static Future<void> setThemeMode(ThemeMode mode, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_themeModeKey, _serializeThemeMode(mode));
    themeMode.value = mode;
  }

  static Future<void> setCustomAlarmSound(String? filePath, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    if (filePath == null) {
      await p.remove(_customAlarmSoundKey);
    } else {
      await p.setString(_customAlarmSoundKey, filePath);
    }
    customAlarmSoundPath.value = (filePath != null && File(filePath).existsSync()) ? filePath : null;
  }
}

