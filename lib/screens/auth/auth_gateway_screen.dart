import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/app_settings_service.dart';
import '../../services/dv_auth_service.dart';
import '../../services/image_service.dart';
import '../../utils/app_typography.dart';
import '../../utils/measurement_utils.dart';
import '../../widgets/grid/image_source_sheet.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/rituals/habit_form_constants.dart';
import 'login_screen.dart';
import 'profile_completion_screen.dart';
import 'signup_screen.dart';
import 'phone_auth_screen.dart';

class AuthGatewayScreen extends StatefulWidget {
  final bool forced; // true when opened because guest expired

  const AuthGatewayScreen({super.key, this.forced = false});

  @override
  State<AuthGatewayScreen> createState() => _AuthGatewayScreenState();
}

class _AuthGatewayScreenState extends State<AuthGatewayScreen> {
  bool _loading = false;
  String? _error;
  int _profileDataKey = 0;

  Future<bool> _isSignedIn() async {
    final token = await DvAuthService.getDvToken();
    final userId = await DvAuthService.getUserId();
    return (token != null && token.isNotEmpty) && (userId != null && userId.isNotEmpty);
  }

  Future<void> _continueWithGoogle() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // google_sign_in v7+ uses a singleton instance (no default constructor).
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final googleUser = await googleSignIn.authenticate();
      if (googleUser == null) return; // cancelled
      final auth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final email = userCred.user?.email;
      if (email != null && email.isNotEmpty) {
        await DvAuthService.setUserDisplayInfo(email: email);
      }
      final idToken = await userCred.user?.getIdToken();
      if ((idToken ?? '').trim().isEmpty) throw Exception('Could not get Firebase idToken.');
      await DvAuthService.exchangeFirebaseIdTokenForDvToken(idToken!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueWithPhone() async {
    if (_loading) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _continueAsGuest() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await DvAuthService.continueAsGuest();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openLogin() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _openSignup() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forced = widget.forced;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        automaticallyImplyLeading: !forced,
      ),
      body: FutureBuilder<bool>(
        future: _isSignedIn(),
        builder: (context, snap) {
          final signedIn = snap.data == true;
          if (signedIn) {
            return _buildSignedInView(context, theme);
          }
          return _buildLoginView(context, theme, forced);
        },
      ),
    );
  }

  static int? _ageFromDob(String? dob) {
    if (dob == null || dob.isEmpty) return null;
    final d = DateTime.tryParse(dob);
    if (d == null) return null;
    return DateTime.now().difference(d).inDays ~/ 365;
  }

  String _genderLabel(String v) {
    switch (v) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'non_binary':
        return 'Non-binary';
      default:
        return 'Prefer not to say';
    }
  }

  Future<void> _openProfileEdit() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
    );
    if (ok == true && mounted) setState(() {});
  }

  Future<void> _changeProfilePhoto() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    final path = await ImageService.pickAndCropProfileImage(context, source: source);
    if (path != null && mounted) {
      await DvAuthService.setProfilePicPath(path);
      if (mounted) setState(() {});
    }
  }

  Widget _buildSignedInView(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(_profileDataKey),
      future: () async {
        final identifier = (await DvAuthService.getUserDisplayIdentifier())?.trim();
        final displayName = await DvAuthService.getDisplayName();
        final weight = await DvAuthService.getWeightKg();
        final height = await DvAuthService.getHeightCm();
        final gender = await DvAuthService.getGender();
        final dob = await DvAuthService.getDateOfBirth();
        final profilePicPath = await DvAuthService.getProfilePicPath();
        return {
          'identifier': identifier,
          'displayName': displayName,
          'weight': weight,
          'height': height,
          'gender': gender,
          'dob': dob,
          'profilePicPath': profilePicPath,
        };
      }(),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        final identifier = data['identifier'] as String?;
        final displayName = data['displayName'] as String?;
        final weight = data['weight'] as double?;
        final height = data['height'] as double?;
        final gender = data['gender'] as String? ?? 'prefer_not_to_say';
        final dob = data['dob'] as String?;
        final profilePicPath = data['profilePicPath'] as String?;
        final label = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : (identifier != null && identifier.isNotEmpty)
                ? 'Signed in as $identifier'
                : 'Signed in';
        final signInMethod = (identifier != null && identifier.contains('@'))
            ? 'Google'
            : (identifier != null && identifier.isNotEmpty)
                ? 'Phone'
                : 'Account';
        final initial = (displayName != null && displayName.isNotEmpty)
            ? displayName[0].toUpperCase()
            : (identifier != null && identifier.isNotEmpty)
                ? identifier[0].toUpperCase()
                : '?';
        final age = _ageFromDob(dob);
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _profileDataKey++);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
            // Profile icon and name - centered, prominent (reference layout)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  ProfileAvatar(
                    initial: initial,
                    imagePath: profilePicPath,
                    radius: 48,
                    onTap: _changeProfilePhoto,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: AppTypography.heading1(context),
                    textAlign: TextAlign.center,
                  ),
                  if (signInMethod != 'Account') ...[
                    const SizedBox(height: 2),
                    Text(
                      signInMethod,
                      style: AppTypography.bodySmall(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            CupertinoListSection.insetGrouped(
              header: Text(
                'Profile',
                style: AppTypography.caption(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              margin: EdgeInsets.zero,
              backgroundColor: colorScheme.surface,
              decoration: habitSectionDecoration(colorScheme),
              separatorColor: habitSectionSeparatorColor(colorScheme),
              children: [
                CupertinoListTile.notched(
                  leading: Icon(Icons.person_outline, color: colorScheme.onSurfaceVariant, size: 24),
                  title: Text(
                    displayName ?? 'Name',
                    style: AppTypography.body(context),
                  ),
                  trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                  onTap: _openProfileEdit,
                ),
                ValueListenableBuilder<MeasurementUnit>(
                  valueListenable: AppSettingsService.measurementUnit,
                  builder: (context, unit, _) {
                    final weightStr = weight != null
                        ? (unit == MeasurementUnit.metric
                            ? '${weight.toStringAsFixed(1)} kg'
                            : '${MeasurementUtils.kgToLb(weight).toStringAsFixed(1)} lb')
                        : 'Weight';
                    return CupertinoListTile.notched(
                      leading: Icon(Icons.monitor_weight_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                      title: Text(weightStr, style: AppTypography.body(context)),
                      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                      onTap: _openProfileEdit,
                    );
                  },
                ),
                ValueListenableBuilder<MeasurementUnit>(
                  valueListenable: AppSettingsService.measurementUnit,
                  builder: (context, unit, _) {
                    final heightStr = height != null
                        ? (unit == MeasurementUnit.metric
                            ? '${height.toStringAsFixed(0)} cm'
                            : () {
                                final (ft, inVal) = MeasurementUtils.cmToFtIn(height);
                                return '$ft ft $inVal in';
                              }())
                        : 'Height';
                    return CupertinoListTile.notched(
                      leading: Icon(Icons.height_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                      title: Text(heightStr, style: AppTypography.body(context)),
                      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                      onTap: _openProfileEdit,
                    );
                  },
                ),
                CupertinoListTile.notched(
                  leading: Icon(Icons.wc_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                  title: Text(_genderLabel(gender), style: AppTypography.body(context)),
                  trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                  onTap: _openProfileEdit,
                ),
                CupertinoListTile.notched(
                  leading: Icon(Icons.cake_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                  title: Text(
                    dob ?? 'Date of birth',
                    style: AppTypography.body(context),
                  ),
                  trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                  onTap: _openProfileEdit,
                ),
                if (age != null)
                  CupertinoListTile.notched(
                    leading: Icon(Icons.calendar_today_outlined, color: colorScheme.onSurfaceVariant, size: 24),
                    title: Text('$age years old', style: AppTypography.body(context)),
                    trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                    onTap: _openProfileEdit,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sign out from the menu to use a different account or continue as guest.',
              style: AppTypography.bodySmall(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if ((_error ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ],
        ),
        );
      },
    );
  }

  Widget _buildLoginView(BuildContext context, ThemeData theme, bool forced) {
    final colorScheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          forced ? 'Your guest access expired' : 'Welcome',
          style: AppTypography.heading2(context),
        ),
        const SizedBox(height: 8),
        Text(
          'Continue as guest (expires after 10 days), or create an account to keep your data synced long-term.',
          style: AppTypography.bodySmall(context).copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if ((_error ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _continueWithGoogle,
          icon: const Icon(Icons.g_mobiledata),
          label: const Text('Continue with Google'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _loading ? null : _continueWithPhone,
          icon: const Icon(Icons.phone_android_outlined),
          label: const Text('Continue with phone'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _continueAsGuest,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue as Guest'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _loading ? null : _openLogin,
          child: const Text('Log In'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _loading ? null : _openSignup,
          child: const Text('Sign Up'),
        ),
        const SizedBox(height: 18),
        ExpansionTile(
          title: Text('Why login?', style: AppTypography.body(context)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Text(
              'Guest sessions expire after 10 days. Logging in will let you sync across devices and preserve full history.',
              style: AppTypography.bodySmall(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

