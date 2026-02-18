import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/dv_auth_service.dart';
import '../../utils/app_typography.dart';
import '../../widgets/rituals/habit_form_constants.dart';
import 'login_screen.dart';
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

  Future<bool> _isSignedIn() async {
    final token = await DvAuthService.getDvToken();
    final userId = await DvAuthService.getCanvaUserId();
    return (token != null && token.isNotEmpty) && (userId != null && userId.isNotEmpty);
  }

  Future<void> _signOut() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await DvAuthService.signOut();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Widget _buildSignedInView(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return FutureBuilder<String?>(
      future: DvAuthService.getUserDisplayIdentifier(),
      builder: (context, snap) {
        final identifier = snap.data?.trim();
        final label = (identifier != null && identifier.isNotEmpty)
            ? 'Signed in as $identifier'
            : 'Signed in';
        final signInMethod = (identifier != null && identifier.contains('@'))
            ? 'Google'
            : (identifier != null && identifier.isNotEmpty)
                ? 'Phone'
                : 'Account';
        final initial = (identifier != null && identifier.isNotEmpty)
            ? identifier[0].toUpperCase()
            : '?';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CupertinoListSection.insetGrouped(
              header: null,
              margin: EdgeInsets.zero,
              backgroundColor: colorScheme.surface,
              decoration: habitSectionDecoration(colorScheme),
              separatorColor: habitSectionSeparatorColor(colorScheme),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          initial,
                          style: AppTypography.heading2(context).copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: AppTypography.heading3(context),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              signInMethod,
                              style: AppTypography.caption(context).copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your account is connected. Sign out to use a different account or continue as guest.',
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
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loading ? null : _signOut,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(_loading ? 'Signing out…' : 'Sign out'),
            ),
          ],
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

