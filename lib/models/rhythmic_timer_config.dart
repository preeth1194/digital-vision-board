/// Configuration for rhythmic timer modes (Time-Based or Song-Based).
final class RhythmicTimerConfig {
  /// Timer mode: 'time' for time-based, 'song' for song-based.
  final String mode; // 'time' | 'song'

  /// Target number of songs (only used in song mode).
  final int? targetSongs;

  /// Linked music provider: 'spotify' | 'apple_music' | null.
  final String? linkedProvider;

  /// Playlist ID for linked music provider.
  final String? playlistId;

  /// Fallback audio assets to use when no provider is linked.
  final List<String>? fallbackAudioAssets;

  const RhythmicTimerConfig({
    required this.mode,
    this.targetSongs,
    this.linkedProvider,
    this.playlistId,
    this.fallbackAudioAssets,
  });

  bool get isTimeBased => mode == 'time';
  bool get isSongBased => mode == 'song';

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'targetSongs': targetSongs,
        'linkedProvider': linkedProvider,
        'playlistId': playlistId,
        'fallbackAudioAssets': fallbackAudioAssets,
      };

  factory RhythmicTimerConfig.fromJson(Map<String, dynamic> json) {
    return RhythmicTimerConfig(
      mode: (json['mode'] as String?) ?? 'time',
      targetSongs: (json['targetSongs'] as num?)?.toInt(),
      linkedProvider: json['linkedProvider'] as String?,
      playlistId: json['playlistId'] as String?,
      fallbackAudioAssets: (json['fallbackAudioAssets'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  RhythmicTimerConfig copyWith({
    String? mode,
    int? targetSongs,
    String? linkedProvider,
    String? playlistId,
    List<String>? fallbackAudioAssets,
  }) {
    return RhythmicTimerConfig(
      mode: mode ?? this.mode,
      targetSongs: targetSongs ?? this.targetSongs,
      linkedProvider: linkedProvider ?? this.linkedProvider,
      playlistId: playlistId ?? this.playlistId,
      fallbackAudioAssets: fallbackAudioAssets ?? this.fallbackAudioAssets,
    );
  }
}
