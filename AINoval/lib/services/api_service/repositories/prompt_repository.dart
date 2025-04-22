import 'package:ainoval/models/prompt_models.dart';

/// 提示词管理接口
abstract class PromptRepository {
  /// 获取所有提示词
  Future<Map<AIFeatureType, PromptData>> getAllPrompts();
  
  /// 获取指定功能类型的提示词
  Future<PromptData> getPrompt(AIFeatureType featureType);
  
  /// 保存提示词
  Future<PromptData> savePrompt(AIFeatureType featureType, String promptText);
  
  /// 删除提示词（恢复为默认）
  Future<PromptData> deletePrompt(AIFeatureType featureType);
  
  /// 获取提示词模板列表
  Future<List<PromptTemplate>> getPromptTemplates();
  
  /// 获取指定功能类型的提示词模板列表
  Future<List<PromptTemplate>> getPromptTemplatesByFeatureType(AIFeatureType featureType);
  
  /// 获取提示词模板详情
  Future<PromptTemplate> getPromptTemplateById(String templateId);
  
  /// 从公共模板复制创建私有模板
  Future<PromptTemplate> copyPublicTemplate(PromptTemplate template);
  
  /// 切换模板收藏状态
  Future<PromptTemplate> toggleTemplateFavorite(PromptTemplate template);
  
  /// 创建提示词模板
  Future<PromptTemplate> createPromptTemplate({
    required String name,
    required String content,
    required AIFeatureType featureType,
    required String authorId,
  });
  
  /// 更新提示词模板
  Future<PromptTemplate> updatePromptTemplate({
    required String templateId,
    String? name,
    String? content,
  });
  
  /// 删除提示词模板
  Future<void> deletePromptTemplate(String templateId);
  
  /// 流式优化提示词
  void optimizePromptStream(
    String templateId,
    OptimizePromptRequest request, {
    Function(double)? onProgress,
    Function(OptimizationResult)? onResult,
    Function(String)? onError,
  });
  
  /// 取消优化
  void cancelOptimization();
  
  /// 优化提示词
  Future<OptimizationResult> optimizePrompt({
    required String templateId,
    required OptimizePromptRequest request,
  });
  
  /// 生成场景摘要
  Future<String> generateSceneSummary({
    required String novelId,
    required String sceneId,
  });
  
  /// 从摘要生成场景
  Future<String> generateSceneFromSummary({
    required String novelId,
    required String summary,
  });
}