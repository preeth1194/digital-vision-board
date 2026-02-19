import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../services/image_service.dart';
import '../../services/puzzle_service.dart';
import '../../utils/file_image_provider.dart';

/// Shows a bottom sheet to select a puzzle image from available goal images.
Future<String?> showPuzzleImageSelectorSheet(
  BuildContext context, {
  required List<VisionBoardInfo> boards,
  SharedPreferences? prefs,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: _PuzzleImageSelectorContent(
            boards: boards,
            prefs: prefs,
          ),
        ),
      );
    },
  );
}

class _PuzzleImageSelectorContent extends StatefulWidget {
  final List<VisionBoardInfo> boards;
  final SharedPreferences? prefs;

  const _PuzzleImageSelectorContent({
    required this.boards,
    this.prefs,
  });

  @override
  State<_PuzzleImageSelectorContent> createState() =>
      _PuzzleImageSelectorContentState();
}

class _PuzzleImageSelectorContentState
    extends State<_PuzzleImageSelectorContent> {
  bool _loading = true;
  List<String> _availableImages = [];
  String? _currentPuzzleImage;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);

    final images = await PuzzleService.getAllAvailableGoalImages(
      boards: widget.boards,
      prefs: widget.prefs,
    );

    final current = await PuzzleService.getCurrentPuzzleImage(
      boards: widget.boards,
      prefs: widget.prefs,
    );

    if (!mounted) return;
    setState(() {
      _availableImages = images;
      _currentPuzzleImage = current;
      _loading = false;
    });
  }

  Future<void> _pickFromGallery() async {
    final cropped = await ImageService.pickAndCropPuzzleImage(
      context,
      source: ImageSource.gallery,
    );
    if (cropped == null || !mounted) return;
    Navigator.of(context).pop(cropped);
  }

  Future<void> _cropAndSelect(String imagePath) async {
    final cropped = await ImageService.cropExistingImageToSquare(
      context,
      sourcePath: imagePath,
    );
    if (!mounted) return;
    Navigator.of(context).pop(cropped ?? imagePath);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Select Puzzle Image',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        if (_loading)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _availableImages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return InkWell(
                    onTap: _pickFromGallery,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.2),
                        ),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 8),
                          Text('Upload Image',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                        ],
                      ),
                    ),
                  );
                }
                final imagePath = _availableImages[index - 1];
                final isSelected = imagePath == _currentPuzzleImage;
                final provider = fileImageProviderFromPath(imagePath);

                return InkWell(
                  onTap: () => _cropAndSelect(imagePath),
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.2),
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: provider != null
                            ? Image(
                                image: provider,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .errorContainer,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
