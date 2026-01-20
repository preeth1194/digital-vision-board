import 'dart:async';

/// Abstract interface for music providers (Spotify, Apple Music, or fallback).
abstract class MusicProvider {
  /// Check if the provider is available and linked.
  Future<bool> isAvailable();

  /// Get the current playing track information.
  Future<CurrentTrack?> getCurrentTrack();

  /// Start listening for track changes.
  /// Returns a stream that emits when the track changes.
  Stream<CurrentTrack> trackChanges();

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

  StreamController<CurrentTrack>? _trackController;
  Timer? _pollTimer;
  String? _lastTrackId;
  bool _isListening = false;

  @override
  Future<bool> isAvailable() async {
    try {
      // TODO: Implement Spotify SDK check
      // This will require native platform channels
      // For now, return false as placeholder
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CurrentTrack?> getCurrentTrack() async {
    try {
      // TODO: Implement Spotify SDK track retrieval
      // This will require native platform channels
      // For now, return null as placeholder
      return null;
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

    // Poll for track changes (Spotify SDK may not provide direct callbacks)
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

  StreamController<CurrentTrack>? _trackController;
  Timer? _pollTimer;
  String? _lastTrackId;
  bool _isListening = false;

  @override
  Future<bool> isAvailable() async {
    try {
      // TODO: Implement Apple Music availability check
      // This will require native platform channels (iOS)
      // For now, return false as placeholder
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CurrentTrack?> getCurrentTrack() async {
    try {
      // TODO: Implement Apple Music track retrieval
      // This will require native platform channels (iOS)
      // Use MPMusicPlayerController on iOS
      // For now, return null as placeholder
      return null;
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

    // Poll for track changes (Apple Music may not provide direct callbacks)
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
  void dispose() {
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
  void dispose() {
    _trackController?.close();
    _trackController = null;
    _isPlaying = false;
  }
}
