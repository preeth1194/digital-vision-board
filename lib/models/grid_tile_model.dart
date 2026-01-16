import 'package:flutter/foundation.dart';

/// Data model for a tile in a structured (staggered) grid vision board.
///
/// - `type`: `'image'` or `'text'`
/// - `content`: file path (image) or text content
@immutable
class GridTileModel {
  final String id;
  final String type; // 'empty' | 'image' | 'text'
  final String? content;
  final int crossAxisCellCount;
  final int mainAxisCellCount;
  final int index;

  const GridTileModel({
    required this.id,
    required this.type,
    required this.content,
    required this.crossAxisCellCount,
    required this.mainAxisCellCount,
    required this.index,
  });

  GridTileModel copyWith({
    String? id,
    String? type,
    String? content,
    int? crossAxisCellCount,
    int? mainAxisCellCount,
    int? index,
  }) {
    return GridTileModel(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      crossAxisCellCount: crossAxisCellCount ?? this.crossAxisCellCount,
      mainAxisCellCount: mainAxisCellCount ?? this.mainAxisCellCount,
      index: index ?? this.index,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'content': content,
        'crossAxisCellCount': crossAxisCellCount,
        'mainAxisCellCount': mainAxisCellCount,
        'index': index,
      };

  factory GridTileModel.fromJson(Map<String, dynamic> json) {
    return GridTileModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'empty',
      content: json['content'] as String?,
      crossAxisCellCount: (json['crossAxisCellCount'] as num?)?.toInt() ?? 1,
      mainAxisCellCount: (json['mainAxisCellCount'] as num?)?.toInt() ?? 1,
      index: (json['index'] as num?)?.toInt() ?? 0,
    );
  }
}

