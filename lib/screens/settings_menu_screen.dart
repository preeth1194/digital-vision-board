import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auto_sync_service.dart';
import '../services/dv_auth_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_typography.dart';
import '../widgets/profile_avatar.dart';
import 'backup_restore_screen.dart';
import 'contact_us_screen.dart';
import 'faq_screen.dart';
import 'my_issues_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'presets/preset_shop_screen.dart';
import 'privacy_policy_screen.dart';
import 'report_issue_screen.dart';
import 'subscription_screen.dart';
import 'widget_guide_screen.dart';

class SettingsMenuScreen extends StatefulWidget {
  const SettingsMenuScreen({
    super.key,
    required this.prefs,
    required this.onOpenAccount,
    required this.onSignOut,
  });

  final SharedPreferences? prefs;
  final Future<void> Function() onOpenAccount;
  final Future<void> Function() onSignOut;

  @override
  State<SettingsMenuScreen> createState() => _SettingsMenuScreenState();
}

class _SettingsMenuScreenState extends State<SettingsMenuScreen> {
  bool _busy = false;

  Future<_MenuProfile> _loadProfile() async {
    final userId = await DvAuthService.getUserId(prefs: widget.prefs);
    final isGuest = (userId ?? '').trim().isEmpty;
    final displayName = isGuest
        ? 'Guest session'
        : (await DvAuthService.getDisplayName(prefs: widget.prefs)) ?? 'Signed in';
    final picPath = await DvAuthService.getProfilePicPath(prefs: widget.prefs);
    final safeName = displayName.trim();
    final initial = safeName.isEmpty ? '?' : safeName.substring(0, 1).toUpperCase();
    return _MenuProfile(
      isGuest: isGuest,
      displayName: safeName.isEmpty ? 'Guest session' : safeName,
      initial: initial,
      picPath: (picPath ?? '').trim().isEmpty ? null : picPath,
    );
  }

