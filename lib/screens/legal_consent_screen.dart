import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';
import '../utils/app_typography.dart';
import 'dashboard_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_and_conditions_screen.dart';

const _legalConsentAcceptedKey = 'legal_consent_accepted_v1';

Future<bool> isLegalConsentAccepted({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  return p.getBool(_legalConsentAcceptedKey) ?? false;
}

Future<void> markLegalConsentAccepted({SharedPreferences? prefs}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  await p.setBool(_legalConsentAcceptedKey, true);
}

class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _acceptAndContinue() async {
    if (!_agreed || _saving) return;
    setState(() => _saving = true);
    await markLegalConsentAccepted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Container(
        decoration: AppColors.skyDecoration(isDark: isDark),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Before You Continue',
                            style: AppTypography.heading2(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please review and accept our Terms & Conditions and Privacy Policy. '
                            'This is required to use the app.',
                            style: AppTypography.bodySmall(context).copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TermsAndConditionsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Read Terms & Conditions'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicyScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.privacy_tip_outlined),
                            label: const Text('Read Privacy Policy'),
                          ),
                          const SizedBox(height: 14),
                          CheckboxListTile(
                            value: _agreed,
                            onChanged: (value) {
                              setState(() => _agreed = value ?? false);
                            },
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              'I agree to the Terms & Conditions and Privacy Policy.',
                              style: AppTypography.bodySmall(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed:
                                (_agreed && !_saving) ? _acceptAndContinue : null,
                            child: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Agree and Continue'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
