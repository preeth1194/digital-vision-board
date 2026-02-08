final class JournalEntry {
  final String id;
  final int createdAtMs;
  /// Optional heading/title for the entry (displayed in lists).
  final String? title;
  /// Legacy plain-text representation (kept for backwards compatibility and quick previews).
  final String text;
  /// Rich-text Quill Delta JSON (ops list). When present, this is the canonical content.
  final List<dynamic>? delta;
  /// Optional legacy goal tag (goal title).
  ///
  /// Kept for backward compatibility; new code should use [tags] and treat any tag
  /// matching a goal title as a goal tag.
  final String? goalTitle;
  /// Tags for this entry (supports custom tags and goal-title tags).
  ///
  /// Stored as a list of strings; normalized to trimmed, non-empty, unique values.
  final List<String> tags;
  /// Local file paths to images associated with this entry.
  ///
  /// Images are stored in the app's documents directory and persist even if deleted from gallery.
  final List<String> imagePaths;
  /// Selected font for this entry (font family name).
  ///
  /// Defaults to null (uses app default). When set, the editor will use this font.
  final String? selectedFont;
  /// Position and size data for floating images.
  ///
  /// Each entry is a map with keys: imagePath, x, y, width, zIndex.
  /// Stored as a list of position/size maps for each image.
  final List<Map<String, dynamic>>? imagePositions;
  /// Local file paths to audio voice notes associated with this entry.
  ///
  /// Audio files are stored in the app's documents directory.
  final List<String> audioPaths;

  /// ID of the journal book this entry belongs to.
  ///
  /// Nullable for backward compatibility with existing entries.
  /// Entries without a bookId are treated as belonging to the default book.
  final String? bookId;

  const JournalEntry({
    required this.id,
    required this.createdAtMs,
    required this.title,
    required this.text,
    required this.delta,
    required this.goalTitle,
    required this.tags,
    this.imagePaths = const [],
    this.selectedFont,
    this.imagePositions,
    this.audioPaths = const [],
    this.bookId,
  });

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAtMs': createdAtMs,
        'title': title,
        'text': text,
        'delta': delta,
        'goalTitle': goalTitle,
        'tags': tags,
        'imagePaths': imagePaths,
        if (selectedFont != null) 'selectedFont': selectedFont,
        if (imagePositions != null) 'imagePositions': imagePositions,
        'audioPaths': audioPaths,
        if (bookId != null) 'bookId': bookId,
      };

  static List<String> _normalizeTags(Iterable<dynamic> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final x in raw) {
      final s = (x is String) ? x.trim() : '';
      if (s.isEmpty) continue;
      if (seen.add(s)) out.add(s);
    }
    return out;
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final legacyGoalTitle = (json['goalTitle'] as String?)?.trim();
    final legacyGoalNorm = (legacyGoalTitle == null || legacyGoalTitle.isEmpty) ? null : legacyGoalTitle;
    final tags = (json['tags'] is List)
        ? _normalizeTags((json['tags'] as List).toList())
        : (legacyGoalNorm == null ? const <String>[] : <String>[legacyGoalNorm]);
    final rawTitle = (json['title'] as String?)?.trim();
    final title = (rawTitle == null || rawTitle.isEmpty) ? null : rawTitle;
    final imagePaths = (json['imagePaths'] is List)
        ? (json['imagePaths'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final selectedFont = (json['selectedFont'] as String?)?.trim();
    final imagePositions = (json['imagePositions'] is List)
        ? (json['imagePositions'] as List)
            .whereType<Map<String, dynamic>>()
            .toList()
        : null;
    final audioPaths = (json['audioPaths'] is List)
        ? (json['audioPaths'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final bookId = (json['bookId'] as String?)?.trim();

    return JournalEntry(
      id: (json['id'] as String?) ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      title: title,
      text: (json['text'] as String?) ?? '',
      delta: (json['delta'] is List) ? (json['delta'] as List).toList() : null,
      goalTitle: legacyGoalNorm,
      tags: tags,
      imagePaths: imagePaths,
      selectedFont: (selectedFont == null || selectedFont.isEmpty) ? null : selectedFont,
      imagePositions: imagePositions,
      audioPaths: audioPaths,
      bookId: (bookId == null || bookId.isEmpty) ? null : bookId,
    );
  }
}

