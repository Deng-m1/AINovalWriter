import 'package:json_annotation/json_annotation.dart';

part 'next_outline_dto.g.dart';

/// 生成剧情大纲请求
@JsonSerializable()
class GenerateNextOutlinesRequest {
  /// 上下文开始章节ID
  final String? startChapterId;

  /// 上下文结束章节ID
  final String? endChapterId;

  /// 生成选项数量
  final int numOptions;

  /// 作者引导
  final String? authorGuidance;

  /// 选定的AI模型配置ID列表
  final List<String>? selectedConfigIds;

  /// 重新生成提示（用于全局重新生成）
  final String? regenerateHint;

  GenerateNextOutlinesRequest({
    this.startChapterId,
    this.endChapterId,
    this.numOptions = 3,
    this.authorGuidance,
    this.selectedConfigIds,
    this.regenerateHint,
  });

  factory GenerateNextOutlinesRequest.fromJson(Map<String, dynamic> json) =>
      _$GenerateNextOutlinesRequestFromJson(json);

  Map<String, dynamic> toJson() => _$GenerateNextOutlinesRequestToJson(this);
}

/// 生成剧情大纲响应
@JsonSerializable()
class GenerateNextOutlinesResponse {
  /// 生成的大纲列表
  final List<OutlineItem> outlines;

  /// 生成时间(毫秒)
  final int generationTimeMs;

  GenerateNextOutlinesResponse({
    required this.outlines,
    required this.generationTimeMs,
  });

  factory GenerateNextOutlinesResponse.fromJson(Map<String, dynamic> json) =>
      _$GenerateNextOutlinesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GenerateNextOutlinesResponseToJson(this);
}

/// 大纲项
@JsonSerializable()
class OutlineItem {
  /// 大纲ID
  final String id;

  /// 大纲标题
  final String title;

  /// 大纲内容
  final String content;

  /// 是否被选中
  final bool isSelected;

  /// 使用的模型配置ID
  final String? configId;

  OutlineItem({
    required this.id,
    required this.title,
    required this.content,
    required this.isSelected,
    this.configId,
  });

  factory OutlineItem.fromJson(Map<String, dynamic> json) =>
      _$OutlineItemFromJson(json);

  Map<String, dynamic> toJson() => _$OutlineItemToJson(this);
}

/// 重新生成单个剧情大纲请求
@JsonSerializable()
class RegenerateOptionRequest {
  /// 选项ID
  final String optionId;

  /// 选定的AI模型配置ID
  final String selectedConfigId;

  /// 重新生成提示
  final String? regenerateHint;

  RegenerateOptionRequest({
    required this.optionId,
    required this.selectedConfigId,
    this.regenerateHint,
  });

  factory RegenerateOptionRequest.fromJson(Map<String, dynamic> json) =>
      _$RegenerateOptionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RegenerateOptionRequestToJson(this);
}

/// 保存剧情大纲请求
@JsonSerializable()
class SaveNextOutlineRequest {
  /// 大纲ID
  final String outlineId;

  /// 插入位置类型
  /// CHAPTER_END: 章节末尾
  /// BEFORE_SCENE: 场景之前
  /// AFTER_SCENE: 场景之后
  /// NEW_CHAPTER: 新建章节（默认）
  final String insertType;

  /// 目标章节ID（当insertType为CHAPTER_END时使用）
  final String? targetChapterId;

  /// 目标场景ID（当insertType为BEFORE_SCENE或AFTER_SCENE时使用）
  final String? targetSceneId;

  /// 是否创建新场景（默认为true）
  final bool createNewScene;

  SaveNextOutlineRequest({
    required this.outlineId,
    this.insertType = 'NEW_CHAPTER',
    this.targetChapterId,
    this.targetSceneId,
    this.createNewScene = true,
  });

  factory SaveNextOutlineRequest.fromJson(Map<String, dynamic> json) =>
      _$SaveNextOutlineRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SaveNextOutlineRequestToJson(this);
}

/// 保存剧情大纲响应
@JsonSerializable()
class SaveNextOutlineResponse {
  /// 是否成功
  final bool success;

  /// 保存的大纲ID
  final String outlineId;

  /// 新创建的章节ID（如果有）
  final String? newChapterId;

  /// 新创建的场景ID（如果有）
  final String? newSceneId;

  /// 目标章节ID（如果指定了现有章节）
  final String? targetChapterId;

  /// 目标场景ID（如果指定了现有场景）
  final String? targetSceneId;

  /// 插入位置类型
  final String insertType;

  /// 大纲标题（用于新章节标题）
  final String outlineTitle;

  SaveNextOutlineResponse({
    required this.success,
    required this.outlineId,
    this.newChapterId,
    this.newSceneId,
    this.targetChapterId,
    this.targetSceneId,
    required this.insertType,
    required this.outlineTitle,
  });

  factory SaveNextOutlineResponse.fromJson(Map<String, dynamic> json) =>
      _$SaveNextOutlineResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SaveNextOutlineResponseToJson(this);
}
