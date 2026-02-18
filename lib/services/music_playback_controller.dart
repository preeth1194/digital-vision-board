import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/habit_item.dart';
import 'music_provider_service.dart';

/// Default fallback audio assets when no provider is linked.
const List<String> _defaultFallbackAssets = [
  'assets/audio/focus_1.mp3',
  'assets/audio/focus_2.mp3',
  'assets/audio/focus_3.mp3',
];

/// Controller for music playback during time-based timer.
/// Supports start/stop/pause for Fallback and Local Files.
/// For Spotify/YouTube Music, opens the app and shows instructions.
final class MusicPlaybackController {
  final HabitTimeBoundSpec timeBound;
  final SharedPreferences prefs;

  AudioPlayer? _audioPlayer;
  MusicProvider? _musicProvider;
  List<String> _playbackAssets = [];
  int _currentAssetIndex = 0;
  bool _isPlaying = false;

  MusicPlaybackController({
    required this.timeBound,
    required this.prefs,
  });

  /// Whether this controller has music to play (playlist, tracks, or fallback).
  bool get hasMusicConfig =>
      timeBound.spotifyPlaylistId != null ||
      (timeBound.spotifyTrackIds?.isNotEmpty ?? false);

  /// Initialize the controller. Call before start().
  Future<void> initialize() async {
    if (!hasMusicConfig) return;

    final linkedProvider = prefs.getString('music_provider_preference');

    // Try Spotify if linked and we have playlist/tracks
    if ((linkedProvider == 'spotify') &&
        (timeBound.spotifyPlaylistId != null ||
            (timeBound.spotifyTrackIds?.isNotEmpty ?? false))) {
      return; // Handled by openExternal - no local playback
    }

    // Try YouTube Music if linked
    if (linkedProvider == 'youtube_music') {
      return; // Handled by openExternal - no local playback
    }

    // Try Local Files if linked
    if (linkedProvider == 'local_files') {
      final localFiles = LocalFileProvider();
      if (await localFiles.isAvailable()) {
        final files = await localFiles.getSelectedFiles();
        if (files.isNotEmpty) {
          _playbackAssets = files;
          _musicProvider = localFiles;
          _audioPlayer = AudioPlayer();
          _setupAudioPlayerForFiles();
          return;
        }
      }
    }

    // Fallback: use default assets
    _playbackAssets = List.from(_defaultFallbackAssets);
    _musicProvider = FallbackAudioProvider(audioAssets: _playbackAssets);
    _audioPlayer = AudioPlayer();
    _setupAudioPlayerForAssets();
  }

  void _setupAudioPlayerForAssets() {
    if (_audioPlayer == null || _playbackAssets.isEmpty) return;

    _audioPlayer!.onPlayerComplete.listen((_) {
      _currentAssetIndex = (_currentAssetIndex + 1) % _playbackAssets.length;
      _playCurrentAsset();
    });
  }

  void _setupAudioPlayerForFiles() {
    if (_audioPlayer == null || _playbackAssets.isEmpty) return;

    _audioPlayer!.onPlayerComplete.listen((_) {
      _currentAssetIndex = (_currentAssetIndex + 1) % _playbackAssets.length;
      _playCurrentFile();
    });
  }

  Future<void> _playCurrentAsset() async {
    if (_audioPlayer == null ||
        _playbackAssets.isEmpty ||
        _currentAssetIndex >= _playbackAssets.length) {
      return;
    }

    final asset = _playbackAssets[_currentAssetIndex];
    try {
      final assetPath = asset.replaceFirst('assets/', '');
      await _audioPlayer!.play(AssetSource(assetPath));
    } catch (_) {
      // Asset not found, try next
      _currentAssetIndex =
          (_currentAssetIndex + 1) % _playbackAssets.length;
      if (_currentAssetIndex != 0) {
        _playCurrentAsset();
      }
    }
  }

  Future<void> _playCurrentFile() async {
    if (_audioPlayer == null ||
        _playbackAssets.isEmpty ||
        _currentAssetIndex >= _playbackAssets.length) {
      return;
    }

    final filePath = _playbackAssets[_currentAssetIndex];
    try {
      await _audioPlayer!.play(DeviceFileSource(filePath));
    } catch (_) {
      _currentAssetIndex =
          (_currentAssetIndex + 1) % _playbackAssets.length;
      if (_currentAssetIndex != 0) {
        _playCurrentFile();
      }
    }
  }

  /// Start playback. For Fallback/Local: starts playing. For Spotify/YT: opens app.
  /// Returns true if local playback started; false if external app was opened or no config.
  Future<bool> start() async {
    if (!hasMusicConfig) return false;

    final linkedProvider = prefs.getString('music_provider_preference');

    // Spotify: open playlist or first track in app
    if (linkedProvider == 'spotify') {
      if (timeBound.spotifyPlaylistId != null) {
        await _openSpotifyPlaylist(timeBound.spotifyPlaylistId!);
        return false;
      }
      if (timeBound.spotifyTrackIds?.isNotEmpty ?? false) {
        await _openSpotifyTrack(timeBound.spotifyTrackIds!.first);
        return false;
      }
    }

    // YouTube Music: open in app (no standard deep link for playlists)
    if (linkedProvider == 'youtube_music') {
      return false;
    }

    // Local playback (Fallback or Local Files)
    if (_audioPlayer != null && _playbackAssets.isNotEmpty) {
      _isPlaying = true;
      _currentAssetIndex = 0;
      if (_musicProvider is LocalFileProvider) {
        await _playCurrentFile();
      } else {
        await _playCurrentAsset();
      }
      return true;
    }

    return false;
  }

  /// Stop playback.
  Future<void> stop() async {
    _isPlaying = false;
    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
    }
  }

  /// Pause playback.
  Future<void> pause() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.pause();
    }
  }

  /// Resume playback (after pause).
  Future<void> resume() async {
    if (!_isPlaying) return;
    if (_audioPlayer != null) {
      await _audioPlayer!.resume();
    }
  }

  /// Whether local playback is currently active (playing or paused).
  bool get isActive => _isPlaying;

  /// Whether we use external app (Spotify/YT) - no programmatic stop.
  Future<bool> usesExternalApp() async {
    if (!hasMusicConfig) return false;
    final linkedProvider = prefs.getString('music_provider_preference');
    return linkedProvider == 'spotify' || linkedProvider == 'youtube_music';
  }

  Future<void> _openSpotifyPlaylist(String playlistId) async {
    final uri = Uri.parse('spotify:playlist:$playlistId');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignore launch errors
    }
  }

  Future<void> _openSpotifyTrack(String trackId) async {
    final uri = Uri.parse('spotify:track:$trackId');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignore launch errors
    }
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await stop();
    _musicProvider?.dispose();
    _musicProvider = null;
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
