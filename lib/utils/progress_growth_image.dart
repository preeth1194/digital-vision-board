final class ProgressGrowthImage {
  ProgressGrowthImage._();

  static const String _basePath = 'assets/progress_growth';
  static const List<int> _orderedBuckets = [0, 15, 30, 45, 60, 75, 100];

  static List<int> orderedBuckets() => List<int>.from(_orderedBuckets);

  static int bucketForPercent(int percent) {
    final p = percent.clamp(0, 100);
    if (p >= 100) return 100;
    if (p >= 75) return 75;
    if (p >= 60) return 60;
    if (p >= 45) return 45;
    if (p >= 30) return 30;
    if (p >= 15) return 15;
    return 0;
  }

  static int percentFromProgress(double progress) {
    return (progress.clamp(0.0, 1.0) * 100).round();
  }

  static String assetForPercent(int percent) {
    final bucket = bucketForPercent(percent);
    return '$_basePath/progress_$bucket.png';
  }

  static String gifAssetForPercent(int percent) {
    final bucket = bucketForPercent(percent);
    return '$_basePath/progress_$bucket.gif';
  }

  static String assetForProgress(double progress) {
    final percent = percentFromProgress(progress);
    return assetForPercent(percent);
  }

  static String gifAssetForProgress(double progress) {
    final percent = percentFromProgress(progress);
    return gifAssetForPercent(percent);
  }

  static List<String> animationFrameAssets() {
    return _orderedBuckets
        .map((bucket) => '$_basePath/progress_$bucket.png')
        .toList(growable: false);
  }
}
