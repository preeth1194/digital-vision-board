import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/vision_board_home_screen.dart';
import 'services/logical_date_service.dart';
import 'services/wizard_defaults_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await LogicalDateService.ensureInitialized(prefs: prefs);
  // Lazy prefetch: do not block app startup (keeps loading screens minimal).
  unawaited(WizardDefaultsService.prefetchDefaults(prefs: prefs));
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
    return MaterialApp(
      title: 'Digital Vision Board',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const VisionBoardHomeScreen(),
    );
  }
}
