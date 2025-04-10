import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/utils/logger.dart';

/// 提示词仓库实现
class PromptRepositoryImpl implements PromptRepository {
  final ApiClient _apiClient;
  static const String _baseUrl = '/api/users/me/prompts';
  static const String _tag = 'PromptRepositoryImpl';

  /// 构造函数
  PromptRepositoryImpl(this._apiClient);

  @override
  Future<Map<AIFeatureType, PromptData>> getAllPrompts() async {
    try {
      final result = await _apiClient.get(_baseUrl);
      if (result is List) {
        final Map<AIFeatureType, PromptData> prompts = {};
        for (final item in result) {
          try {
            final dto = UserPromptTemplateDto.fromJson(item);
            // 获取默认提示词
            final defaultPrompt = await _getDefaultPrompt(dto.featureType);
            // 创建PromptData
            prompts[dto.featureType] = PromptData(
              userPrompt: dto.promptText,
              defaultPrompt: defaultPrompt,
              isCustomized: true,
            );
          } catch (e) {
            AppLogger.e(_tag, '解析提示词失败: $item', e);
          }
        }
        return prompts;
      } else {
        throw Exception('获取提示词列表失败: 响应格式错误');
      }
    } catch (e) {
      AppLogger.e(_tag, '获取所有提示词失败', e);
      throw Exception('获取提示词列表失败: ${e.toString()}');
    }
  }

  @override
  Future<PromptData> getPrompt(AIFeatureType featureType) async {
    try {
      final url = '$_baseUrl/${featureType.toString().split('.').last}';
      final result = await _apiClient.get(url);
      final dto = UserPromptTemplateDto.fromJson(result);
      
      // 获取默认提示词
      final defaultPrompt = await _getDefaultPrompt(featureType);
      
      return PromptData(
        userPrompt: dto.promptText,
        defaultPrompt: defaultPrompt,
        isCustomized: true,
      );
    } catch (e) {
      // 如果获取失败，尝试获取默认提示词
      try {
        final defaultPrompt = await _getDefaultPrompt(featureType);
        return PromptData(
          userPrompt: defaultPrompt,
          defaultPrompt: defaultPrompt,
          isCustomized: false,
        );
      } catch (e2) {
        AppLogger.e(_tag, '获取提示词失败: $featureType', e2);
        throw Exception('获取提示词失败: ${e2.toString()}');
      }
    }
  }

  @override
  Future<PromptData> savePrompt(AIFeatureType featureType, String promptText) async {
    try {
      final url = '$_baseUrl/${featureType.toString().split('.').last}';
      final request = UpdatePromptRequest(promptText: promptText);
      final result = await _apiClient.put(url, data: request.toJson());
      final dto = UserPromptTemplateDto.fromJson(result);
      
      // 获取默认提示词
      final defaultPrompt = await _getDefaultPrompt(featureType);
      
      return PromptData(
        userPrompt: dto.promptText,
        defaultPrompt: defaultPrompt,
        isCustomized: true,
      );
    } catch (e) {
      AppLogger.e(_tag, '保存提示词失败: $featureType', e);
      throw Exception('保存提示词失败: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePrompt(AIFeatureType featureType) async {
    try {
      final url = '$_baseUrl/${featureType.toString().split('.').last}';
      await _apiClient.delete(url);
    } catch (e) {
      AppLogger.e(_tag, '删除提示词失败: $featureType', e);
      throw Exception('删除提示词失败: ${e.toString()}');
    }
  }

  /// 获取默认提示词
  Future<String> _getDefaultPrompt(AIFeatureType featureType) async {
    // 这里应该有一个用于获取默认提示词的接口
    // 但如果没有，我们可以使用一些默认值作为备用
    if (featureType == AIFeatureType.sceneToSummary) {
      return '请根据以下场景内容，生成一个简洁的摘要，用于帮助读者快速了解场景的核心内容。';
    } else if (featureType == AIFeatureType.summaryToScene) {
      return '请根据以下摘要，生成一个详细的场景描写，包括情节、对话和必要的环境描述。';
    } else {
      return '请生成内容';
    }
  }
} 