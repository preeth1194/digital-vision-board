import 'dart:async';
import 'package:flutter/services.dart';

import '../models/spotify_playlist.dart';

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
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getSpotifyPlaylists',
        {'limit': limit, 'offset': offset},
      );
      if (result == null) return [];
      return result
          .map((item) => SpotifyPlaylist.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      // If not implemented, return empty list
      return [];
    }
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query, {int limit = 20}) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'searchSpotifyTracks',
        {'query': query, 'limit': limit},
      );
      if (result == null) return [];
      return result
          .map((item) => SpotifyTrack.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      // If not implemented, return empty list
      return [];
    }
  }

  @override
  Future<List<SpotifyTrack>> getPlaylistTracks(String playlistId, {int limit = 100, int offset = 0}) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getSpotifyPlaylistTracks',
        {'playlistId': playlistId, 'limit': limit, 'offset': offset},
      );
      if (result == null) return [];
      return result
          .map((item) => SpotifyTrack.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      // If not implemented, return empty list
      return [];
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
