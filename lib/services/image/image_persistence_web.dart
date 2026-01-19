Future<String?> persistImageToAppStorage(String sourcePath) async {
  // This app’s image flows are currently not supported on web (picker/cropper).
  // Keep this as a safe stub so the project still compiles for web.
  return null;
}

Future<String?> persistImageBytesToAppStorage(
  List<int> bytes, {
  required String extension,
}) async {
  return null;
}

