import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';
import '../widgets/terms_consent_layout.dart';
import 'dashboard_screen.dart';

const _legalConsentAcceptedKey = 'legal_consent_accepted_v1';

Future<bool> isLegalConsentAccepted({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  return p.getBool(_legalConsentAcceptedKey) ?? false;
}

Future<void> markLegalConsentAccepted({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  await p.setBool(_legalConsentAcceptedKey, true);
}

class LegalConsentScreen extends StatelessWidget {
  const LegalConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.sproutGreen,
        body: TermsConsentLayout(
          onAcceptComplete: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          },
        ),
      ),
    );
  }
}
