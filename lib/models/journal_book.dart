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

  /// Default cover color (coral red).
  static const int defaultCoverColor = 0xFFE57373;

  /// Preset cover colors for the color picker.
  static const List<int> presetColors = [
    0xFFE57373, // Coral Red
    0xFFFFB74D, // Orange
    0xFFFFF176, // Yellow
    0xFFAED581, // Light Green
    0xFF4DB6AC, // Teal
    0xFF64B5F6, // Blue
    0xFF9575CD, // Purple
    0xFFF06292, // Pink
    0xFFA1887F, // Brown
    0xFF90A4AE, // Blue Grey
  ];
}
