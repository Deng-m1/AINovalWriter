import 'package:ainoval/models/prompt_models.dart';

/// 提示词仓库接口
abstract class PromptRepository {
  /// 获取所有提示词
  Future<Map<AIFeatureType, PromptData>> getAllPrompts();
  
  /// 获取指定类型的提示词
  Future<PromptData> getPrompt(AIFeatureType featureType);
  
  /// 保存/更新提示词
  Future<PromptData> savePrompt(AIFeatureType featureType, String promptText);
  
  /// 删除提示词（恢复为默认）
  Future<void> deletePrompt(AIFeatureType featureType);
} 