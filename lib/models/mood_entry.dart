final class MoodEntry {
  final String id;
  final DateTime date;
  final int value; // 1=Awful, 2=Bad, 3=Neutral, 4=Good, 5=Great

  const MoodEntry({
    required this.id,
    required this.date,
    required this.value,
  });

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dateKey,
        'value': value,
      };

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-');
    return MoodEntry(
      id: json['id'] as String,
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      value: (json['value'] as num).toInt(),
    );
  }
}
