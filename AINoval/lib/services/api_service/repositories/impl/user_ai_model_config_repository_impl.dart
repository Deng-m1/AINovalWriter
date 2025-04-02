import 'dart:async';

import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/services/api_service/base/api_client.dart';
// Api Exception 可能仍然需要，用于类型检查或如果 repository 层需要抛出特定类型的异常
// 但 ApiExceptionHelper 不需要了
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';
import 'package:ainoval/utils/logger.dart';

/// 用户 AI 模型配置仓库实现
class UserAIModelConfigRepositoryImpl implements UserAIModelConfigRepository {
  UserAIModelConfigRepositoryImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<String>> listAvailableProviders() async {
    AppLogger.i('UserAIModelConfigRepoImpl', '获取可用提供商');
    try {
      final providers = await apiClient.listAIProviders();
      AppLogger.i(
          'UserAIModelConfigRepoImpl', '获取可用提供商成功: count=${providers.length}');
      return providers;
    } catch (e, stackTrace) {
      AppLogger.e(
          'UserAIModelConfigRepoImpl', '获取可用提供商失败', e, stackTrace);
      // 直接重新抛出，ApiClient 会处理 DioException 转换
      rethrow;
    }
  }

  @override
  Future<List<String>> listModelsForProvider(String provider) async {
    AppLogger.i('UserAIModelConfigRepoImpl', '获取提供商 $provider 模型');
    try {
      final models = await apiClient.listAIModelsForProvider(provider: provider);
      AppLogger.i('UserAIModelConfigRepoImpl',
          '获取提供商 $provider 模型成功: count=${models.length}');
      return models;
    } catch (e, stackTrace) {
      AppLogger.e('UserAIModelConfigRepoImpl',
          '获取提供商 $provider 模型失败', e, stackTrace);
      // 直接重新抛出
      rethrow;
    }
  }

  @override
  Future<UserAIModelConfigModel> addConfiguration({
    required String userId,
    required String provider,
    required String modelName,
    String? alias,
    required String apiKey,
    String? apiEndpoint,
  }) async {
    AppLogger.i('UserAIModelConfigRepoImpl', '添加配置: userId=$userId'); // Mask apiKey in logs
    try {
      final config = await apiClient.addAIConfiguration(
        userId: userId,
        provider: provider,
        modelName: modelName,
        alias: alias,
        apiKey: apiKey,
        apiEndpoint: apiEndpoint,
      );
      AppLogger.i('UserAIModelConfigRepoImpl',
          '添加配置成功: userId=$userId, configId=${config.id}');
      return config;
    } catch (e, stackTrace) {
      AppLogger.e('UserAIModelConfigRepoImpl',
          '添加配置失败: userId=$userId', e, stackTrace);
      // 直接重新抛出
      rethrow;
    }
  }

  @override
  Future<List<UserAIModelConfigModel>> listConfigurations({
    required String userId,
    bool? validatedOnly,
  }) async {
    AppLogger.i('UserAIModelConfigRepoImpl',
        '列出配置: userId=$userId, validatedOnly=$validatedOnly');
    try {
      final configs = await apiClient.listAIConfigurations(
        userId: userId,
        validatedOnly: validatedOnly,
      );
      AppLogger.i('UserAIModelConfigRepoImpl',
          '列出配置成功: userId=$userId, count=${configs.length}');
      return configs;
    } catch (e, stackTrace) {
      AppLogger.e('UserAIModelConfigRepoImpl',
          '列出配置失败: userId=$userId', e, stackTrace);
      // 直接重新抛出
      rethrow;
    }
  }

  @override
  Future<UserAIModelConfigModel> getConfigurationById({
    required String userId,
    required String configId,
  }) async {
    AppLogger.i('UserAIModelConfigRepoImpl',
        '获取配置: userId=$userId, configId=$configId');
    try {
      final config = await apiClient.getAIConfigurationById(
        userId: userId,
        configId: configId,
      );
      AppLogger.i('UserAIModelConfigRepoImpl',
          '获取配置成功: userId=$userId, configId=${config.id}');
      return config;
    } catch (e, stackTrace) {
      AppLogger.e('UserAIModelConfigRepoImpl',
          '获取配置失败: userId=$userId, configId=$configId', e, stackTrace);
       // 直接重新抛出
       rethrow;
    }
  }

