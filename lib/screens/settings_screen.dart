import 'package:flutter/material.dart';
import '../utils/app_typography.dart';

import 'onboarding/onboarding_carousel_screen.dart';
import 'admin/templates_admin_screen.dart';
import '../services/dv_auth_service.dart';
import '../services/app_settings_service.dart';
import '../widgets/dialogs/home_screen_widget_instructions_sheet.dart';

final class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _gender = 'prefer_not_to_say';
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await DvAuthService.getGender();
    final mode = AppSettingsService.themeMode.value;
    if (!mounted) return;
    setState(() {
      _gender = g;
      _themeMode = mode;
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
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
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Admin: Templates'),
            subtitle: const Text('Publish vision board templates for users'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TemplatesAdminScreen()),
              );
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.slideshow_outlined),
            title: const Text('View onboarding'),
            subtitle: const Text('Replay the intro carousel anytime'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OnboardingCarouselScreen(
                    onFinished: (ctx) => Navigator.of(ctx).pop(),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('Add home-screen widget'),
            subtitle: const Text('See step-by-step instructions'),
            onTap: () => showHomeScreenWidgetInstructionsSheet(context),
          ),
          const Divider(height: 0),
        ],
      ),
    );
  }
}

