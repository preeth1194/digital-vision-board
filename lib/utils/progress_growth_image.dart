final class ProgressGrowthImage {
  ProgressGrowthImage._();

  static const String _basePath = 'assets/progress_growth';

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

  static String assetForProgress(double progress) {
    final percent = percentFromProgress(progress);
    return assetForPercent(percent);
  }
}
