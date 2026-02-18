/// Conversion helpers for weight and height between metric and imperial units.
/// Backend stores metric (kg, cm); UI may display in imperial (lb, ft/in).
class MeasurementUtils {
  MeasurementUtils._();

  static const double _lbPerKg = 2.20462;
  static const double _cmPerInch = 2.54;

  static double kgToLb(double kg) => kg * _lbPerKg;
  static double lbToKg(double lb) => lb / _lbPerKg;

  static double cmToInches(double cm) => cm / _cmPerInch;
  static double inchesToCm(double inches) => inches * _cmPerInch;

  /// Converts cm to feet and inches. Returns (feet, inches) where inches is 0-11.
  static (int feet, int inches) cmToFtIn(double cm) {
    final totalInches = cmToInches(cm);
    var ft = (totalInches / 12).floor();
    var inVal = (totalInches - ft * 12).round();
    if (inVal >= 12) {
      inVal = 0;
      ft += 1;
    }
    return (ft, inVal);
  }

  /// Converts feet and inches to cm.
  static double ftInToCm(int feet, int inches) {
    final totalInches = (feet * 12) + inches;
    return inchesToCm(totalInches.toDouble());
  }
}
