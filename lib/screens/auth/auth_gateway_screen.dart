import 'package:flutter/material.dart';

import '../../services/dv_auth_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthGatewayScreen extends StatefulWidget {
  final bool forced; // true when opened because guest expired

  const AuthGatewayScreen({super.key, this.forced = false});

  @override
  State<AuthGatewayScreen> createState() => _AuthGatewayScreenState();
}

class _AuthGatewayScreenState extends State<AuthGatewayScreen> {
  bool _loading = false;
  String? _error;

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            forced ? 'Your guest access expired' : 'Welcome',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Continue as guest (expires after 10 days), or create an account to keep your data synced long-term.',
            style: const TextStyle(color: Colors.black54),
          ),
          if ((_error ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
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
            title: const Text('Why login?'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: const [
              Text(
                'Guest sessions expire after 10 days. Logging in will let you sync across devices and preserve full history.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

