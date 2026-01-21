import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

import '../models/spotify_playlist.dart';
import 'dv_auth_service.dart';

/// Abstract interface for music providers (Spotify, Apple Music, or fallback).
abstract class MusicProvider {
  /// Check if the provider is available and linked.
  Future<bool> isAvailable();

  /// Get the current playing track information.
  Future<CurrentTrack?> getCurrentTrack();

  /// Start listening for track changes.
  /// Returns a stream that emits when the track changes.
  Stream<CurrentTrack> trackChanges();

  /// Get user's playlists (optional - only if provider supports it)
  Future<List<SpotifyPlaylist>> getPlaylists({int limit = 50, int offset = 0});

  /// Search for tracks/songs
  Future<List<SpotifyTrack>> searchTracks(String query, {int limit = 20});

  /// Get tracks from a playlist
  Future<List<SpotifyTrack>> getPlaylistTracks(String playlistId, {int limit = 100, int offset = 0});

  /// Dispose resources.
  void dispose();
}

/// Information about the currently playing track.
final class CurrentTrack {
  final String title;
  final String? artist;
  final String? album;
  final String? trackId;

  const CurrentTrack({
    required this.title,
    this.artist,
    this.album,
    this.trackId,
  });
}

/// Spotify music provider implementation.
class SpotifyProvider implements MusicProvider {
  SpotifyProvider._();
  static final SpotifyProvider _instance = SpotifyProvider._();
  factory SpotifyProvider() => _instance;

  static const MethodChannel _methodChannel = MethodChannel('dvb/music_provider');
  static const EventChannel _eventChannel = EventChannel('dvb/music_provider_events');

  StreamController<CurrentTrack>? _trackController;
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _pollTimer;
  String? _lastTrackId;
  bool _isListening = false;
  bool _isAuthenticated = false;

  /// Authenticate with Spotify
  /// Note: With MediaSession/NowPlayingInfoCenter approach, authentication is not required
  /// This method is kept for future Spotify SDK integration
  Future<bool> authenticate() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('authenticateSpotify');
      if (result == true) {
        _isAuthenticated = true;
      }
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if Spotify is authenticated
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isSpotifyAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CurrentTrack?> getCurrentTrack() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getCurrentTrack');
      if (result == null) return null;

