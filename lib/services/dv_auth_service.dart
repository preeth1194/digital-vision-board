import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const _userEmailKey = 'dv_user_email_v1';
  static const _userDisplayNameKey = 'dv_user_display_name_v1';
  static const _userWeightKey = 'dv_user_weight_kg_v1';
  static const _userHeightKey = 'dv_user_height_cm_v1';
  static const _userDobKey = 'dv_user_dob_v1';
  static const _userProfilePicKey = 'dv_user_profile_pic_v1';
  static const _activityLevelKey = 'dv_user_activity_level_v1';
  static const _dietPreferenceKey = 'dv_user_diet_preference_v1';
  static const _allergiesKey = 'dv_user_allergies_v1';
  static const _onboardingCompletedKey = 'onboarding_completed_v1';
  static const _legalConsentAcceptedKey = 'legal_consent_accepted_v1';

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

  /// Persist email for display in user profile (e.g. after Google sign-in).
  static Future<void> setUserDisplayInfo({
    String? email,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final em = (email ?? '').trim();
    if (em.isNotEmpty) {
      await p.setString(_userEmailKey, em);
    } else {
      await p.remove(_userEmailKey);
    }
  }

  /// Returns email for display. Null if not set.
  static Future<String?> getUserDisplayIdentifier({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final email = (p.getString(_userEmailKey) ?? '').trim();
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

  static Future<void> setWeightKg(double? weightKg, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    if (weightKg == null) {
      await p.remove(_userWeightKey);
    } else {
      await p.setString(_userWeightKey, weightKg.toString());
    }
  }

  static Future<void> setHeightCm(double? heightCm, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    if (heightCm == null) {
      await p.remove(_userHeightKey);
    } else {
      await p.setString(_userHeightKey, heightCm.toString());
    }
  }

  static Future<String?> getDateOfBirth({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (p.getString(_userDobKey) ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static Future<void> setDateOfBirth(
    String? dateOfBirth, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (dateOfBirth ?? '').trim();
    if (v.isEmpty) {
      await p.remove(_userDobKey);
    } else {
      await p.setString(_userDobKey, v);
    }
  }

  static Future<String?> getProfilePicPath({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (p.getString(_userProfilePicKey) ?? '').trim();
    return v.isEmpty ? null : v;
  }

  static Future<String> getActivityLevel({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (p.getString(_activityLevelKey) ?? '').trim().toLowerCase();
    if (v.isEmpty) return 'moderate';
    return v;
  }

  static Future<String?> getDietPreference({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (p.getString(_dietPreferenceKey) ?? '').trim().toLowerCase();
    return v.isEmpty ? null : v;
  }

  static Future<List<String>> getAllergies({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_allergiesKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return const [];
    }
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
    String? activityLevel,
    String? dietPreference,
    List<String>? allergies,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final dn = (displayName ?? '').trim();
    if (dn.isNotEmpty) {
      await p.setString(_userDisplayNameKey, dn);
    } else {
      await p.remove(_userDisplayNameKey);
    }
    if (weightKg != null) {
      await p.setString(_userWeightKey, weightKg.toString());
    } else {
      await p.remove(_userWeightKey);
    }
    if (heightCm != null) {
      await p.setString(_userHeightKey, heightCm.toString());
    } else {
      await p.remove(_userHeightKey);
    }
    final dob = (dateOfBirth ?? '').trim();
    if (dob.isNotEmpty) {
      await p.setString(_userDobKey, dob);
    } else {
      await p.remove(_userDobKey);
    }
    final activity = (activityLevel ?? '').trim().toLowerCase();
    if (activity.isNotEmpty) {
      await p.setString(_activityLevelKey, activity);
    } else {
      await p.remove(_activityLevelKey);
    }
    final diet = (dietPreference ?? '').trim().toLowerCase();
    if (diet.isNotEmpty) {
      await p.setString(_dietPreferenceKey, diet);
    } else {
      await p.remove(_dietPreferenceKey);
    }
    if (allergies != null) {
      final normalized = allergies
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (normalized.isEmpty) {
        await p.remove(_allergiesKey);
      } else {
        await p.setString(_allergiesKey, jsonEncode(normalized));
      }
    }
  }

  static Future<bool> isProfileComplete({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final identifier = await getUserDisplayIdentifier(prefs: p);
    if (identifier == null || identifier.isEmpty) return false;
    return true;
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

  static Future<void> setActivityLevel(
    String? activityLevel, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (activityLevel ?? '').trim().toLowerCase();
    if (v.isEmpty) {
      await p.remove(_activityLevelKey);
    } else {
      await p.setString(_activityLevelKey, v);
    }
  }

  static Future<void> setDietPreference(
    String? dietPreference, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final v = (dietPreference ?? '').trim().toLowerCase();
    if (v.isEmpty) {
      await p.remove(_dietPreferenceKey);
    } else {
      await p.setString(_dietPreferenceKey, v);
    }
  }

  static Future<void> setAllergies(
    List<String>? allergies, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final values = (allergies ?? const <String>[])
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (values.isEmpty) {
      await p.remove(_allergiesKey);
      return;
    }
    await p.setString(_allergiesKey, jsonEncode(values));
  }

  static Future<bool> isOnboardingCompleted({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getBool(_onboardingCompletedKey) ?? false;
  }

  static Future<void> markOnboardingCompleted({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(_onboardingCompletedKey, true);
  }

  static Future<bool> isLegalConsentAccepted({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getBool(_legalConsentAcceptedKey) ?? false;
  }

  static Future<void> markLegalConsentAccepted({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(_legalConsentAcceptedKey, true);
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

  /// Pushes locally stored profile fields to the server after a [dvToken] exists.
  ///
  /// Reads [SharedPreferences] via existing getters; best-effort (same as [putUserSettings]).
  static Future<void> syncLocalProfileToServer({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    if (await getDvToken(prefs: p) == null) return;

    final activityRaw = (p.getString(_activityLevelKey) ?? '').trim();
    final allergiesList = await getAllergies(prefs: p);

    await putUserSettings(
      homeTimezone: await getHomeTimezone(prefs: p),
      gender: await getGender(prefs: p),
      displayName: await getDisplayName(prefs: p),
      weightKg: await getWeightKg(prefs: p),
      heightCm: await getHeightCm(prefs: p),
      dateOfBirth: await getDateOfBirth(prefs: p),
      activityLevel: activityRaw.isNotEmpty ? activityRaw : null,
      dietPreference: await getDietPreference(prefs: p),
      allergies: allergiesList.isNotEmpty ? allergiesList : null,
      prefs: p,
    );
  }

  /// Best-effort server update (requires dvToken and a DB-backed backend).
  static Future<void> putUserSettings({
    String? homeTimezone,
    String? gender,
    String? displayName,
    double? weightKg,
    double? heightCm,
    String? dateOfBirth,
    String? activityLevel,
    String? dietPreference,
    List<String>? allergies,
    String? subscriptionPlanId,
    bool? subscriptionActive,
    String? subscriptionSource,
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
    if (activityLevel != null) body['activity_level'] = activityLevel;
    if (dietPreference != null) body['diet_preference'] = dietPreference;
    if (allergies != null) body['allergies'] = allergies;
    if (subscriptionPlanId != null) body['subscription_plan_id'] = subscriptionPlanId;
    if (subscriptionActive != null) body['subscription_active'] = subscriptionActive;
    if (subscriptionSource != null) body['subscription_source'] = subscriptionSource;
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
    await p.remove(_userEmailKey);
    await p.remove(_userDisplayNameKey);
    await p.remove(_userWeightKey);
    await p.remove(_userHeightKey);
    await p.remove(_userDobKey);
    await p.remove(_userProfilePicKey);
    await p.remove(_activityLevelKey);
    await p.remove(_dietPreferenceKey);
    await p.remove(_allergiesKey);
  }

  /// Sign out: clear Firebase/Google sessions, auth state, and backup keys.
  static Future<void> signOut({SharedPreferences? prefs}) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await clear(prefs: prefs);
    // Clear locally cached encryption key and backup link state.
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove('dv_encryption_key_v1');
    await p.remove('dv_google_backup_linked_v1');
    await p.remove('dv_google_drive_folder_id_v1');
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
    int expiresAtMs;
    try {
      expiresAtMs = DateTime.parse(expiresAt).millisecondsSinceEpoch;
    } on FormatException catch (e) {
      debugPrint('[DvAuth] Invalid expiresAt format from server: $expiresAt — $e');
      // Fall back to 10 days from now
      expiresAtMs = DateTime.now().add(const Duration(days: 10)).millisecondsSinceEpoch;
    }

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

