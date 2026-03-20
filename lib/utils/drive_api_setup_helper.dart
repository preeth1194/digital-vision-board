/// Parses Google Drive client errors when the Drive API is disabled for a GCP project.
final class DriveApiSetupHelper {
  DriveApiSetupHelper._();

  static final _embeddedConsoleLink = RegExp(
    r'https://console\.developers\.google\.com/apis/api/drive\.googleapis\.com/overview\?project=\d+',
  );

  static final _projectInSentence =
      RegExp(r'in project (\d+) before or it is disabled', caseSensitive: false);

  /// True when the error matches "Drive API not enabled" (common [DetailedApiRequestError] text).
  static bool isDriveApiDisabledError(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final lower = raw.toLowerCase();
    if (raw.contains('Google Drive API has not been used')) return true;
    if (lower.contains('drive.googleapis.com') &&
        lower.contains('403') &&
        (lower.contains('disabled') || lower.contains('not been used'))) {
      return true;
    }
    return false;
  }

  /// Console URL to enable Drive API, from the error string if possible.
  static Uri? consoleUrlFromDriveError(String raw) {
    final fromLink = _embeddedConsoleLink.firstMatch(raw);
    if (fromLink != null) {
      return Uri.tryParse(fromLink.group(0)!);
    }
    final proj = _projectInSentence.firstMatch(raw)?.group(1) ??
        RegExp(r'project=(\d+)').firstMatch(raw)?.group(1);
    if (proj == null || proj.isEmpty) return null;
    return Uri.parse(
      'https://console.developers.google.com/apis/api/drive.googleapis.com/overview?project=$proj',
    );
  }

  static const friendlyMessage =
      'Google Drive isn\u2019t enabled for this app\u2019s cloud project yet. '
      'Turn on the Google Drive API in Google Cloud Console, wait a minute, '
      'then try Back Up Now again.';
}
