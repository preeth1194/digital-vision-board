class WaterIntakeEntry {
  final String dateKey; // 'yyyy-MM-dd'
  final int glasses;
  final int goal;

  const WaterIntakeEntry({
    required this.dateKey,
    required this.glasses,
    this.goal = 8,
  });

  WaterIntakeEntry copyWith({int? glasses, int? goal}) => WaterIntakeEntry(
        dateKey: dateKey,
        glasses: glasses ?? this.glasses,
        goal: goal ?? this.goal,
      );

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'glasses': glasses,
        'goal': goal,
      };

  factory WaterIntakeEntry.fromJson(Map<String, dynamic> json) =>
      WaterIntakeEntry(
        dateKey: json['dateKey'] as String,
        glasses: (json['glasses'] as num).toInt(),
        goal: (json['goal'] as num?)?.toInt() ?? 8,
      );

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
