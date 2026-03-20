import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/legal_consent_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/habit_geofence_tracking_service.dart';
import 'services/dv_auth_service.dart';
import 'services/app_settings_service.dart';
import 'services/logical_date_service.dart';
import 'services/habit_progress_widget_snapshot_service.dart';
import 'utils/app_colors.dart';
import 'services/widget_deeplink_service.dart';
import 'services/habit_progress_widget_action_queue_service.dart';
import 'services/notifications_service.dart';
import 'services/wizard_defaults_service.dart';
import 'services/ad_service.dart';
import 'services/affirmation_service.dart';
import 'services/subscription_service.dart';
import 'utils/app_spacing.dart';

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
  final legalConsentAccepted = await isLegalConsentAccepted(prefs: prefs);
  final showOnboarding = !onboardingDone && !existingUser;
  if (!onboardingDone && existingUser) {
    await markOnboardingCompleted(prefs: prefs);
  }

  runApp(
    DigitalVisionBoardApp(
      showOnboarding: showOnboarding,
      legalConsentAccepted: legalConsentAccepted,
    ),
  );
}

class DigitalVisionBoardApp extends StatelessWidget {
  const DigitalVisionBoardApp({
    super.key,
    this.showOnboarding = false,
    this.legalConsentAccepted = false,
  });

  final bool showOnboarding;
  final bool legalConsentAccepted;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final textTheme = GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        displaySmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.cloudDark : AppColors.cloudWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.30)
            : AppColors.forestDeep.withValues(alpha: 0.07),
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusChip),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: textTheme.bodySmall ?? const TextStyle(fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }

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
          theme: _buildTheme(colorScheme: AppColors.lightScheme, isDark: false),
          darkTheme: _buildTheme(colorScheme: AppColors.darkScheme, isDark: true),
          themeMode: mode,
          home: showOnboarding
              ? const OnboardingScreen()
              : (!legalConsentAccepted
                    ? const LegalConsentScreen()
                    : const DashboardScreen()),
        );
      },
    );
  }
}
