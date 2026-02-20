import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_typography.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.skyGradient(isDark: isDark),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Privacy Policy'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            Text('Privacy Policy', style: AppTypography.heading1(context)),
            const SizedBox(height: 6),
            Text(
              'Last updated: February 2026',
              style: AppTypography.secondary(context),
            ),
            const SizedBox(height: 24),
            _section(
              context,
              title: 'Information We Collect',
              body:
                  'We collect information you provide directly, such as your '
                  'name, profile picture, and habit data. We also collect device '
                  'information and usage analytics to improve the app experience.',
            ),
            _section(
              context,
              title: 'How We Use Your Information',
              body:
                  'Your information is used to provide and personalise the app, '
                  'sync your data across devices, send reminders you have opted '
                  'into, and improve our services. We do not sell your personal '
                  'information to third parties.',
            ),
            _section(
              context,
              title: 'Data Storage & Security',
              body:
                  'Your data is stored securely using encrypted connections. '
                  'If you enable Google Drive backup, your data is encrypted '
                  'before being uploaded. We use industry-standard security '
                  'measures to protect your information.',
            ),
            _section(
              context,
              title: 'Third-Party Services',
              body:
                  'The app may use third-party services such as Firebase for '
                  'authentication and analytics, Google Drive for backups, and '
                  'ad networks for free-tier users. Each third-party service '
                  'has its own privacy policy governing the use of your data.',
            ),
            _section(
              context,
              title: 'Your Rights',
              body:
                  'You can request deletion of your account and associated data '
                  'at any time by contacting us. You may also export your data '
                  'through the backup feature before deleting your account.',
            ),
            _section(
              context,
              title: 'Changes to This Policy',
              body:
                  'We may update this privacy policy from time to time. We will '
                  'notify you of any material changes through the app. Continued '
                  'use of the app after changes constitutes acceptance of the '
                  'updated policy.',
            ),
            _section(
              context,
              title: 'Contact Us',
              body:
                  'If you have questions or concerns about this privacy policy, '
                  'please reach out to us through the app\'s support channels.',
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
          const SizedBox(height: 6),
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
