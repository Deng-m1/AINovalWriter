import 'package:json_annotation/json_annotation.dart';


/// AI功能类型枚举
enum AIFeatureType {
  /// 场景生成摘要
  sceneToSummary,
  
  /// 摘要生成场景
  summaryToScene
}

/// 提示词数据模型
class PromptData {
  /// 用户自定义提示词
  final String userPrompt;
  
  /// 系统默认提示词
  final String defaultPrompt;
  
  /// 是否为用户自定义
  final bool isCustomized;

  PromptData({
    required this.userPrompt,
    required this.defaultPrompt,
    required this.isCustomized,
  });
  
  /// 获取当前生效的提示词（如果自定义则返回用户提示词，否则返回默认提示词）
  String get activePrompt => isCustomized ? userPrompt : defaultPrompt;
}

/// 用户提示词模板DTO
class UserPromptTemplateDto {
  /// 功能类型
  final AIFeatureType featureType;
  
  /// 提示词文本
  final String promptText;

  UserPromptTemplateDto({
    required this.featureType,
    required this.promptText,
  });

  factory UserPromptTemplateDto.fromJson(Map<String, dynamic> json) {
    String featureTypeStr = json['featureType'] as String;
    AIFeatureType type;
    
    // 根据字符串解析枚举
    switch (featureTypeStr) {
      case 'SCENE_TO_SUMMARY':
        type = AIFeatureType.sceneToSummary;
        break;
      case 'SUMMARY_TO_SCENE':
        type = AIFeatureType.summaryToScene;
        break;
      default:
        throw ArgumentError('未知的功能类型: $featureTypeStr');
    }
    
    return UserPromptTemplateDto(
      featureType: type,
      promptText: json['promptText'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    String featureTypeStr;
    
    // 将枚举转换为字符串
    switch (featureType) {
      case AIFeatureType.sceneToSummary:
        featureTypeStr = 'SCENE_TO_SUMMARY';
        break;
      case AIFeatureType.summaryToScene:
        featureTypeStr = 'SUMMARY_TO_SCENE';
        break;
    }
    
    return {
      'featureType': featureTypeStr,
      'promptText': promptText,
    };
  }
}

/// 更新提示词请求DTO
class UpdatePromptRequest {
  /// 提示词文本
  final String promptText;

  UpdatePromptRequest({
    required this.promptText,
  });

  factory UpdatePromptRequest.fromJson(Map<String, dynamic> json) {
    return UpdatePromptRequest(
      promptText: json['promptText'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'promptText': promptText,
    };
  }
} 