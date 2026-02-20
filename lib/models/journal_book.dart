/// Represents a journal book that can contain multiple journal entries.
final class JournalBook {
  /// Unique identifier for this book.
  final String id;

  /// Display name of the book.
  final String name;

  /// Timestamp when the book was created (milliseconds since epoch).
  final int createdAtMs;

  /// Optional icon code point for custom book icon.
  /// Stored as int to allow serialization. Use IconData(iconCodePoint, fontFamily: 'MaterialIcons') to convert.
  final int? iconCodePoint;

  /// Optional subtitle for the book cover.
  final String? subtitle;

  /// Cover color as hex value (e.g., 0xFFE57373 for coral red).
  /// Stored as int to allow serialization. Use Color(coverColor) to convert.
  final int? coverColor;

  /// Path to custom cover image (if user uploaded one).
  final String? coverImagePath;

  const JournalBook({
    required this.id,
    required this.name,
    required this.createdAtMs,
    this.iconCodePoint,
    this.subtitle,
    this.coverColor,
    this.coverImagePath,
  });

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAtMs': createdAtMs,
        if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
        if (subtitle != null) 'subtitle': subtitle,
        if (coverColor != null) 'coverColor': coverColor,
        if (coverImagePath != null) 'coverImagePath': coverImagePath,
      };

  factory JournalBook.fromJson(Map<String, dynamic> json) {
    return JournalBook(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Untitled',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt(),
      subtitle: json['subtitle'] as String?,
      coverColor: (json['coverColor'] as num?)?.toInt(),
      coverImagePath: json['coverImagePath'] as String?,
    );
  }

  JournalBook copyWith({
    String? id,
    String? name,
    int? createdAtMs,
    int? iconCodePoint,
    String? subtitle,
    int? coverColor,
    String? coverImagePath,
  }) {
    return JournalBook(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      subtitle: subtitle ?? this.subtitle,
      coverColor: coverColor ?? this.coverColor,
      coverImagePath: coverImagePath ?? this.coverImagePath,
    );
  }

  /// Default cover color (red).
  static const int defaultCoverColor = 0xFFEF4444;

  /// Preset cover colors for the color picker.
  /// Uses the same 7 colors as the habit system (light variants).
  static const List<int> presetColors = [
    0xFFEF4444, // Red   (habitRedLight)
    0xFFF97316, // Orange (habitOrangeLight)
    0xFFEAB308, // Yellow (habitYellowLight)
    0xFF22C55E, // Green  (habitGreenLight)
    0xFF3B82F6, // Blue   (habitBlueLight)
    0xFF6366F1, // Indigo (habitIndigoLight)
    0xFF8B5CF6, // Violet (habitVioletLight)
  ];
}
