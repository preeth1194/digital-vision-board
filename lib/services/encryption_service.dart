import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dv_auth_service.dart';

/// AES-256-GCM encryption/decryption with a randomly generated key
/// stored on the backend in dv_user_settings.encryption_key.
class EncryptionService {
  EncryptionService._();

  static const _localKeyPref = 'dv_encryption_key_v1';

  static final _algo = AesGcm.with256bits();

  /// Returns the encryption key, fetching from backend or generating new.
  static Future<SecretKey> getOrCreateKey({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();

    final local = p.getString(_localKeyPref);
    if (local != null && local.isNotEmpty) {
      return SecretKey(base64Decode(local));
    }

    final remote = await _fetchKeyFromBackend(prefs: p);
    if (remote != null) {
      await p.setString(_localKeyPref, remote);
      return SecretKey(base64Decode(remote));
    }

    final key = await _algo.newSecretKey();
    final keyBytes = await key.extractBytes();
    final b64 = base64Encode(keyBytes);
    await _pushKeyToBackend(b64, prefs: p);
    await p.setString(_localKeyPref, b64);
    return key;
  }

  /// Encrypt bytes. Returns [12-byte nonce][ciphertext][16-byte MAC].
  static Future<Uint8List> encrypt(
    Uint8List plaintext, {
    required SecretKey key,
  }) async {
    final box = await _algo.encrypt(plaintext, secretKey: key);
    final out = BytesBuilder(copy: false);
    out.add(box.nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.toBytes();
  }

  /// Decrypt bytes produced by [encrypt].
  static Future<Uint8List> decrypt(
    Uint8List encrypted, {
    required SecretKey key,
  }) async {
    if (encrypted.length < 28) {
      throw const FormatException('Encrypted data too short');
    }
    final nonce = encrypted.sublist(0, 12);
    final mac = Mac(encrypted.sublist(encrypted.length - 16));
    final cipherText = encrypted.sublist(12, encrypted.length - 16);
    final box = SecretBox(cipherText, nonce: nonce, mac: mac);
    final plain = await _algo.decrypt(box, secretKey: key);
    return Uint8List.fromList(plain);
  }

  /// Encrypt a file on disk to [outputPath].
  static Future<void> encryptFile({
    required String inputPath,
    required String outputPath,
    required SecretKey key,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final encrypted = await encrypt(bytes, key: key);
    await File(outputPath).writeAsBytes(encrypted, flush: true);
  }

  /// Decrypt a file on disk to [outputPath].
  static Future<void> decryptFile({
    required String inputPath,
    required String outputPath,
    required SecretKey key,
  }) async {
    final bytes = await File(inputPath).readAsBytes();
    final decrypted = await decrypt(bytes, key: key);
    await File(outputPath).writeAsBytes(decrypted, flush: true);
  }

  static Future<String?> _fetchKeyFromBackend({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await DvAuthService.getDvToken(prefs: p);
    if (token == null) return null;
    try {
      final res = await http.get(
        Uri.parse('${DvAuthService.backendBaseUrl()}/user/encryption-key'),
        headers: {
          'Authorization': 'Bearer $token',
          'accept': 'application/json',
        },
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final key = body['encryption_key'] as String?;
      return (key != null && key.isNotEmpty) ? key : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _pushKeyToBackend(
    String b64Key, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await DvAuthService.getDvToken(prefs: p);
    if (token == null) return;
    try {
      await http.put(
        Uri.parse('${DvAuthService.backendBaseUrl()}/user/encryption-key'),
        headers: {
          'Authorization': 'Bearer $token',
          'content-type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode({'encryption_key': b64Key}),
      );
    } catch (_) {
      // non-fatal; key is cached locally
    }
  }

  /// Clear the locally cached key (e.g. on sign-out).
  static Future<void> clearLocal({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(_localKeyPref);
  }
}
