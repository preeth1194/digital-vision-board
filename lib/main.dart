import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
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
import 'services/ad_service.dart';
import 'services/affirmation_service.dart';
import 'services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Read before recording so we can distinguish new vs existing users for onboarding.
  final existingUser = prefs.getInt('dv_first_install_ms_v1') != null;
  await DvAuthService.ensureFirstInstallRecorded(prefs: prefs);
  await AppSettingsService.load(prefs: prefs);
  await LogicalDateService.ensureInitialized(prefs: prefs);
  // Best-effort: keep home-screen widgets up-to-date (snapshot + deep-link toggles).
  unawaited(HabitProgressWidgetSnapshotService.refreshBestEffort(prefs: prefs));
  unawaited(PuzzleWidgetSnapshotService.refreshBestEffort(prefs: prefs));
  await WidgetDeepLinkService.start();
  HabitProgressWidgetActionQueueService.instance.start();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Non-fatal: app can still run without Firebase configured.
  }
  // Lazy prefetch: do not block app startup (keeps loading screens minimal).
  unawaited(WizardDefaultsService.prefetchDefaults(prefs: prefs));
  // Initialize notifications early so tap handler is wired before any notification arrives.
  try {
    await NotificationsService.ensureInitialized();
  } catch (_) {
    // Non-fatal: app can still run without notifications.
  }
  // Lazy start geofence tracking from local storage (best-effort).
  unawaited(HabitGeofenceTrackingService.instance.bootstrapFromStorage(prefs: prefs).catchError((_) {}));
  // Initialize ads and subscriptions (best-effort, non-blocking).
  unawaited(AdService.initialize().catchError((_) {}));
  unawaited(SubscriptionService.initialize(prefs: prefs).catchError((_) {}));
  unawaited(AffirmationService.seedDefaultsIfEmpty(prefs: prefs));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Existing users skip onboarding; new users see it.
  final onboardingDone = await isOnboardingCompleted(prefs: prefs);
  final showOnboarding = !onboardingDone && !existingUser;
  if (!onboardingDone && existingUser) {
    await markOnboardingCompleted(prefs: prefs);
  }

  runApp(DigitalVisionBoardApp(showOnboarding: showOnboarding));
}

class DigitalVisionBoardApp extends StatelessWidget {
  const DigitalVisionBoardApp({super.key, this.showOnboarding = false});

  final bool showOnboarding;

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
            scaffoldBackgroundColor: AppColors.skyGradientTopLight,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.darkest,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
            ),
            cardTheme: CardThemeData(
              color: AppColors.cloudLight,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.08),
            ),
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
            scaffoldBackgroundColor: AppColors.skyGradientTopDark,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.darkScheme.onSurface,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
            ),
            cardTheme: CardThemeData(
              color: AppColors.cloudDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: AppColors.cloudBorderDark,
                  width: 0.5,
                ),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.3),
            ),
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
              bodyColor: AppColors.darkScheme.onSurface,
              displayColor: AppColors.darkScheme.onSurface,
            ),
          ),
          themeMode: mode,
          home: showOnboarding
              ? const OnboardingScreen()
              : const DashboardScreen(),
        );
      },
    );
  }
}
