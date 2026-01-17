import 'package:flutter/foundation.dart';

@immutable
class BoardTemplateSummary {
  final String id;
  final String name;
  /// 'goal_canvas' | 'grid'
  final String kind;
  /// Relative path from backend (e.g. '/template-images/...') or null.
  final String? previewImageUrl;

  const BoardTemplateSummary({
    required this.id,
    required this.name,
    required this.kind,
    required this.previewImageUrl,
  });

  factory BoardTemplateSummary.fromJson(Map<String, dynamic> json) {
    return BoardTemplateSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      kind: json['kind'] as String? ?? 'goal_canvas',
      previewImageUrl: json['previewImageUrl'] as String?,
    );
  }
}

@immutable
class BoardTemplate {
  final String id;
  final String name;
  final String kind; // 'goal_canvas' | 'grid'
  final String? previewImageUrl;
  final Map<String, dynamic> templateJson;

  const BoardTemplate({
    required this.id,
    required this.name,
    required this.kind,
    required this.previewImageUrl,
    required this.templateJson,
  });

  factory BoardTemplate.fromJson(Map<String, dynamic> json) {
    final tj = json['templateJson'];
    return BoardTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled',
      kind: json['kind'] as String? ?? 'goal_canvas',
      previewImageUrl: json['previewImageUrl'] as String?,
      templateJson: (tj is Map<String, dynamic>) ? tj : <String, dynamic>{},
    );
  }
}

