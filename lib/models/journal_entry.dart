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

  const JournalEntry({
    required this.id,
    required this.createdAtMs,
    required this.title,
    required this.text,
    required this.delta,
    required this.goalTitle,
    required this.tags,
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

    return JournalEntry(
      id: (json['id'] as String?) ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      title: title,
      text: (json['text'] as String?) ?? '',
      delta: (json['delta'] is List) ? (json['delta'] as List).toList() : null,
      goalTitle: legacyGoalNorm,
      tags: tags,
    );
  }
}

