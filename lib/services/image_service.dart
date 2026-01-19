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
      final res = await http.get(Uri.parse(u));
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download image.')),
        );
      }
      return null;
    }
  }
}

