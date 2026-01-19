import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<ImageSource?> showImageSourceSheet(BuildContext context) async {
  if (kIsWeb) return ImageSource.gallery;

  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.of(context).pop('gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a Photo'),
            onTap: () => Navigator.of(context).pop('camera'),
          ),
          ListTile(
            leading: const Icon(Icons.cancel),
            title: const Text('Cancel'),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );

  if (choice == null) return null;
  return choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
}

