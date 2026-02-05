import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../utils/app_typography.dart';
import '../services/dv_auth_service.dart';
import '../services/app_settings_service.dart';
import '../widgets/dialogs/home_screen_widget_instructions_sheet.dart';
import 'music_provider_settings_screen.dart';

final class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _gender = 'prefer_not_to_say';
  ThemeMode _themeMode = ThemeMode.system;
  String? _customAlarmSoundPath;

  @override
  void initState() {
    super.initState();
    _load();
    // Listen to custom alarm sound path changes
    AppSettingsService.customAlarmSoundPath.addListener(_onCustomSoundChanged);
  }

  @override
  void dispose() {
    AppSettingsService.customAlarmSoundPath.removeListener(_onCustomSoundChanged);
    super.dispose();
  }

  void _onCustomSoundChanged() {
    if (mounted) {
      setState(() {
        _customAlarmSoundPath = AppSettingsService.customAlarmSoundPath.value;
      });
    }
  }

  Future<void> _load() async {
    final g = await DvAuthService.getGender();
    final mode = AppSettingsService.themeMode.value;
    final soundPath = AppSettingsService.customAlarmSoundPath.value;
    if (!mounted) return;
    setState(() {
      _gender = g;
      _themeMode = mode;
      _customAlarmSoundPath = soundPath;
    });
  }

  String _genderLabel(String v) {
    switch (v) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'non_binary':
        return 'Non-binary';
      default:
        return 'Prefer not to say';
    }
  }

  Future<void> _pickGender() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('Gender', style: AppTypography.heading3(context)),
            const SizedBox(height: 8),
            for (final v in const ['prefer_not_to_say', 'male', 'female', 'non_binary'])
              RadioListTile<String>(
                value: v,
                groupValue: _gender,
                title: Text(_genderLabel(v)),
                onChanged: (x) => Navigator.of(ctx).pop(x),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _gender = selected);
    await DvAuthService.setGender(selected);
    await DvAuthService.putUserSettings(gender: selected);
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> _pickThemeMode() async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('Theme', style: AppTypography.heading3(context)),
            const SizedBox(height: 8),
            for (final v in const [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
              RadioListTile<ThemeMode>(
                value: v,
                groupValue: _themeMode,
                title: Text(_themeModeLabel(v)),
                onChanged: (x) => Navigator.of(ctx).pop(x),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _themeMode = selected);
    await AppSettingsService.setThemeMode(selected);
  }

  Future<void> _pickAlarmSound() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      if (File(filePath).existsSync()) {
        await AppSettingsService.setCustomAlarmSound(filePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Alarm sound set: ${path.basename(filePath)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAlarmSound() async {
    await AppSettingsService.setCustomAlarmSound(null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alarm sound reset to default'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _getAlarmSoundDisplayName() {
    if (_customAlarmSoundPath == null) {
      return 'Default';
    }
    return path.basename(_customAlarmSoundPath!);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Appearance'),
            subtitle: Text(_themeModeLabel(_themeMode)),
            onTap: _pickThemeMode,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Gender (for recommendations)'),
            subtitle: Text(_genderLabel(_gender)),
            onTap: _pickGender,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Reminder Sound'),
            subtitle: Text(_getAlarmSoundDisplayName()),
            trailing: _customAlarmSoundPath != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearAlarmSound,
                    tooltip: 'Clear custom sound',
                  )
                : null,
            onTap: _pickAlarmSound,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('Add home-screen widget'),
            subtitle: const Text('See step-by-step instructions'),
            onTap: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  showHomeScreenWidgetInstructionsSheet(context);
                }
              });
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Music Provider Settings'),
            subtitle: const Text('Configure Spotify or Apple Music for rhythmic timers'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MusicProviderSettingsScreen()),
              );
            },
          ),
          const Divider(height: 0),
        ],
      ),
    );
  }
}

