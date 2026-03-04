import 'package:flutter/material.dart';

import '../../utils/progress_growth_image.dart';

/// Shows a stage PNG by default and plays the matching stage GIF on tap.
class InteractiveProgressGrowthImage extends StatefulWidget {
  final double progress;
  final double width;
  final double height;
  final BoxFit fit;
  final Duration gifDisplayDuration;

  const InteractiveProgressGrowthImage({
    super.key,
    required this.progress,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
    this.gifDisplayDuration = const Duration(milliseconds: 1200),
  });

  @override
  State<InteractiveProgressGrowthImage> createState() =>
      _InteractiveProgressGrowthImageState();
}

class _InteractiveProgressGrowthImageState
    extends State<InteractiveProgressGrowthImage> {
  bool _showGif = false;

  String get _staticAsset => ProgressGrowthImage.assetForProgress(widget.progress);
  String get _gifAsset => ProgressGrowthImage.gifAssetForProgress(widget.progress);

  @override
  void didUpdateWidget(covariant InteractiveProgressGrowthImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress && _showGif) {
      _showGif = false;
    }
  }

  void _playAnimation() {
    if (!_showGif) {
      setState(() => _showGif = true);
    }
    Future<void>.delayed(widget.gifDisplayDuration, () {
      if (!mounted) return;
      setState(() => _showGif = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _playAnimation(),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: _showGif
              ? Image.asset(
                  _gifAsset,
                  key: ValueKey<String>(_gifAsset),
                  fit: widget.fit,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      _staticAsset,
                      fit: widget.fit,
                    );
                  },
                )
              : Image.asset(
                  _staticAsset,
                  key: ValueKey<String>(_staticAsset),
                  fit: widget.fit,
                ),
        ),
      ),
    );
  }
}
