import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';
import 'services/habit_geofence_tracking_service.dart';
import 'services/dv_auth_service.dart';
import 'services/app_settings_service.dart';
import 'services/logical_date_service.dart';
import 'services/habit_progress_widget_snapshot_service.dart';
import 'services/puzzle_widget_snapshot_service.dart';
import 'utils/app_colors.dart';
import 'services/widget_deeplink_service.dart';
import 'services/habit_progress_widget_action_queue_service.dart';
import 'services/notifications_service.dart';
import 'services/wizard_defaults_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await DvAuthService.ensureFirstInstallRecorded(prefs: prefs);
  await AppSettingsService.load(prefs: prefs);
  await LogicalDateService.ensureInitialized(prefs: prefs);
  // Best-effort: keep home-screen widgets up-to-date (snapshot + deep-link toggles).
  unawaited(HabitProgressWidgetSnapshotService.refreshBestEffort(prefs: prefs));
  unawaited(PuzzleWidgetSnapshotService.refreshBestEffort(prefs: prefs));
  await WidgetDeepLinkService.start();
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
  // Initialize notifications early so tap handler is wired before any notification arrives.
  await NotificationsService.ensureInitialized();
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

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettingsService.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Digital Vision Board',
          localizationsDelegates: quill.FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: quill.FlutterQuillLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: AppColors.lightScheme,
            useMaterial3: true,
            textTheme: GoogleFonts.interTextTheme(
              const TextTheme(
                displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                displayMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                displaySmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ).apply(
              bodyColor: AppColors.darkest,
              displayColor: AppColors.darkest,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: AppColors.darkScheme,
            useMaterial3: true,
            textTheme: GoogleFonts.interTextTheme(
              const TextTheme(
                displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                displayMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                displaySmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ).apply(
              bodyColor: AppColors.paleGreenTint,
              displayColor: AppColors.paleGreenTint,
            ),
          ),
          themeMode: mode,
          home: const DashboardScreen(),
        );
      },
    );
  }
}
