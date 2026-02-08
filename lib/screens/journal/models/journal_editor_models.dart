/// Save operation status for the journal editor.
enum SaveStatus {
  idle,
  saving,
  saved,
  error,
}

/// Result returned from the journal editor screen.
final class JournalEditorResult {
  final List<dynamic> deltaJson;
  final String plainText;
  final String title;
  final List<String> tags;
  /// Legacy goal title (optional). If set, this entry is considered goal-tagged.
  final String? legacyGoalTitle;

  const JournalEditorResult({
    required this.deltaJson,
    required this.plainText,
    required this.title,
    required this.tags,
    required this.legacyGoalTitle,
  });
}

/// Represents a note item in the feed.
final class NoteFeedItem {
  final DateTime at;
  final String title;
  final String body;
  final String? subtitle;
  /// When present, this note is associated with a specific goal title.
  final String? goalTitle;

  const NoteFeedItem({
    required this.at,
    required this.title,
    required this.body,
    required this.subtitle,
    required this.goalTitle,
  });
}

/// Holds goal title and importance information.
final class GoalSummary {
  final String title;
  final String? whyImportant;

  const GoalSummary({required this.title, required this.whyImportant});
}