  @override
  Future<UserAIModelConfigModel> updateConfiguration({
    required String userId,
    required String configId,
    String? alias,
    String? apiKey,
    String? apiEndpoint,
  }) async {
     if (alias == null && apiKey == null && apiEndpoint == null) {
        AppLogger.w('UserAIModelConfigRepoImpl', '更新配置调用，但没有提供要更新的字段: userId=$userId, configId=$configId');
        AppLogger.i('UserAIModelConfigRepoImpl', '无有效更新字段，尝试获取当前配置');
        // 注意：这里的 getConfigurationById 本身也可能抛出异常
        return getConfigurationById(userId: userId, configId: configId);
     }

    AppLogger.i('UserAIModelConfigRepoImpl',
        '更新配置: userId=$userId, configId=$configId'); // Mask apiKey
    try {
      final config = await apiClient.updateAIConfiguration(
        userId: userId,
        configId: configId,
        alias: alias,
        apiKey: apiKey,
        apiEndpoint: apiEndpoint,
      );
      AppLogger.i('UserAIModelConfigRepoImpl',
          '更新配置成功: userId=$userId, configId=${config.id}');
      return config;
    } catch (e, stackTrace) {
      AppLogger.e('UserAIModelConfigRepoImpl',
          '更新配置失败: userId=$userId, configId=$configId', e, stackTrace);
      // 直接重新抛出
      rethrow;
    }
  }

  @override
  Future<void> deleteConfiguration({
    required String userId,
    required String configId,
  }) async {
    AppLogger.i('UserAIModelConfigRepoImpl',
        '删除配置: userId=$userId, configId=$configId');
    try {
      await apiClient.deleteAIConfiguration(userId: userId, configId: configId);
      AppLogger.i('UserAIModelConfigRepoImpl',
          '删除配置成功: userId=$userId, configId=$configId');
    } catch (e, stackTrace) {
      AppLogger.e('UserAIModelConfigRepoImpl',
          '删除配置失败: userId=$userId, configId=$configId', e, stackTrace);
      // 直接重新抛出
      rethrow;
    }
  }

  @override
  Future<UserAIModelConfigModel> validateConfiguration({
    required String userId,
    required String configId,
  }) async {
    AppLogger.i('UserAIModelConfigRepoImpl',
        '验证配置: userId=$userId, configId=$configId');
    try {
      final config = await apiClient.validateAIConfiguration(
        userId: userId,
        configId: configId,
      );
      AppLogger.i('UserAIModelConfigRepoImpl',
          '验证配置成功: userId=$userId, configId=${config.id}, isValidated=${config.isValidated}');
      return config;
    } catch (e, stackTrace) {
      AppLogger.e('UserAIModelConfigRepoImpl',
          '验证配置失败: userId=$userId, configId=$configId', e, stackTrace);
      // 直接重新抛出
      rethrow;
    }
  }

  @override
  Future<UserAIModelConfigModel> setDefaultConfiguration({
    required String userId,
    required String configId,
  }) async {
    AppLogger.i('UserAIModelConfigRepoImpl',
        '设置默认配置: userId=$userId, configId=$configId');
    try {
      final config = await apiClient.setDefaultAIConfiguration(
        userId: userId,
        configId: configId,
      );
      AppLogger.i('UserAIModelConfigRepoImpl',
          '设置默认配置成功: userId=$userId, configId=${config.id}, isDefault=${config.isDefault}');
      return config;
    } catch (e, stackTrace) {
      AppLogger.e('UserAIModelConfigRepoImpl',
          '设置默认配置失败: userId=$userId, configId=$configId', e, stackTrace);
      // 直接重新抛出
      rethrow;
    }
  }
}

