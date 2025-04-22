part of 'ai_config_bloc.dart';

abstract class AiConfigEvent extends Equatable {
  const AiConfigEvent();

  @override
  List<Object?> get props => [];
}

/// 加载所有配置
class LoadAiConfigs extends AiConfigEvent {
  // 实际应用中应从认证状态获取
  const LoadAiConfigs({required this.userId});
  final String userId;
  @override
  List<Object?> get props => [userId];
}

/// 加载可用提供商
class LoadAvailableProviders extends AiConfigEvent {}

/// 加载指定提供商的模型
class LoadModelsForProvider extends AiConfigEvent {
  const LoadModelsForProvider({required this.provider});
  final String provider;
  @override
  List<Object?> get props => [provider];
}

/// 添加配置
class AddAiConfig extends AiConfigEvent {
  const AddAiConfig({
    required this.userId,
    required this.provider,
    required this.modelName,
    required this.apiKey,
    this.alias,
    this.apiEndpoint,
  });
  final String userId;
  final String provider;
  final String modelName;
  final String apiKey;
  final String? alias;
  final String? apiEndpoint;
  @override
  List<Object?> get props =>
      [userId, provider, modelName, apiKey, alias, apiEndpoint];
}

/// 更新配置
class UpdateAiConfig extends AiConfigEvent {
  const UpdateAiConfig({
    required this.userId,
    required this.configId,
    this.alias,
    this.apiKey,
    this.apiEndpoint,
  });
  final String userId;
  final String configId;
  final String? alias;
  final String? apiKey;
  final String? apiEndpoint;
  @override
  List<Object?> get props => [userId, configId, alias, apiKey, apiEndpoint];
}

/// 删除配置
class DeleteAiConfig extends AiConfigEvent {
  const DeleteAiConfig({required this.userId, required this.configId});
  final String userId;
  final String configId;
  @override
  List<Object?> get props => [userId, configId];
}

/// 验证配置
class ValidateAiConfig extends AiConfigEvent {
  const ValidateAiConfig({required this.userId, required this.configId});
  final String userId;
  final String configId;
  @override
  List<Object?> get props => [userId, configId];
}

/// 设置默认配置
class SetDefaultAiConfig extends AiConfigEvent {
  const SetDefaultAiConfig({required this.userId, required this.configId});
  final String userId;
  final String configId;
  @override
  List<Object?> get props => [userId, configId];
}

/// 清除提供商/模型列表(例如，关闭对话框时)
class ClearProviderModels extends AiConfigEvent {}

/// 获取提供商默认配置
class GetProviderDefaultConfig extends AiConfigEvent {
  const GetProviderDefaultConfig({
    required this.provider,
  });
  final String provider;

  @override
  List<Object?> get props => [provider];
}

/// 加载指定配置的API密钥
class LoadApiKeyForConfig extends AiConfigEvent {
  const LoadApiKeyForConfig({
    required this.userId,
    required this.configId,
    required this.onApiKeyLoaded,
  });
  final String userId;
  final String configId;
  final void Function(String apiKey) onApiKeyLoaded;

  @override
  List<Object?> get props => [userId, configId];
}
