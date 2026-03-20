import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

const String _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

// google_sign_in v7 requires initialize() to be called exactly once.
// Calling it more than once results in undefined behavior per the package docs.
bool _googleSignInInitialized = false;

Future<void> initializeGoogleSignIn() async {
  if (_googleSignInInitialized) return;
  _googleSignInInitialized = true;

  final googleSignIn = GoogleSignIn.instance;
  if (!kIsWeb) {
    await googleSignIn.initialize();
    return;
  }

  final clientId = _googleWebClientId.trim();
  if (clientId.isEmpty) {
    throw StateError(
      'Missing GOOGLE_WEB_CLIENT_ID. Run with '
      '--dart-define=GOOGLE_WEB_CLIENT_ID=<web-oauth-client-id> for web sign-in.',
    );
  }
  await googleSignIn.initialize(clientId: clientId);
}
