import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class AppSettingsService {
  AppSettingsService._();

  static const String _themeModeKey = 'dv_theme_mode_v1'; // system|light|dark

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

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

  static Future<void> load({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_themeModeKey) ?? 'system';
    themeMode.value = _parseThemeMode(raw);
  }

  static Future<void> setThemeMode(ThemeMode mode, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_themeModeKey, _serializeThemeMode(mode));
    themeMode.value = mode;
  }
}

