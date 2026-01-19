import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Minimal auth storage + guest issuance.
///
/// - Guest tokens expire after 10 days (server-issued).
/// - Login/Signup are UI-only templates for now.
final class DvAuthService {
  DvAuthService._();

  static const _dvTokenKey = 'dv_auth_token_v1';
  static const _expiresAtMsKey = 'dv_auth_expires_at_ms_v1'; // unix ms
  static const _firstInstallMsKey = 'dv_first_install_ms_v1'; // unix ms
  static const _homeTimezoneKey = 'dv_home_timezone_v1';
  static const _genderKey = 'dv_gender_v1';
  static const _canvaUserIdKey = 'dv_canva_user_id_v1';

  // Legacy key used by Canva OAuth flow.
  static const _legacyCanvaDvTokenKey = 'dv_canva_token_v1';

  static String backendBaseUrl() {
    const raw = String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: 'https://digital-vision-board.onrender.com',
    );
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  static Future<void> migrateLegacyTokenIfNeeded({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = p.getString(_dvTokenKey);
    if (existing != null && existing.isNotEmpty) return;

    final legacy = p.getString(_legacyCanvaDvTokenKey);
    if (legacy == null || legacy.isEmpty) return;

    // Canva tokens are treated as non-expiring for now.
    await p.setString(_dvTokenKey, legacy);
    await p.remove(_expiresAtMsKey);
  }

  static Future<String?> getDvToken({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final t = p.getString(_dvTokenKey);
    return (t != null && t.isNotEmpty) ? t : null;
  }

  static Future<String?> getCanvaUserId({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getString(_canvaUserIdKey);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  static Future<void> _setDvToken(
    String dvToken, {
    String? canvaUserId,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_dvTokenKey, dvToken);
    await p.remove(_expiresAtMsKey); // treated as non-expiring for Canva tokens
    final cuid = (canvaUserId ?? '').trim();
    if (cuid.isEmpty) {
      await p.remove(_canvaUserIdKey);
    } else {
      await p.setString(_canvaUserIdKey, cuid);
    }
  }

  /// Connect to Canva via backend OAuth (poll-based), storing a dvToken for API calls.
  ///
  /// This is designed to work even when window.opener postMessage is not available
  /// (e.g., inside sandboxed environments).
  static Future<CanvaOAuthResult> connectViaCanvaOAuth({
    Duration timeout = const Duration(minutes: 2),
    SharedPreferences? prefs,
  }) async {
    if (kIsWeb) {
      throw Exception('Canva OAuth is not supported on web in this app.');
    }
    final p = prefs ?? await SharedPreferences.getInstance();

    final startRes = await http.get(
      Uri.parse('${backendBaseUrl()}/auth/canva/start_poll'),
      headers: {'accept': 'application/json'},
    );
    if (startRes.statusCode < 200 || startRes.statusCode >= 300) {
      throw Exception('OAuth start failed (${startRes.statusCode}): ${startRes.body}');
    }
    final startJson = jsonDecode(startRes.body) as Map<String, dynamic>;
    final authUrl = startJson['authUrl'] as String?;
    final pollToken = startJson['pollToken'] as String?;
    if ((authUrl ?? '').trim().isEmpty || (pollToken ?? '').trim().isEmpty) {
      throw Exception('OAuth start response missing authUrl/pollToken');
    }

    final ok = await launchUrl(Uri.parse(authUrl!), mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('Could not open Canva OAuth URL.');

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final pollRes = await http.get(
        Uri.parse('${backendBaseUrl()}/auth/canva/poll?pollToken=${Uri.encodeComponent(pollToken!)}'),
        headers: {'accept': 'application/json'},
      );
      if (pollRes.statusCode < 200 || pollRes.statusCode >= 300) continue;
      final pollJson = jsonDecode(pollRes.body) as Map<String, dynamic>;
      final status = pollJson['status'] as String?;
      if (status != 'completed') continue;
      final dvToken = pollJson['dvToken'] as String?;
      final canvaUserId = pollJson['canvaUserId'] as String?;
      if ((dvToken ?? '').trim().isEmpty) continue;

      await _setDvToken(dvToken!.trim(), canvaUserId: canvaUserId, prefs: p);
      return CanvaOAuthResult(dvToken: dvToken.trim(), canvaUserId: canvaUserId?.trim());
    }

    throw Exception('Timed out waiting for Canva OAuth to complete.');
  }

  static Future<int?> getExpiresAtMs({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getInt(_expiresAtMsKey);
    return v;
  }

  static Future<void> ensureFirstInstallRecorded({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = p.getInt(_firstInstallMsKey);
    if (existing != null && existing > 0) return;
    await p.setInt(_firstInstallMsKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<int?> getFirstInstallMs({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getInt(_firstInstallMsKey);
    return v;
  }

  static Future<bool> isGuestSession({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await getDvToken(prefs: p);
    if (token == null) return false;
    final expiresAtMs = await getExpiresAtMs(prefs: p);
    return expiresAtMs != null;
  }

  static Future<bool> isGuestExpired({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await getDvToken(prefs: p);
    if (token == null) return false;
    final expiresAtMs = await getExpiresAtMs(prefs: p);
    if (expiresAtMs == null) return false; // non-guest / non-expiring
    return DateTime.now().millisecondsSinceEpoch > expiresAtMs;
  }

  static Future<String?> getHomeTimezone({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final tz = p.getString(_homeTimezoneKey);
    return (tz != null && tz.trim().isNotEmpty) ? tz.trim() : null;
  }

  /// Stored values:
  /// - 'male' | 'female' | 'non_binary' | 'prefer_not_to_say'
  static Future<String> getGender({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (p.getString(_genderKey) ?? '').trim();
    if (v.isEmpty) return 'prefer_not_to_say';
    return v;
  }

  static Future<void> setHomeTimezone(String? tz, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (tz ?? '').trim();
    if (v.isEmpty) {
      await p.remove(_homeTimezoneKey);
    } else {
      await p.setString(_homeTimezoneKey, v);
    }
  }

  static Future<void> setGender(String? gender, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (gender ?? '').trim();
    await p.setString(_genderKey, v.isEmpty ? 'prefer_not_to_say' : v);
  }

  static Uri _url(String path) => Uri.parse('${backendBaseUrl()}$path');

  /// Exchange a Firebase Auth ID token for a dvToken used by this backend.
  ///
  /// Backend endpoint: POST /auth/firebase/exchange { idToken }
  static Future<FirebaseExchangeResult> exchangeFirebaseIdTokenForDvToken(
    String idToken, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = idToken.trim();
    if (token.isEmpty) throw Exception('Missing Firebase idToken');

    final res = await http.post(
      _url('/auth/firebase/exchange'),
      headers: {
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode({'idToken': token}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Firebase exchange failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final ok = decoded['ok'];
    if (ok != true) {
      throw Exception('Firebase exchange failed: ${decoded['error'] ?? 'unknown_error'}');
    }
    final dvToken = (decoded['dvToken'] as String?)?.trim();
    final userId = (decoded['userId'] as String?)?.trim();
    if ((dvToken ?? '').isEmpty || (userId ?? '').isEmpty) {
      throw Exception('Firebase exchange response missing dvToken/userId');
    }

    await _setDvToken(dvToken!, canvaUserId: userId, prefs: p);
    return FirebaseExchangeResult(dvToken: dvToken, userId: userId);
  }

  /// Best-effort server update (requires dvToken and a DB-backed backend).
  static Future<void> putUserSettings({
    String? homeTimezone,
    String? gender,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await getDvToken(prefs: p);
    if (token == null) return;
    final body = <String, dynamic>{};
    if (homeTimezone != null) body['home_timezone'] = homeTimezone;
    if (gender != null) body['gender'] = gender;
    if (body.isEmpty) return;
    try {
      final res = await http.put(
        _url('/user/settings'),
        headers: {
          'Authorization': 'Bearer $token',
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return;
    } catch (_) {
      // non-fatal
    }
  }

  static Future<void> clear({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(_dvTokenKey);
    await p.remove(_expiresAtMsKey);
    await p.remove(_canvaUserIdKey);
    await p.remove(_genderKey);
  }

  static Future<GuestAuthResult> continueAsGuest({
    String? homeTimezone,
    String? gender,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final url = _url('/auth/guest');
    final body = <String, dynamic>{};
    final tz = (homeTimezone ?? '').trim();
    if (tz.isNotEmpty) body['home_timezone'] = tz;
    final g = (gender ?? '').trim();
    if (g.isNotEmpty) body['gender'] = g;

    final res = await http.post(
      url,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Guest auth failed (${res.statusCode}): ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final dvToken = decoded['dvToken'] as String?;
    final expiresAt = decoded['expiresAt'] as String?;
    if (dvToken == null || dvToken.isEmpty || expiresAt == null || expiresAt.isEmpty) {
      throw Exception('Guest auth response missing dvToken/expiresAt');
    }
    final expiresAtMs = DateTime.parse(expiresAt).millisecondsSinceEpoch;

    await p.setString(_dvTokenKey, dvToken);
    await p.setInt(_expiresAtMsKey, expiresAtMs);

    final returnedTz = decoded['home_timezone'] as String?;
    if (returnedTz != null && returnedTz.trim().isNotEmpty) {
      await setHomeTimezone(returnedTz, prefs: p);
    }
    final returnedGender = (decoded['gender'] as String?)?.trim();
    if (returnedGender != null && returnedGender.isNotEmpty) {
      await setGender(returnedGender, prefs: p);
    } else {
      await setGender('prefer_not_to_say', prefs: p);
    }

    return GuestAuthResult(
      dvToken: dvToken,
      expiresAtMs: expiresAtMs,
      homeTimezone: returnedTz?.trim().isEmpty ?? true ? null : returnedTz!.trim(),
      gender: (returnedGender == null || returnedGender.isEmpty) ? 'prefer_not_to_say' : returnedGender,
    );
  }
}

final class FirebaseExchangeResult {
  final String dvToken;
  final String userId;

  const FirebaseExchangeResult({required this.dvToken, required this.userId});
}

final class CanvaOAuthResult {
  final String dvToken;
  final String? canvaUserId;

  const CanvaOAuthResult({required this.dvToken, required this.canvaUserId});
}

final class GuestAuthResult {
  final String dvToken;
  final int expiresAtMs;
  final String? homeTimezone;
  final String gender;

  const GuestAuthResult({
    required this.dvToken,
    required this.expiresAtMs,
    required this.homeTimezone,
    required this.gender,
  });
}

