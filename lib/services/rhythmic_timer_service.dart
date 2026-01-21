import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/rhythmic_timer_config.dart';
import 'logical_date_service.dart';
import 'music_provider_service.dart';
import 'rhythmic_timer_state_service.dart' show RhythmicTimerState, RhythmicTimerStateService;

/// Get the linked music provider from user preferences
Future<String?> _getLinkedProvider() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('music_provider_preference');
    // Only return if it's a valid provider (not 'fallback')
    if (provider == 'spotify' || provider == 'apple_music' || provider == 'youtube_music' || provider == 'local_files') {
      return provider;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Main service for managing rhythmic timer (Time-Based and Song-Based modes).
final class RhythmicTimerService {
  final String habitId;
  final HabitItem habit;
  final SharedPreferences prefs;
  final DateTime logicalDate;
  final Future<void> Function()? onHabitComplete;

  MusicProvider? _musicProvider;
  StreamSubscription<CurrentTrack>? _trackSubscription;
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _isRunning = false;

  RhythmicTimerService({
    required this.habitId,
    required this.habit,
    required this.prefs,
    required this.logicalDate,
    this.onHabitComplete,
  });

  /// Get the rhythmic timer configuration from habit.
  Future<RhythmicTimerConfig?> getConfig() async {
    final timeBound = habit.timeBound;
    if (timeBound == null || !timeBound.enabled) return null;

    // For song-based mode, we need targetSongs from a separate config
    // For now, we'll use duration as song count if mode is 'song'
    if (timeBound.isSongBased) {
      // Get linked provider from user preferences
      final linkedProvider = await _getLinkedProvider();
      
      // Get playlist/track selection from timeBound
      final playlistId = timeBound.spotifyPlaylistId;
      final selectedTrackIds = timeBound.spotifyTrackIds;
      
      // If specific tracks are selected, use that count; otherwise use duration
      final targetSongs = selectedTrackIds?.isNotEmpty == true
          ? selectedTrackIds!.length
          : (timeBound.duration > 0 ? timeBound.duration : null);
      
      return RhythmicTimerConfig(
        mode: 'song',
        targetSongs: targetSongs,
        linkedProvider: linkedProvider,
        playlistId: playlistId,
        selectedTrackIds: selectedTrackIds,
        fallbackAudioAssets: _getDefaultAudioAssets(),
      );
    }

    // Time-based mode
    return RhythmicTimerConfig(
      mode: 'time',
      targetSongs: null,
      linkedProvider: null,
      playlistId: null,
      fallbackAudioAssets: null,
    );
  }

  List<String> _getDefaultAudioAssets() {
    // Default fallback audio assets
    return [
      'assets/audio/focus_1.mp3',
      'assets/audio/focus_2.mp3',
      'assets/audio/focus_3.mp3',
    ];
  }

  /// Initialize the timer service based on mode.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final config = await getConfig();
    if (config == null) return;

    if (config.isSongBased) {
      await _initializeSongMode(config);
    } else {
      // Time-based mode uses existing HabitTimerStateService
      // No additional initialization needed here
    }

    _isInitialized = true;
  }

  Future<void> _initializeSongMode(RhythmicTimerConfig config) async {
    final targetSongs = config.targetSongs ?? 1;
    await RhythmicTimerStateService.initialize(
      prefs: prefs,
      habitId: habitId,
      logicalDate: logicalDate,
      totalSongs: targetSongs,
    );

    // Try to initialize music provider
    await _initializeMusicProvider(config);
  }

  Future<void> _initializeMusicProvider(RhythmicTimerConfig config) async {
    // Try Spotify first if linked
    if (config.linkedProvider == 'spotify') {
      final spotify = SpotifyProvider();
      if (await spotify.isAvailable()) {
        _musicProvider = spotify;
        return;
      }
    }

    // Try YouTube Music if linked
    if (config.linkedProvider == 'youtube_music') {
      final youtubeMusic = YouTubeMusicProvider();
      if (await youtubeMusic.isAvailable()) {
        _musicProvider = youtubeMusic;
        return;
      }
    }

    // Try Local Files if linked
    if (config.linkedProvider == 'local_files') {
      final localFiles = LocalFileProvider();
      if (await localFiles.isAvailable()) {
        _musicProvider = localFiles;
        return;
      }
    }

    // Try Apple Music if linked
    if (config.linkedProvider == 'apple_music') {
      final appleMusic = AppleMusicProvider();
      if (await appleMusic.isAvailable()) {
        _musicProvider = appleMusic;
        return;
      }
    }

    // Fallback to internal audio player
    final fallbackAssets = config.fallbackAudioAssets ?? _getDefaultAudioAssets();
    if (fallbackAssets.isNotEmpty) {
      _musicProvider = FallbackAudioProvider(audioAssets: fallbackAssets);
      _audioPlayer = AudioPlayer();
      _setupAudioPlayer(fallbackAssets);
    }
  }

  void _setupAudioPlayer(List<String> assets) {
    if (_audioPlayer == null || assets.isEmpty) return;

    final fallbackProvider = _musicProvider as FallbackAudioProvider?;
    if (fallbackProvider == null) return;

    // Set up completion listener
    _audioPlayer!.onPlayerComplete.listen((_) {
      fallbackProvider.onTrackCompleted();
      _onTrackChanged(fallbackProvider);
    });
  }

  /// Start the timer.
  Future<void> start() async {
    if (!_isInitialized) {
      await initialize();
    }

    final config = await getConfig();
    if (config == null) return;

    if (config.isSongBased) {
      await _startSongMode();
    } else {
      // Time-based mode uses existing HabitTimerStateService
      // This is handled by the existing timer screen
    }

    _isRunning = true;
  }

  Future<void> _startSongMode() async {
    // If no music provider is available, we can still track manually
    // User can manually mark songs as complete
    if (_musicProvider == null) {
      // Initialize state if not already done
      final state = await RhythmicTimerStateService.getState(
        prefs: prefs,
        habitId: habitId,
        logicalDate: logicalDate,
      );
      if (state == null) {
        final config = await getConfig();
        final targetSongs = config?.targetSongs ?? 1;
        await RhythmicTimerStateService.initialize(
          prefs: prefs,
          habitId: habitId,
          logicalDate: logicalDate,
          totalSongs: targetSongs,
        );
      }
      // Set a placeholder song title
      await RhythmicTimerStateService.updateCurrentSong(
        prefs: prefs,
        habitId: habitId,
        logicalDate: logicalDate,
        songTitle: 'Manual Mode - Tap to mark songs complete',
      );
      return;
    }

    // Set up track change listener
    _trackSubscription?.cancel();
    _trackSubscription = _musicProvider!.trackChanges().listen((track) {
      _onTrackChanged(_musicProvider!);
    });

    // Get initial track
    final currentTrack = await _musicProvider!.getCurrentTrack();
    if (currentTrack != null) {
      await RhythmicTimerStateService.updateCurrentSong(
        prefs: prefs,
        habitId: habitId,
        logicalDate: logicalDate,
        songTitle: currentTrack.title,
      );
    } else {
      // No current track, set placeholder
      await RhythmicTimerStateService.updateCurrentSong(
        prefs: prefs,
        habitId: habitId,
        logicalDate: logicalDate,
        songTitle: 'Waiting for music...',
      );
    }

    // If using fallback audio player, start playing
    if (_musicProvider is FallbackAudioProvider && _audioPlayer != null) {
      final fallback = _musicProvider as FallbackAudioProvider;
      final track = await fallback.getCurrentTrack();
      if (track?.trackId != null) {
        try {
          // Remove 'assets/' prefix for AssetSource
          final assetPath = track!.trackId!.replaceFirst('assets/', '');
          await _audioPlayer!.play(AssetSource(assetPath));
        } catch (e) {
          // Asset not found, continue without audio
          print('Could not play audio asset: $e');
        }
      }
    }
  }

  /// Handle track change - decrement songs remaining.
  Future<void> _onTrackChanged(MusicProvider provider) async {
    if (!_isRunning) return;

    final currentTrack = await provider.getCurrentTrack();
    if (currentTrack != null) {
      // Update current song title
      await RhythmicTimerStateService.updateCurrentSong(
        prefs: prefs,
        habitId: habitId,
        logicalDate: logicalDate,
        songTitle: currentTrack.title,
      );

      // Decrement songs remaining
      final remaining = await RhythmicTimerStateService.decrementSong(
        prefs: prefs,
        habitId: habitId,
        logicalDate: logicalDate,
      );

      // Check if completed
      if (remaining <= 0) {
        await _onCompletion();
      }
    }
  }

  /// Handle timer completion.
  Future<void> _onCompletion() async {
    await pause();
    if (onHabitComplete != null) {
      await onHabitComplete!();
    }
  }

  /// Pause the timer.
  Future<void> pause() async {
    _isRunning = false;
    _trackSubscription?.cancel();
    _trackSubscription = null;

    if (_audioPlayer != null) {
      await _audioPlayer!.pause();
    }
  }

  /// Resume the timer.
  Future<void> resume() async {
    if (!_isInitialized) {
      await initialize();
    }

    final config = await getConfig();
    if (config == null) return;

    if (config.isSongBased) {
      await _startSongMode();
    }

    _isRunning = true;
  }

  /// Get current timer state.
  Future<RhythmicTimerState?> getCurrentState() async {
    final config = await getConfig();
    if (config == null) return null;

    if (config.isSongBased) {
      return await RhythmicTimerStateService.getState(
        prefs: prefs,
        habitId: habitId,
        logicalDate: logicalDate,
      );
    }

    // For time-based, return null (handled by HabitTimerStateService)
    return null;
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await pause();
    _musicProvider?.dispose();
    _musicProvider = null;
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _isInitialized = false;
  }
}