  Future<void> _runAccountFlow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onOpenAccount();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runSignOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dcs = Theme.of(context).colorScheme;
    final isDark = dcs.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dcs.surface,
      appBar: AppBar(
        title: Text(
          'Settings and activity',
          style: AppTypography.heading3(context),
        ),
        backgroundColor: dcs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<_MenuProfile>(
        future: _loadProfile(),
        builder: (context, snap) {
          final profile = snap.data ??
              const _MenuProfile(
                isGuest: true,
                displayName: 'Guest session',
                initial: '?',
                picPath: null,
              );
          return Container(
            decoration: AppColors.skyDecoration(isDark: isDark),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
              const SizedBox(height: AppSpacing.md),
              const _SectionHeader('Account'),
              _ProfileListItem(
                profile: profile,
                busy: _busy,
                onTap: _runAccountFlow,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: SubscriptionService.isSubscribed,
                builder: (context, subscribed, _) => _MenuRow(
                  icon: subscribed ? Icons.workspace_premium_rounded : Icons.workspace_premium_outlined,
                  label: subscribed ? 'Premium Active' : 'Go Premium',
                  subtitle: subscribed ? 'Manage your subscription plan' : null,
                  onTap: () => _open(const SubscriptionScreen()),
                ),
              ),
              ValueListenableBuilder<SyncState>(
                valueListenable: AutoSyncService.state,
                builder: (context, syncState, _) {
                  return FutureBuilder<bool>(
                    future: GoogleDriveBackupService.isLinked(prefs: widget.prefs),
                    builder: (context, linkedSnap) {
                      final linked = linkedSnap.data ?? false;
                      final subtitle = !linked
                          ? 'Tap to link Google account'
                          : switch (syncState) {
                              SyncState.syncing => 'Syncing now',
                              SyncState.error => 'Sync failed, tap to retry',
                              _ => AutoSyncService.lastSyncText,
                            };
                      final icon = !linked
                          ? Icons.cloud_off_outlined
                          : switch (syncState) {
                              SyncState.syncing => Icons.cloud_sync_outlined,
                              SyncState.error => Icons.cloud_off_outlined,
                              _ => Icons.cloud_done_outlined,
                            };
                      return _MenuRow(
                        icon: icon,
                        label: linked ? 'Backup and sync' : 'Backup not set up',
                        subtitle: subtitle,
                        onTap: () => _open(const BackupRestoreScreen()),
                      );
                    },
                  );
                },
              ),
              if (!profile.isGuest)
                _MenuRow(
                  icon: Icons.logout,
                  label: 'Sign out',
                  onTap: _runSignOut,
                ),
              
              const SizedBox(height: AppSpacing.md),
              const _SectionHeader('Tools'),
              _MenuRow(
                icon: Icons.storefront_outlined,
                label: 'Preset Shop',
                onTap: () => _open(const PresetShopScreen()),
              ),
              _MenuRow(
                icon: Icons.widgets_outlined,
                label: 'Widget Guide',
                onTap: () => _open(const WidgetGuideScreen()),
              ),
              _MenuRow(
                icon: Icons.info_outline,
                label: 'App Tour',
                onTap: () => _open(const OnboardingScreen(replayMode: true)),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SectionHeader('Help'),
              _MenuRow(
                icon: Icons.bug_report_outlined,
                label: 'Report Issue',
                onTap: () => _open(const ReportIssueScreen()),
              ),
              _MenuRow(
                icon: Icons.mail_outline,
                label: 'Contact Us',
                onTap: () => _open(const ContactUsScreen()),
              ),
              _MenuRow(
                icon: Icons.assignment_outlined,
                label: 'My Issues',
                onTap: () => _open(const MyIssuesScreen()),
              ),
              _MenuRow(
                icon: Icons.help_outline,
                label: 'FAQ',
                onTap: () => _open(const FaqScreen()),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SectionHeader('Legal'),
              _MenuRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => _open(const PrivacyPolicyScreen()),
              ),
            ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.busy,
    required this.onTap,
  });

  final _MenuProfile profile;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dcs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: busy ? null : onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dcs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dcs.outline.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            ProfileAvatar(initial: profile.initial, imagePath: profile.picPath, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w700, color: dcs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.isGuest ? 'Sign In / Sign Up' : 'View Profile',
                    style: AppTypography.caption(context).copyWith(color: dcs.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: dcs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ProfileListItem extends StatelessWidget {
  const _ProfileListItem({
    required this.profile,
    required this.busy,
    required this.onTap,
  });

  final _MenuProfile profile;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dcs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      minVerticalPadding: 4,
      visualDensity: VisualDensity.standard,
      leading: ProfileAvatar(
        initial: profile.initial,
        imagePath: profile.picPath,
        radius: 20,
      ),
      title: Text(
        profile.displayName,
        style: AppTypography.bodySmall(context).copyWith(
          color: dcs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        profile.isGuest ? 'Sign In / Sign Up' : 'View Profile',
        style: AppTypography.caption(context).copyWith(
          color: dcs.onSurfaceVariant,
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 22, color: dcs.onSurfaceVariant),
      onTap: busy ? null : onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final dcs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, AppSpacing.sm),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(color: dcs.onSurfaceVariant, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dcs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      minVerticalPadding: 4,
      visualDensity: VisualDensity.standard,
      leading: Icon(icon, size: 24, color: dcs.onSurfaceVariant),
      title: Text(
        label,
        style: AppTypography.bodySmall(context).copyWith(
          color: dcs.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.caption(context).copyWith(color: dcs.onSurfaceVariant),
            ),
      trailing: Icon(Icons.chevron_right, size: 22, color: dcs.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _MenuProfile {
  const _MenuProfile({
    required this.isGuest,
    required this.displayName,
    required this.initial,
    required this.picPath,
  });

  final bool isGuest;
  final String displayName;
  final String initial;
  final String? picPath;
}
