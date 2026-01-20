/// Model representing an affirmation for vision board categories
final class Affirmation {
  final String id;
  final String? category;
  final String text;
  final bool isPinned;
  final bool isCustom;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Affirmation({
    required this.id,
    this.category,
    required this.text,
    this.isPinned = false,
    this.isCustom = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'text': text,
        'is_pinned': isPinned,
        'is_custom': isCustom,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Affirmation.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return Affirmation(
      id: (json['id'] as String?) ?? '',
      category: (json['category'] as String?)?.trim(),
      text: (json['text'] as String?) ?? '',
      isPinned: (json['is_pinned'] as bool?) ?? (json['isPinned'] as bool?) ?? false,
      isCustom: (json['is_custom'] as bool?) ?? (json['isCustom'] as bool?) ?? true,
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Affirmation copyWith({
    String? id,
    String? category,
    String? text,
    bool? isPinned,
    bool? isCustom,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Affirmation(
      id: id ?? this.id,
      category: category ?? this.category,
      text: text ?? this.text,
      isPinned: isPinned ?? this.isPinned,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
