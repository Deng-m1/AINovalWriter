import 'package:equatable/equatable.dart';

/// 剧情大纲模型
class NextOutline extends Equatable {
  final String id;
  final String title;
  final String content;
  final bool isSelected;

  const NextOutline({
    required this.id,
    required this.title,
    required this.content,
    this.isSelected = false,
  });

  /// 从JSON创建NextOutline实例
  factory NextOutline.fromJson(Map<String, dynamic> json) {
    return NextOutline(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'isSelected': isSelected,
    };
  }

  /// 创建一个新的NextOutline实例，更新指定字段
  NextOutline copyWith({
    String? id,
    String? title,
    String? content,
    bool? isSelected,
  }) {
    return NextOutline(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [id, title, content, isSelected];
}

/// 剧情大纲生成请求
class GenerateNextOutlinesRequest {
  final String targetChapter;
  final int numOptions;
  final String? authorGuidance;

  GenerateNextOutlinesRequest({
    required this.targetChapter,
    required this.numOptions,
    this.authorGuidance,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'targetChapter': targetChapter,
      'numOptions': numOptions,
      'authorGuidance': authorGuidance,
    };
  }
}

/// 剧情大纲生成响应
class GenerateNextOutlinesResponse {
  final List<NextOutline> outlines;

  GenerateNextOutlinesResponse({
    required this.outlines,
  });

  /// 从JSON创建GenerateNextOutlinesResponse实例
  factory GenerateNextOutlinesResponse.fromJson(Map<String, dynamic> json) {
    return GenerateNextOutlinesResponse(
      outlines: (json['outlines'] as List<dynamic>)
          .map((e) => NextOutline.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 保存剧情大纲请求
class SaveNextOutlineRequest {
  final String outlineId;
  final String novelId;
  final String? targetChapterId;

  SaveNextOutlineRequest({
    required this.outlineId,
    required this.novelId,
    this.targetChapterId,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'outlineId': outlineId,
      'novelId': novelId,
      'targetChapterId': targetChapterId,
    };
  }
}
