/// CBT (Cognitive Behavioral Therapy) enhancements that can be attached to
/// habits, tasks, or checklist items.
///
/// All fields are optional and stored in a JSON-friendly way.
final class CbtEnhancements {
  final String? microVersion;
  final String? predictedObstacle;
  final String? ifThenPlan;
  /// 0-10, optional.
  final int? confidenceScore;
  final String? reward;

  const CbtEnhancements({
    this.microVersion,
    this.predictedObstacle,
    this.ifThenPlan,
    this.confidenceScore,
    this.reward,
  });

  CbtEnhancements copyWith({
    String? microVersion,
    String? predictedObstacle,
    String? ifThenPlan,
    int? confidenceScore,
    String? reward,
  }) {
    return CbtEnhancements(
      microVersion: microVersion ?? this.microVersion,
      predictedObstacle: predictedObstacle ?? this.predictedObstacle,
      ifThenPlan: ifThenPlan ?? this.ifThenPlan,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      reward: reward ?? this.reward,
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  Map<String, dynamic> toJson() => {
        'microVersion': microVersion,
        'predictedObstacle': predictedObstacle,
        'ifThenPlan': ifThenPlan,
        'confidenceScore': confidenceScore,
        'reward': reward,
      };

  factory CbtEnhancements.fromJson(Map<String, dynamic> json) => CbtEnhancements(
        // Support both camelCase and snake_case for forward compatibility.
        microVersion: (json['microVersion'] as String?) ?? (json['micro_version'] as String?),
        predictedObstacle:
            (json['predictedObstacle'] as String?) ?? (json['predicted_obstacle'] as String?),
        ifThenPlan: (json['ifThenPlan'] as String?) ?? (json['if_then_plan'] as String?),
        confidenceScore: _asInt(json['confidenceScore'] ?? json['confidence_score']),
        reward: json['reward'] as String?,
      );
}

