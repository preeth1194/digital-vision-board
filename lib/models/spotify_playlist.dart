/// Model representing a Spotify playlist
final class SpotifyPlaylist {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? ownerName;
  final int? trackCount;
  final String? uri;

  const SpotifyPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.ownerName,
    this.trackCount,
    this.uri,
  });

  factory SpotifyPlaylist.fromJson(Map<String, dynamic> json) {
    return SpotifyPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      ownerName: json['ownerName'] as String?,
      trackCount: (json['trackCount'] as num?)?.toInt(),
      uri: json['uri'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'ownerName': ownerName,
        'trackCount': trackCount,
        'uri': uri,
      };
}

/// Model representing a Spotify track/song
final class SpotifyTrack {
  final String id;
  final String name;
  final String? artist;
  final String? album;
  final String? imageUrl;
  final int? durationMs;
  final String? uri;

  const SpotifyTrack({
    required this.id,
    required this.name,
    this.artist,
    this.album,
    this.imageUrl,
    this.durationMs,
    this.uri,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    return SpotifyTrack(
      id: json['id'] as String,
      name: json['name'] as String,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      imageUrl: json['imageUrl'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt(),
      uri: json['uri'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artist': artist,
        'album': album,
        'imageUrl': imageUrl,
        'durationMs': durationMs,
        'uri': uri,
      };

  String get displayTitle => name;
  String get displaySubtitle {
    if (artist != null && album != null) {
      return '$artist • $album';
    } else if (artist != null) {
      return artist!;
    } else if (album != null) {
      return album!;
    }
    return '';
  }
}
