import '../../../models/user_ai_model_config_model.dart';

/// 用户 AI 模型配置仓库接口定义
abstract interface class UserAIModelConfigRepository {
  /// 获取系统支持的所有AI提供商
  Future<List<String>> listAvailableProviders();

  /// 获取指定提供商支持的模型列表
  Future<List<String>> listModelsForProvider(String provider);

  /// 添加新的用户AI模型配置
  Future<UserAIModelConfigModel> addConfiguration({
    required String userId,
    required String provider,
    required String modelName,
    String? alias,
    required String apiKey,
    String? apiEndpoint,
  });

  /// 列出用户所有的AI模型配置
  /// [validatedOnly] 为 true 时，只返回已验证的配置
  Future<List<UserAIModelConfigModel>> listConfigurations({
    required String userId,
    bool? validatedOnly,
  });

  /// 获取指定ID的用户AI模型配置
  Future<UserAIModelConfigModel> getConfigurationById({
    required String userId,
    required String configId,
  });

  /// 更新指定ID的用户AI模型配置
  /// [alias], [apiKey], [apiEndpoint] 可选，只传递需要更新的字段
  Future<UserAIModelConfigModel> updateConfiguration({
    required String userId,
    required String configId,
    String? alias,
    String? apiKey,
    String? apiEndpoint,
  });

  /// 删除指定ID的用户AI模型配置
  Future<void> deleteConfiguration({
    required String userId,
    required String configId,
  });

  /// 手动触发指定配置的API Key验证
  Future<UserAIModelConfigModel> validateConfiguration({
    required String userId,
    required String configId,
  });

  /// 设置指定配置为用户的默认模型
  Future<UserAIModelConfigModel> setDefaultConfiguration({
    required String userId,
    required String configId,
  });
} 