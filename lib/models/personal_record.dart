/// A single logged lift entry (weight + reps for one exercise at one point in time).
class PersonalRecord {
  final String exerciseKey; // normalized: lowercase trimmed title used as storage key
  final String exerciseName; // display name
  final double weight;
  final String unit; // 'kg' or 'lb'
  final int reps;
  final DateTime achievedAt;

  const PersonalRecord({
    required this.exerciseKey,
    required this.exerciseName,
    required this.weight,
    required this.unit,
    required this.reps,
    required this.achievedAt,
  });

  /// Weight normalized to kg for comparison purposes.
  double get weightInKg => unit == 'lb' ? weight * 0.453592 : weight;

  /// Returns true if this record represents a heavier lift than [other]
  /// (normalized to kg; ties broken by reps).
  bool isBetterThan(PersonalRecord other) {
    final diff = weightInKg - other.weightInKg;
    if (diff.abs() > 0.001) return diff > 0;
    return reps > other.reps;
  }

  /// Human-readable summary, e.g. "100 kg × 5".
  String get summary {
    final w = weight == weight.truncateToDouble()
        ? weight.toInt().toString()
        : weight.toStringAsFixed(1);
    return '$w $unit × $reps';
  }

  Map<String, dynamic> toJson() => {
    'exerciseKey': exerciseKey,
    'exerciseName': exerciseName,
    'weight': weight,
    'unit': unit,
    'reps': reps,
    'achievedAt': achievedAt.toIso8601String(),
  };

  factory PersonalRecord.fromJson(Map<String, dynamic> json) {
    return PersonalRecord(
      exerciseKey: json['exerciseKey'] as String,
      exerciseName: json['exerciseName'] as String,
      weight: (json['weight'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'kg',
      reps: (json['reps'] as num).toInt(),
      achievedAt: DateTime.parse(json['achievedAt'] as String),
    );
  }

  static String normalizeKey(String exerciseName) =>
      exerciseName.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}