      return CurrentTrack(
        title: result['title'] as String? ?? 'Unknown',
        artist: result['artist'] as String?,
        album: result['album'] as String?,
        trackId: result['trackId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<CurrentTrack> trackChanges() {
    if (_isListening) {
      return _trackController!.stream;
    }

    _isListening = true;
    _trackController = StreamController<CurrentTrack>.broadcast();

    // Start listening on native side
    _methodChannel.invokeMethod('startListening').catchError((_) {});

    // Listen to event channel for real-time updates
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final track = CurrentTrack(
            title: event['title'] as String? ?? 'Unknown',
            artist: event['artist'] as String?,
            album: event['album'] as String?,
            trackId: event['trackId'] as String?,
          );
          if (track.trackId != _lastTrackId) {
            _lastTrackId = track.trackId;
            _trackController?.add(track);
          }
        }
      },
      onError: (_) {
        // Fallback to polling if event channel fails
      },
    );

    // Poll as fallback (in case event channel doesn't work)
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final track = await getCurrentTrack();
      if (track != null && track.trackId != _lastTrackId) {
        _lastTrackId = track.trackId;
        _trackController?.add(track);
      }
    });

    return _trackController!.stream;
  }

  @override
  Future<List<SpotifyPlaylist>> getPlaylists({int limit = 50, int offset = 0}) async {
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) {
        throw Exception('Please log in to access Spotify playlists. You can continue as guest or create an account.');
      }

      final url = Uri.parse('${DvAuthService.backendBaseUrl()}/api/spotify/playlists')
          .replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $dvToken',
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('Spotify not connected. Please connect Spotify in settings.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to load playlists: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final playlists = json['playlists'] as List<dynamic>? ?? [];
      return playlists
          .map((item) => SpotifyPlaylist.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query, {int limit = 20}) async {
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) {
        throw Exception('Please log in to search Spotify tracks. You can continue as guest or create an account.');
      }

      final url = Uri.parse('${DvAuthService.backendBaseUrl()}/api/spotify/search')
          .replace(queryParameters: {
        'query': query,
        'limit': limit.toString(),
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $dvToken',
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('Spotify not connected. Please connect Spotify in settings.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Search failed: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tracks = json['tracks'] as List<dynamic>? ?? [];
      return tracks
          .map((item) => SpotifyTrack.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<SpotifyTrack>> getPlaylistTracks(String playlistId, {int limit = 100, int offset = 0}) async {
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) {
        throw Exception('Please log in to access Spotify playlist tracks. You can continue as guest or create an account.');
      }

      final url = Uri.parse('${DvAuthService.backendBaseUrl()}/api/spotify/playlist/$playlistId/tracks')
          .replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $dvToken',
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('Spotify not connected. Please connect Spotify in settings.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to load playlist tracks: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tracks = json['tracks'] as List<dynamic>? ?? [];
      return tracks
          .map((item) => SpotifyTrack.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _trackController?.close();
    _trackController = null;
    _isListening = false;
    _lastTrackId = null;
  }
}

/// Apple Music provider implementation.
class AppleMusicProvider implements MusicProvider {
  AppleMusicProvider._();
  static final AppleMusicProvider _instance = AppleMusicProvider._();
  factory AppleMusicProvider() => _instance;

  static const MethodChannel _methodChannel = MethodChannel('dvb/music_provider');
  static const EventChannel _eventChannel = EventChannel('dvb/music_provider_events');

  StreamController<CurrentTrack>? _trackController;
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _pollTimer;
  String? _lastTrackId;
  bool _isListening = false;
  bool _hasPermission = false;

  /// Request Apple Music permission
  Future<bool> requestPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestAppleMusicPermission');
      if (result == true) {
        _hasPermission = true;
      }
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if Apple Music permission is granted
  bool get hasPermission => _hasPermission;

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isAppleMusicAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CurrentTrack?> getCurrentTrack() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getCurrentTrack');
      if (result == null) return null;

      return CurrentTrack(
        title: result['title'] as String? ?? 'Unknown',
        artist: result['artist'] as String?,
        album: result['album'] as String?,
        trackId: result['trackId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<CurrentTrack> trackChanges() {
    if (_isListening) {
      return _trackController!.stream;
    }

    _isListening = true;
    _trackController = StreamController<CurrentTrack>.broadcast();

    // Start listening on native side
    _methodChannel.invokeMethod('startListening').catchError((_) {});

    // Listen to event channel for real-time updates
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final track = CurrentTrack(
            title: event['title'] as String? ?? 'Unknown',
            artist: event['artist'] as String?,
            album: event['album'] as String?,
            trackId: event['trackId'] as String?,
          );
          if (track.trackId != _lastTrackId) {
            _lastTrackId = track.trackId;
            _trackController?.add(track);
          }
        }
      },
      onError: (_) {
        // Fallback to polling if event channel fails
      },
    );

    // Poll as fallback
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final track = await getCurrentTrack();
      if (track != null && track.trackId != _lastTrackId) {
        _lastTrackId = track.trackId;
        _trackController?.add(track);
      }
    });

    return _trackController!.stream;
  }

  @override
  Future<List<SpotifyPlaylist>> getPlaylists({int limit = 50, int offset = 0}) async {
    // Apple Music playlist support would go here
    return [];
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query, {int limit = 20}) async {
    // Apple Music search support would go here
    return [];
  }

  @override
  Future<List<SpotifyTrack>> getPlaylistTracks(String playlistId, {int limit = 100, int offset = 0}) async {
    // Apple Music playlist tracks support would go here
    return [];
  }

  @override
  void dispose() {
    _methodChannel.invokeMethod('stopListening').catchError((_) {});
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _trackController?.close();
    _trackController = null;
    _isListening = false;
    _lastTrackId = null;
  }
}

/// Fallback audio provider using local assets.
class FallbackAudioProvider implements MusicProvider {
  final List<String> audioAssets;
  int _currentIndex = 0;
  StreamController<CurrentTrack>? _trackController;
  bool _isPlaying = false;

  FallbackAudioProvider({required this.audioAssets});

  @override
  Future<bool> isAvailable() async {
    // Fallback is always available if we have assets
    return audioAssets.isNotEmpty;
  }

  @override
  Future<CurrentTrack?> getCurrentTrack() async {
    if (audioAssets.isEmpty || _currentIndex >= audioAssets.length) {
      return null;
    }
    final asset = audioAssets[_currentIndex];
    // Extract filename as title
    final title = asset.split('/').last.replaceAll('.mp3', '').replaceAll('_', ' ');
    return CurrentTrack(title: title, trackId: asset);
  }

  @override
  Stream<CurrentTrack> trackChanges() {
    if (_trackController != null) {
      return _trackController!.stream;
    }

    _trackController = StreamController<CurrentTrack>.broadcast();

    // When a song completes, move to next and emit
    // This will be triggered by the audio player completion callback
    // For now, we'll set up the stream structure

    return _trackController!.stream;
  }

  /// Called when current track completes - moves to next track.
  void onTrackCompleted() {
    if (audioAssets.isEmpty) return;

    _currentIndex = (_currentIndex + 1) % audioAssets.length;
    getCurrentTrack().then((track) {
      if (track != null) {
        _trackController?.add(track);
      }
    });
  }

  /// Reset to first track.
  void reset() {
    _currentIndex = 0;
  }

  @override
  Future<List<SpotifyPlaylist>> getPlaylists({int limit = 50, int offset = 0}) async {
    // Fallback provider doesn't support playlists
    return [];
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query, {int limit = 20}) async {
    // Fallback provider doesn't support search
    return [];
  }

  @override
  Future<List<SpotifyTrack>> getPlaylistTracks(String playlistId, {int limit = 100, int offset = 0}) async {
    // Fallback provider doesn't support playlists
    return [];
  }

  @override
  void dispose() {
    _trackController?.close();
    _trackController = null;
    _isPlaying = false;
  }
}

/// YouTube Music provider implementation.
class YouTubeMusicProvider implements MusicProvider {
  YouTubeMusicProvider._();
  static final YouTubeMusicProvider _instance = YouTubeMusicProvider._();
  factory YouTubeMusicProvider() => _instance;

  static const MethodChannel _methodChannel = MethodChannel('dvb/music_provider');
  static const EventChannel _eventChannel = EventChannel('dvb/music_provider_events');

  StreamController<CurrentTrack>? _trackController;
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _pollTimer;
  String? _lastTrackId;
  bool _isListening = false;
  bool _isAuthenticated = false;

  /// Authenticate with YouTube Music
  Future<bool> authenticate() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('authenticateYouTubeMusic');
      if (result == true) {
        _isAuthenticated = true;
      }
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if YouTube Music is authenticated
  bool get isAuthenticated => _isAuthenticated;

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isYouTubeMusicAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CurrentTrack?> getCurrentTrack() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getCurrentTrack');
      if (result == null) return null;

      return CurrentTrack(
        title: result['title'] as String? ?? 'Unknown',
        artist: result['artist'] as String?,
        album: result['album'] as String?,
        trackId: result['trackId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<CurrentTrack> trackChanges() {
    if (_isListening) {
      return _trackController!.stream;
    }

    _isListening = true;
    _trackController = StreamController<CurrentTrack>.broadcast();

    // Start listening on native side
    _methodChannel.invokeMethod('startListening').catchError((_) {});

    // Listen to event channel for real-time updates
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final track = CurrentTrack(
            title: event['title'] as String? ?? 'Unknown',
            artist: event['artist'] as String?,
            album: event['album'] as String?,
            trackId: event['trackId'] as String?,
          );
          if (track.trackId != _lastTrackId) {
            _lastTrackId = track.trackId;
            _trackController?.add(track);
          }
        }
      },
      onError: (_) {
        // Fallback to polling if event channel fails
      },
    );

    // Poll as fallback (in case event channel doesn't work)
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final track = await getCurrentTrack();
      if (track != null && track.trackId != _lastTrackId) {
        _lastTrackId = track.trackId;
        _trackController?.add(track);
      }
    });

    return _trackController!.stream;
  }

  @override
  Future<List<SpotifyPlaylist>> getPlaylists({int limit = 50, int offset = 0}) async {
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) {
        throw Exception('Please log in to access YouTube Music playlists. You can continue as guest or create an account.');
      }

      final url = Uri.parse('${DvAuthService.backendBaseUrl()}/api/youtube-music/playlists')
          .replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $dvToken',
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('YouTube Music not connected. Please connect YouTube Music in settings.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to load playlists: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final playlists = json['playlists'] as List<dynamic>? ?? [];
      return playlists
          .map((item) => SpotifyPlaylist.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query, {int limit = 20}) async {
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) {
        throw Exception('Please log in to search YouTube Music tracks. You can continue as guest or create an account.');
      }

      final url = Uri.parse('${DvAuthService.backendBaseUrl()}/api/youtube-music/search')
          .replace(queryParameters: {
        'query': query,
        'limit': limit.toString(),
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $dvToken',
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('YouTube Music not connected. Please connect YouTube Music in settings.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Search failed: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tracks = json['tracks'] as List<dynamic>? ?? [];
      return tracks
          .map((item) => SpotifyTrack.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<SpotifyTrack>> getPlaylistTracks(String playlistId, {int limit = 100, int offset = 0}) async {
    try {
      final dvToken = await DvAuthService.getDvToken();
      if (dvToken == null) {
        throw Exception('Please log in to access YouTube Music playlist tracks. You can continue as guest or create an account.');
      }

      final url = Uri.parse('${DvAuthService.backendBaseUrl()}/api/youtube-music/playlist/$playlistId/tracks')
          .replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $dvToken',
          'accept': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('YouTube Music not connected. Please connect YouTube Music in settings.');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to load playlist tracks: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tracks = json['tracks'] as List<dynamic>? ?? [];
      return tracks
          .map((item) => SpotifyTrack.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _trackController?.close();
    _trackController = null;
    _isListening = false;
    _lastTrackId = null;
  }
}

/// Local file provider implementation.
class LocalFileProvider implements MusicProvider {
  LocalFileProvider._();
  static final LocalFileProvider _instance = LocalFileProvider._();
  factory LocalFileProvider() => _instance;

  static const String _selectedFilesKey = 'local_file_provider_selected_files';
  
  List<String> _selectedFiles = [];
  int _currentIndex = 0;
  StreamController<CurrentTrack>? _trackController;
  bool _isListening = false;

  /// Load selected files from SharedPreferences
  Future<void> _loadSelectedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filesJson = prefs.getStringList(_selectedFilesKey) ?? [];
      _selectedFiles = filesJson;
    } catch (_) {
      _selectedFiles = [];
    }
  }

  /// Save selected files to SharedPreferences
  Future<void> _saveSelectedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_selectedFilesKey, _selectedFiles);
    } catch (_) {
      // Ignore save errors
    }
  }

  /// Get the list of selected file paths
  Future<List<String>> getSelectedFiles() async {
    await _loadSelectedFiles();
    return List.unmodifiable(_selectedFiles);
  }

  /// Add files to the selection
  Future<void> addFiles(List<String> filePaths) async {
    await _loadSelectedFiles();
    for (final filePath in filePaths) {
      if (!_selectedFiles.contains(filePath)) {
        _selectedFiles.add(filePath);
      }
    }
    await _saveSelectedFiles();
  }

  /// Remove a file from the selection
  Future<void> removeFile(String filePath) async {
    await _loadSelectedFiles();
    _selectedFiles.remove(filePath);
    await _saveSelectedFiles();
  }

  /// Clear all selected files
  Future<void> clearFiles() async {
    _selectedFiles = [];
    await _saveSelectedFiles();
  }

  String _getTrackTitle(String filePath) {
    final fileName = path.basename(filePath);
    // Remove extension
    return fileName.replaceAll(RegExp(r'\.[^.]*$'), '').replaceAll('_', ' ');
  }

  @override
  Future<bool> isAvailable() async {
    await _loadSelectedFiles();
    return _selectedFiles.isNotEmpty;
  }

  @override
  Future<CurrentTrack?> getCurrentTrack() async {
    await _loadSelectedFiles();
    if (_selectedFiles.isEmpty || _currentIndex >= _selectedFiles.length) {
      return null;
    }
    final filePath = _selectedFiles[_currentIndex];
    final title = _getTrackTitle(filePath);
    return CurrentTrack(
      title: title,
      trackId: filePath,
    );
  }

  @override
  Stream<CurrentTrack> trackChanges() {
    if (_isListening) {
      return _trackController!.stream;
    }

    _isListening = true;
    _trackController = StreamController<CurrentTrack>.broadcast();

    return _trackController!.stream;
  }

  /// Called when current track completes - moves to next track.
  void onTrackCompleted() async {
    await _loadSelectedFiles();
    if (_selectedFiles.isEmpty) return;

    _currentIndex = (_currentIndex + 1) % _selectedFiles.length;
    final track = await getCurrentTrack();
    if (track != null) {
      _trackController?.add(track);
    }
  }

  /// Reset to first track.
  void reset() {
    _currentIndex = 0;
  }

  @override
  Future<List<SpotifyPlaylist>> getPlaylists({int limit = 50, int offset = 0}) async {
    await _loadSelectedFiles();
    if (_selectedFiles.isEmpty) {
      return [];
    }
    // Return a single "Local Files" playlist
    return [
      SpotifyPlaylist(
        id: 'local_files',
        name: 'Local Files',
        trackCount: _selectedFiles.length,
      ),
    ];
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query, {int limit = 20}) async {
    await _loadSelectedFiles();
    if (query.trim().isEmpty) {
      return [];
    }

    final lowerQuery = query.toLowerCase();
    final matchingFiles = _selectedFiles
        .where((filePath) {
          final fileName = path.basename(filePath).toLowerCase();
          return fileName.contains(lowerQuery);
        })
        .take(limit)
        .toList();

    return matchingFiles.map((filePath) {
      final title = _getTrackTitle(filePath);
      return SpotifyTrack(
        id: filePath,
        name: title,
      );
    }).toList();
  }

  @override
  Future<List<SpotifyTrack>> getPlaylistTracks(String playlistId, {int limit = 100, int offset = 0}) async {
    await _loadSelectedFiles();
    if (playlistId != 'local_files') {
      return [];
    }

    final startIndex = offset;
    final endIndex = (startIndex + limit).clamp(0, _selectedFiles.length);
    final files = _selectedFiles.sublist(
      startIndex.clamp(0, _selectedFiles.length),
      endIndex,
    );

    return files.map((filePath) {
      final title = _getTrackTitle(filePath);
      return SpotifyTrack(
        id: filePath,
        name: title,
      );
    }).toList();
  }

  @override
  void dispose() {
    _trackController?.close();
    _trackController = null;
    _isListening = false;
  }
}
