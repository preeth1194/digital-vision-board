import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing Spotify configuration (Client ID, etc.)
/// 
/// NOTE: For production, store these securely (e.g., environment variables, secure storage)
/// This is a simple implementation using SharedPreferences for development.
class SpotifyConfigService {
  SpotifyConfigService._();
  static final SpotifyConfigService _instance = SpotifyConfigService._();
  factory SpotifyConfigService() => _instance;

  static const String _clientIdKey = 'spotify_client_id';
  static const String _redirectUriKey = 'spotify_redirect_uri';
  static const String _accessTokenKey = 'spotify_access_token';
  static const String _tokenExpiryKey = 'spotify_token_expiry';

  // Default redirect URI - matches AndroidManifest.xml
  static const String defaultRedirectUri = 'dvb://spotify-callback';

  /// Get Spotify Client ID from preferences or return default
  /// 
  /// IMPORTANT: Replace with your actual Client ID from Spotify Developer Dashboard
  /// https://developer.spotify.com/dashboard
  Future<String> getClientId() async {
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString(_clientIdKey);
    if (clientId != null && clientId.isNotEmpty) {
      return clientId;
    }
    // Default placeholder - MUST be replaced with your actual Client ID
    return 'YOUR_SPOTIFY_CLIENT_ID';
  }

  /// Set Spotify Client ID
  Future<void> setClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clientIdKey, clientId);
  }

  /// Get redirect URI
  Future<String> getRedirectUri() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_redirectUriKey) ?? defaultRedirectUri;
  }

  /// Set redirect URI
  Future<void> setRedirectUri(String redirectUri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_redirectUriKey, redirectUri);
  }

  /// Save access token
  Future<void> saveAccessToken(String token, int expiresInSeconds) async {
    final prefs = await SharedPreferences.getInstance();
    final expiryTime = DateTime.now().add(Duration(seconds: expiresInSeconds)).millisecondsSinceEpoch;
    await prefs.setString(_accessTokenKey, token);
    await prefs.setInt(_tokenExpiryKey, expiryTime);
  }

  /// Get access token if still valid
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);
    final expiryTime = prefs.getInt(_tokenExpiryKey);
    
    if (token == null || expiryTime == null) {
      return null;
    }

    // Check if token is expired
    if (DateTime.now().millisecondsSinceEpoch >= expiryTime) {
      // Token expired, clear it
      await clearAccessToken();
      return null;
    }

    return token;
  }

  /// Clear access token
  Future<void> clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_tokenExpiryKey);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
