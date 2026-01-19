import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:firebase_core/firebase_core.dart';
import 'config/app_theme.dart';
import 'screens/board/vision_board_home_screen.dart';
import 'services/habits/habit_geofence_tracking_service.dart';
import 'services/auth/dv_auth_service.dart';
import 'services/utils/app_settings_service.dart';
import 'services/utils/logical_date_service.dart';
import 'services/widgets/habit_progress_widget_snapshot_service.dart';
import 'services/widgets/widget_deeplink_service.dart';
import 'services/widgets/habit_progress_widget_action_queue_service.dart';
import 'services/board/wizard_defaults_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await DvAuthService.ensureFirstInstallRecorded(prefs: prefs);
  await AppSettingsService.load(prefs: prefs);
  await LogicalDateService.ensureInitialized(prefs: prefs);
  // Best-effort: keep home-screen widgets up-to-date (snapshot + deep-link toggles).
  unawaited(HabitProgressWidgetSnapshotService.refreshBestEffort(prefs: prefs));
  unawaited(WidgetDeepLinkService.start());
  HabitProgressWidgetActionQueueService.instance.start();
  // Firebase is optional at runtime until platform config files are added.
  // (google-services.json / GoogleService-Info.plist via FlutterFire.)
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Non-fatal: app can still run without Firebase configured.
  }
  // Lazy prefetch: do not block app startup (keeps loading screens minimal).
  unawaited(WizardDefaultsService.prefetchDefaults(prefs: prefs));
  // Lazy start geofence tracking from local storage (best-effort).
  unawaited(HabitGeofenceTrackingService.instance.bootstrapFromStorage(prefs: prefs));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const DigitalVisionBoardApp());
}

class DigitalVisionBoardApp extends StatelessWidget {
  const DigitalVisionBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettingsService.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Digital Vision Board',
          localizationsDelegates: quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          theme: AppTheme.buildLightTheme(),
          darkTheme: AppTheme.buildDarkTheme(),
          themeMode: mode,
          home: const VisionBoardHomeScreen(),
        );
      },
    );
  }
}
