import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Reusable image picking + cropping helper.
///
/// Workflow:
/// 1) pick image via [ImagePicker]
/// 2) immediately crop via [ImageCropper]
/// 3) return the cropped file path (or null if cancelled)
class ImagePickCropService {
  ImagePickCropService._();

  static final ImagePicker _picker = ImagePicker();

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
    if (kIsWeb) {
      // Keep behavior explicit; current app already treats image editing on web as limited.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image picking/cropping is not supported on web yet.')),
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
      compressQuality: imageQuality,
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
        IOSUiSettings(
          title: 'Crop',
        ),
      ],
    );

    // Requirement: only add cropped file; if cancelled, return null.
    return cropped?.path;
  }
}

