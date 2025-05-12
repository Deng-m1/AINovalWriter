import 'package:json_annotation/json_annotation.dart';

/// 生成剧情大纲请求
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

  factory GenerateNextOutlinesRequest.fromJson(Map<String, dynamic> json) {
    return GenerateNextOutlinesRequest(
      startChapterId: json['startChapterId'] as String?,
      endChapterId: json['endChapterId'] as String?,
      numOptions: json['numOptions'] as int? ?? 3,
      authorGuidance: json['authorGuidance'] as String?,
      selectedConfigIds: (json['selectedConfigIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      regenerateHint: json['regenerateHint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (startChapterId != null) 'startChapterId': startChapterId,
      if (endChapterId != null) 'endChapterId': endChapterId,
      'numOptions': numOptions,
      if (authorGuidance != null) 'authorGuidance': authorGuidance,
      if (selectedConfigIds != null) 'selectedConfigIds': selectedConfigIds,
      if (regenerateHint != null) 'regenerateHint': regenerateHint,
    };
  }
}

/// 生成剧情大纲响应
class GenerateNextOutlinesResponse {
  /// 生成的大纲列表
  final List<OutlineItem> outlines;

  /// 生成时间(毫秒)
  final int generationTimeMs;

  GenerateNextOutlinesResponse({
    required this.outlines,
    required this.generationTimeMs,
  });

  factory GenerateNextOutlinesResponse.fromJson(Map<String, dynamic> json) {
    return GenerateNextOutlinesResponse(
      outlines: (json['outlines'] as List<dynamic>)
          .map((e) => OutlineItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      generationTimeMs: json['generationTimeMs'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outlines': outlines.map((e) => e.toJson()).toList(),
      'generationTimeMs': generationTimeMs,
    };
  }
}

/// 大纲项
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

  factory OutlineItem.fromJson(Map<String, dynamic> json) {
    return OutlineItem(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      isSelected: json['isSelected'] as bool,
      configId: json['configId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'isSelected': isSelected,
      if (configId != null) 'configId': configId,
    };
  }
}

/// 重新生成单个剧情大纲请求
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

  factory RegenerateOptionRequest.fromJson(Map<String, dynamic> json) {
    return RegenerateOptionRequest(
      optionId: json['optionId'] as String,
      selectedConfigId: json['selectedConfigId'] as String,
      regenerateHint: json['regenerateHint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'optionId': optionId,
      'selectedConfigId': selectedConfigId,
      if (regenerateHint != null) 'regenerateHint': regenerateHint,
    };
  }
}

/// 保存剧情大纲请求
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

  factory SaveNextOutlineRequest.fromJson(Map<String, dynamic> json) {
    return SaveNextOutlineRequest(
      outlineId: json['outlineId'] as String,
      insertType: json['insertType'] as String? ?? 'NEW_CHAPTER',
      targetChapterId: json['targetChapterId'] as String?,
      targetSceneId: json['targetSceneId'] as String?,
      createNewScene: json['createNewScene'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outlineId': outlineId,
      'insertType': insertType,
      if (targetChapterId != null) 'targetChapterId': targetChapterId,
      if (targetSceneId != null) 'targetSceneId': targetSceneId,
      'createNewScene': createNewScene,
    };
  }
}

/// 保存剧情大纲响应
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

  factory SaveNextOutlineResponse.fromJson(Map<String, dynamic> json) {
    return SaveNextOutlineResponse(
      success: json['success'] as bool,
      outlineId: json['outlineId'] as String,
      newChapterId: json['newChapterId'] as String?,
      newSceneId: json['newSceneId'] as String?,
      targetChapterId: json['targetChapterId'] as String?,
      targetSceneId: json['targetSceneId'] as String?,
      insertType: json['insertType'] as String,
      outlineTitle: json['outlineTitle'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'outlineId': outlineId,
      if (newChapterId != null) 'newChapterId': newChapterId,
      if (newSceneId != null) 'newSceneId': newSceneId,
      if (targetChapterId != null) 'targetChapterId': targetChapterId,
      if (targetSceneId != null) 'targetSceneId': targetSceneId,
      'insertType': insertType,
      'outlineTitle': outlineTitle,
    };
  }
}

/// 大纲生成输出结果
class NextOutlineOutput {
  /// 大纲列表
  final List<NextOutlineDTO> outlineList;
  
  /// 生成时间(毫秒)
  final int generationTimeMs;
  
  /// 所选大纲索引
  final int? selectedOutlineIndex;

  NextOutlineOutput({
    required this.outlineList,
    required this.generationTimeMs,
    this.selectedOutlineIndex,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'outlineList': outlineList.map((e) => e.toJson()).toList(),
      'generationTimeMs': generationTimeMs,
      if (selectedOutlineIndex != null) 'selectedOutlineIndex': selectedOutlineIndex,
    };
  }
}

/// 剧情大纲DTO
class NextOutlineDTO {
  /// 大纲ID
  final String id;
  
  /// 大纲标题
  final String title;
  
  /// 大纲内容
  final String content;
  
  /// 模型配置ID
  final String? configId;

  NextOutlineDTO({
    required this.id,
    required this.title,
    required this.content,
    this.configId,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      if (configId != null) 'configId': configId,
    };
  }
}
