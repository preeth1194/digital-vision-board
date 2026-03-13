import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/app_typography.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: AppColors.skyDecoration(isDark: isDark),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Terms & Conditions'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            Text('Terms & Conditions', style: AppTypography.heading1(context)),
            const SizedBox(height: 8),
            Text(
              'Last updated: March 2026',
              style: AppTypography.secondary(context),
            ),
            const SizedBox(height: 24),
            _section(
              context,
              title: 'Acceptance of Terms',
              body:
                  'By using Digital Vision Board, you agree to these terms. '
                  'If you do not agree, please do not use the app.',
            ),
            _section(
              context,
              title: 'Use of the App',
              body:
                  'You agree to use the app lawfully and responsibly. You must '
                  'not misuse, disrupt, or attempt unauthorized access to the app '
                  'or related services.',
            ),
            _section(
              context,
              title: 'Accounts and Guest Access',
              body:
                  'You may use the app as a guest or sign in with supported '
                  'providers. You are responsible for activities under your '
                  'account or guest profile on your device.',
            ),
            _section(
              context,
              title: 'Content and Data',
              body:
                  'You retain ownership of your personal content (habits, '
                  'journal entries, routines, and related data). You grant us a '
                  'limited license to process this data solely to operate and '
                  'improve app features.',
            ),
            _section(
              context,
              title: 'Subscriptions and Ads',
              body:
                  'Some features may require subscriptions, and free-tier use may '
                  'include ads. Billing terms for subscriptions are managed by the '
                  'platform app store and may be subject to its policies.',
            ),
            _section(
              context,
              title: 'Disclaimers',
              body:
                  'The app is provided "as is" without warranties of any kind. '
                  'Digital Vision Board is a productivity and wellness tool and is '
                  'not a medical or emergency service.',
            ),
            _section(
              context,
              title: 'Limitation of Liability',
              body:
                  'To the maximum extent permitted by law, we are not liable for '
                  'indirect, incidental, or consequential damages arising from use '
                  'of the app.',
            ),
            _section(
              context,
              title: 'Changes to Terms',
              body:
                  'We may update these terms from time to time. Continued use of '
                  'the app after updates constitutes acceptance of the revised '
                  'terms.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static Widget _section(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.heading3(context),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTypography.bodySmall(context).copyWith(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
