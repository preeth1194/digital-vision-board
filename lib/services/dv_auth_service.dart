import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  static const _firstInstallMsKey = 'dv_first_install_ms_v1'; // unix ms
  static const _homeTimezoneKey = 'dv_home_timezone_v1';
  static const _genderKey = 'dv_gender_v1';
  static const _userIdKey = 'dv_canva_user_id_v1'; // kept for backward compat
  static const _userPhoneKey = 'dv_user_phone_v1';
  static const _userEmailKey = 'dv_user_email_v1';
  static const _userDisplayNameKey = 'dv_user_display_name_v1';
  static const _userWeightKey = 'dv_user_weight_kg_v1';
  static const _userHeightKey = 'dv_user_height_cm_v1';
  static const _userDobKey = 'dv_user_dob_v1';
  static const _userProfilePicKey = 'dv_user_profile_pic_v1';

  static String backendBaseUrl() {
    const raw = String.fromEnvironment(
      'BACKEND_BASE_URL',
      defaultValue: 'https://digital-vision-board.onrender.com',
    );
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  static Future<String?> getDvToken({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final t = p.getString(_dvTokenKey);
    return (t != null && t.isNotEmpty) ? t : null;
  }

  static Future<String?> getUserId({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getString(_userIdKey);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  /// Persist phone/email for display in user profile (e.g. after Firebase sign-in).
  static Future<void> setUserDisplayInfo({
    String? phoneNumber,
    String? email,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final phone = (phoneNumber ?? '').trim();
    final em = (email ?? '').trim();
    if (phone.isNotEmpty) await p.setString(_userPhoneKey, phone);
    else await p.remove(_userPhoneKey);
    if (em.isNotEmpty) await p.setString(_userEmailKey, em);
    else await p.remove(_userEmailKey);
  }

  /// Returns phone or email for display (whichever is set). Null if neither.
  static Future<String?> getUserDisplayIdentifier({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final phone = (p.getString(_userPhoneKey) ?? '').trim();
    final email = (p.getString(_userEmailKey) ?? '').trim();
    if (phone.isNotEmpty) return phone;
    if (email.isNotEmpty) return email;
    return null;
  }

  static Future<String?> getDisplayName({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (p.getString(_userDisplayNameKey) ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static Future<double?> getWeightKg({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getString(_userWeightKey);
    if (v == null || v.isEmpty) return null;
    final n = double.tryParse(v);
    return n;
  }

  static Future<double?> getHeightCm({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = p.getString(_userHeightKey);
    if (v == null || v.isEmpty) return null;
    final n = double.tryParse(v);
    return n;
  }

  static Future<String?> getDateOfBirth({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (p.getString(_userDobKey) ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static Future<String?> getProfilePicPath({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (p.getString(_userProfilePicKey) ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static Future<void> setProfilePicPath(String? path, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (path ?? '').trim();
    if (v.isEmpty) {
      await p.remove(_userProfilePicKey);
    } else {
      await p.setString(_userProfilePicKey, v);
    }
  }

  static Future<void> setProfileInfo({
    String? displayName,
    double? weightKg,
    double? heightCm,
    String? dateOfBirth,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final dn = (displayName ?? '').trim();
    if (dn.isNotEmpty) await p.setString(_userDisplayNameKey, dn);
    else await p.remove(_userDisplayNameKey);
    if (weightKg != null) await p.setString(_userWeightKey, weightKg.toString());
    else await p.remove(_userWeightKey);
    if (heightCm != null) await p.setString(_userHeightKey, heightCm.toString());
    else await p.remove(_userHeightKey);
    final dob = (dateOfBirth ?? '').trim();
    if (dob.isNotEmpty) await p.setString(_userDobKey, dob);
    else await p.remove(_userDobKey);
  }

  /// For phone users: profile is complete if displayName is set. For Google: always true.
  static Future<bool> isProfileComplete({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final identifier = await getUserDisplayIdentifier(prefs: p);
    if (identifier == null || identifier.isEmpty) return true;
    if (identifier.contains('@')) return true;
    final name = await getDisplayName(prefs: p);
    return name != null && name.isNotEmpty;
  }

  static Future<void> _setDvToken(
    String dvToken, {
    String? userId,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_dvTokenKey, dvToken);
    await p.remove(_expiresAtMsKey);
    final uid = (userId ?? '').trim();
    if (uid.isEmpty) {
      await p.remove(_userIdKey);
    } else {
      await p.setString(_userIdKey, uid);
    }
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

    final dvTokenValue = dvToken!;
    final userIdValue = userId!;
    await _setDvToken(dvTokenValue, userId: userIdValue, prefs: p);
    return FirebaseExchangeResult(dvToken: dvTokenValue, userId: userIdValue);
  }

  /// Best-effort server update (requires dvToken and a DB-backed backend).
  static Future<void> putUserSettings({
    String? homeTimezone,
    String? gender,
    String? displayName,
    double? weightKg,
    double? heightCm,
    String? dateOfBirth,
    String? subscriptionPlanId,
    bool? subscriptionActive,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await getDvToken(prefs: p);
    if (token == null) return;
    final body = <String, dynamic>{};
    if (homeTimezone != null) body['home_timezone'] = homeTimezone;
    if (gender != null) body['gender'] = gender;
    if (displayName != null) body['display_name'] = displayName;
    if (weightKg != null) body['weight_kg'] = weightKg;
    if (heightCm != null) body['height_cm'] = heightCm;
    if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
    if (subscriptionPlanId != null) body['subscription_plan_id'] = subscriptionPlanId;
    if (subscriptionActive != null) body['subscription_active'] = subscriptionActive;
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
    await p.remove(_userIdKey);
    await p.remove(_genderKey);
    await p.remove(_userPhoneKey);
    await p.remove(_userEmailKey);
    await p.remove(_userDisplayNameKey);
    await p.remove(_userWeightKey);
    await p.remove(_userHeightKey);
    await p.remove(_userDobKey);
    await p.remove(_userProfilePicKey);
  }

  /// Sign out: clear Firebase/Google sessions and app auth state.
  static Future<void> signOut({SharedPreferences? prefs}) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await clear(prefs: prefs);
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

