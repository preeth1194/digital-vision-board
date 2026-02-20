import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'image_persistence.dart';

/// Handles all image picking + cropping logic.
///
/// Workflow:
/// 1) pick image via [ImagePicker]
/// 2) immediately crop via [ImageCropper]
/// 3) return the cropped file path (or null if cancelled)
class ImageService {
  ImageService._();

  static final ImagePicker _picker = ImagePicker();
  static bool _busy = false;

  /// Picks an image (gallery/camera), then opens crop UI, returning cropped path.
  ///
  /// Note: On web, cropping is not currently supported in this app flow.
  static Future<String?> pickAndCropImage(
    BuildContext context, {
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      if (kIsWeb) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image picking/cropping is not supported on web yet.'),
            ),
          );
        }
        return null;
      }

      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (picked == null) return null;

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: imageQuality ?? 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            statusBarColor: Theme.of(context).colorScheme.primary,
            activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop'),
        ],
      );
      if (cropped == null || cropped.path.isEmpty) return null;

      // Persist the cropped output into app-owned storage so it remains available
      // even if the original photo is deleted or OS temp/cache is cleared.
      try {
        final persisted = await persistImageToAppStorage(cropped.path);
        if (persisted != null && persisted.isNotEmpty) return persisted;
      } catch (_) {
        // If persistence fails, fall back to the cropped path.
      }

      return cropped.path;
    } finally {
      _busy = false;
    }
  }

  /// Picks an image (gallery/camera), crops to square, and persists to app storage.
  /// Returns the persisted path or null if cancelled.
  static Future<String?> pickAndCropProfileImage(
    BuildContext context, {
    required ImageSource source,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      if (kIsWeb) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image picking/cropping is not supported on web yet.'),
            ),
          );
        }
        return null;
      }

      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 85,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: Theme.of(context).colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            statusBarColor: Theme.of(context).colorScheme.primary,
            activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
      if (cropped == null || cropped.path.isEmpty) return null;

      try {
        final persisted = await persistImageToAppStorage(cropped.path);
        if (persisted != null && persisted.isNotEmpty) return persisted;
      } catch (_) {}

      return cropped.path;
    } finally {
      _busy = false;
    }
  }

  /// Picks an image from gallery, crops to square (1:1), and persists.
  /// Intended for puzzle image uploads where a square source is required.
  static Future<String?> pickAndCropPuzzleImage(
    BuildContext context, {
    required ImageSource source,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      if (kIsWeb) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image picking/cropping is not supported on web yet.'),
            ),
          );
        }
        return null;
      }

      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (picked == null) return null;

      return _cropToSquareAndPersist(context, picked.path);
    } finally {
      _busy = false;
    }
  }

  /// Opens the square-locked cropper on an existing file and persists the result.
  /// Used when the user selects an existing goal image for the puzzle.
  static Future<String?> cropExistingImageToSquare(
    BuildContext context, {
    required String sourcePath,
  }) async {
    if (_busy) return null;
    _busy = true;
    try {
      if (kIsWeb) return null;
      return _cropToSquareAndPersist(context, sourcePath);
    } finally {
      _busy = false;
    }
  }

  static Future<String?> _cropToSquareAndPersist(
    BuildContext context,
    String sourcePath,
  ) async {
    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressQuality: 90,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop for Puzzle',
          toolbarColor: Theme.of(context).colorScheme.primary,
          toolbarWidgetColor: Colors.white,
          statusBarColor: Theme.of(context).colorScheme.primary,
          activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop for Puzzle',
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    if (cropped == null || cropped.path.isEmpty) return null;

    try {
      final persisted = await persistImageToAppStorage(cropped.path);
      if (persisted != null && persisted.isNotEmpty) return persisted;
    } catch (_) {}

    return cropped.path;
  }

  /// Downloads an image from [url], resizes so the max side is [maxSidePx],
  /// encodes as JPEG ([jpegQuality]), and persists into app-owned storage.
  ///
  /// Returns:
  /// - IO platforms: local file path
  /// - Web: returns the URL (persistence isn't supported in this project on web)
  static Future<String?> downloadResizeAndPersistJpegFromUrl(
    BuildContext context, {
    required String url,
    int maxSidePx = 2048,
    int jpegQuality = 90,
  }) async {
    final u = url.trim();
    if (u.isEmpty) return null;
    if (kIsWeb) {
      // Web persistence is stubbed in this project; fall back to using the URL.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web: image will be used as a URL (device storage is not supported).')),
        );
      }
      return u;
    }

    try {
      final res = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 20));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not download image (${res.statusCode}).')),
          );
        }
        return null;
      }

      final bytes = Uint8List.fromList(res.bodyBytes);
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final w = decoded.width;
      final h = decoded.height;
      final maxSide = w > h ? w : h;
      final targetMax = maxSidePx.clamp(256, 8192);
      final needsResize = maxSide > targetMax;

      final out = needsResize
          ? img.copyResize(
              decoded,
              width: w >= h ? targetMax : null,
              height: h > w ? targetMax : null,
              interpolation: img.Interpolation.cubic,
            )
          : decoded;

      final q = jpegQuality.clamp(60, 95);
      final jpg = img.encodeJpg(out, quality: q);
      final persisted = await persistImageBytesToAppStorage(jpg, extension: 'jpg');
      if (persisted != null && persisted.trim().isNotEmpty) return persisted.trim();
      return null;
    } catch (e, st) {
      debugPrint('[ImageService] downloadResizeAndPersistJpegFromUrl error: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download image: $e')),
        );
      }
      return null;
    }
  }
}

