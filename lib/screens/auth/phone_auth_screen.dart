import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/dv_auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phone = TextEditingController();
  final _smsCode = TextEditingController();

  bool _loading = false;
  String? _verificationId;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _smsCode.dispose();
    super.dispose();
  }

  Future<void> _startVerify() async {
    if (_loading) return;
    final number = _phone.text.trim();
    if (number.isEmpty) {
      setState(() => _error = 'Enter a phone number (E.164 format, e.g. +14155552671).');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: number,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolve on Android sometimes.
          try {
            final cred = await FirebaseAuth.instance.signInWithCredential(credential);
            final idToken = await cred.user?.getIdToken();
            if ((idToken ?? '').trim().isEmpty) return;
            await DvAuthService.exchangeFirebaseIdTokenForDvToken(idToken!);
            if (!mounted) return;
            Navigator.of(context).pop(true);
          } catch (_) {
            // ignore; user can still enter SMS manually
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => _error = e.message ?? e.code);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCode() async {
    if (_loading) return;
    final vid = _verificationId;
    if ((vid ?? '').isEmpty) {
      setState(() => _error = 'Tap "Send code" first.');
      return;
    }
    final code = _smsCode.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the SMS code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(verificationId: vid!, smsCode: code);
      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await cred.user?.getIdToken();
      if ((idToken ?? '').trim().isEmpty) {
        throw Exception('Could not get Firebase idToken.');
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasVerification = (_verificationId ?? '').trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in with phone')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Enter your phone number in international format.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+14155552671',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _startVerify,
            icon: const Icon(Icons.sms_outlined),
            label: Text(_loading ? 'Sending…' : 'Send code'),
          ),
          const SizedBox(height: 18),
          if (hasVerification) ...[
            TextField(
              controller: _smsCode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'SMS code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submitCode,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify & continue'),
            ),
          ],
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
        ],
      ),
    );
  }
}

