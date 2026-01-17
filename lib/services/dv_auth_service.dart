import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal auth storage + guest issuance.
///
/// - Guest tokens expire after 10 days (server-issued).
/// - Login/Signup are UI-only templates for now.
final class DvAuthService {
  DvAuthService._();

  static const _dvTokenKey = 'dv_auth_token_v1';
  static const _expiresAtMsKey = 'dv_auth_expires_at_ms_v1'; // unix ms
  static const _homeTimezoneKey = 'dv_home_timezone_v1';

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

  static Future<int?> getExpiresAtMs({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getInt(_expiresAtMsKey);
    return v;
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

  static Future<void> setHomeTimezone(String? tz, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (tz ?? '').trim();
    if (v.isEmpty) {
      await p.remove(_homeTimezoneKey);
    } else {
      await p.setString(_homeTimezoneKey, v);
    }
  }

  static Future<void> clear({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(_dvTokenKey);
    await p.remove(_expiresAtMsKey);
  }

  static Future<GuestAuthResult> continueAsGuest({
    String? homeTimezone,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final url = Uri.parse('${backendBaseUrl()}/auth/guest');
    final body = <String, dynamic>{};
    final tz = (homeTimezone ?? '').trim();
    if (tz.isNotEmpty) body['home_timezone'] = tz;

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

    return GuestAuthResult(
      dvToken: dvToken,
      expiresAtMs: expiresAtMs,
      homeTimezone: returnedTz?.trim().isEmpty ?? true ? null : returnedTz!.trim(),
    );
  }
}

final class GuestAuthResult {
  final String dvToken;
  final int expiresAtMs;
  final String? homeTimezone;

  const GuestAuthResult({
    required this.dvToken,
    required this.expiresAtMs,
    required this.homeTimezone,
  });
}

