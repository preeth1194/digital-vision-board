class CalorieEntry {
  final String dateKey; // 'yyyy-MM-dd'
  final int calories;
  final int goal;

  const CalorieEntry({
    required this.dateKey,
    required this.calories,
    this.goal = 2000,
  });

  CalorieEntry copyWith({int? calories, int? goal}) => CalorieEntry(
        dateKey: dateKey,
        calories: calories ?? this.calories,
        goal: goal ?? this.goal,
      );

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'calories': calories,
        'goal': goal,
      };

  factory CalorieEntry.fromJson(Map<String, dynamic> json) => CalorieEntry(
        dateKey: json['dateKey'] as String,
        calories: (json['calories'] as num).toInt(),
        goal: (json['goal'] as num?)?.toInt() ?? 2000,
      );

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
