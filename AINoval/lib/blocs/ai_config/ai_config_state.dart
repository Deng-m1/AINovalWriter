part of 'ai_config_bloc.dart';

enum AiConfigStatus { initial, loading, loaded, error }

enum AiConfigActionStatus { initial, loading, success, error } // 用于跟踪增删改等操作的状态

class AiConfigState extends Equatable {
  // <<< 添加此行: ID of the config currently undergoing an action

  const AiConfigState({
    this.status = AiConfigStatus.initial,
    this.actionStatus = AiConfigActionStatus.initial,
    this.configs = const [],
    this.availableProviders = const [],
    this.modelsForProvider = const [],
    this.selectedProviderForModels,
    this.errorMessage,
    this.actionErrorMessage,
    this.loadingConfigId, // <<< 添加此行
    this.modelGroups = const {},
    this.providerDefaultConfigs = const {},
  });
  final AiConfigStatus status; // 主要加载状态
  final AiConfigActionStatus actionStatus; // 操作状态 (添加/更新/删除/验证/设置默认)
  final List<UserAIModelConfigModel> configs;
  final List<String> availableProviders;
  final List<String> modelsForProvider;
  final String? selectedProviderForModels; // 跟踪当前正在查看哪个提供商的模型
  final String? errorMessage;
  final String? actionErrorMessage; // 操作的特定错误消息
  final String? loadingConfigId;
  final Map<String, AIModelGroup> modelGroups; // 按提供商分组的模型
  final Map<String, UserAIModelConfigModel> providerDefaultConfigs; // 每个提供商的默认配置

  // 获取已验证的配置，用于选择器
  List<UserAIModelConfigModel> get validatedConfigs =>
      configs.where((c) => c.isValidated).toList();

  // 获取默认配置
  UserAIModelConfigModel? get defaultConfig =>
      configs.firstWhereOrNull((c) => c.isDefault);
      
  // 获取特定提供商的默认配置
  UserAIModelConfigModel? getProviderDefaultConfig(String provider) {
    return providerDefaultConfigs[provider];
  }

  AiConfigState copyWith({
    AiConfigStatus? status,
    AiConfigActionStatus? actionStatus,
    List<UserAIModelConfigModel>? configs,
    List<String>? availableProviders,
    List<String>? modelsForProvider,
    String? selectedProviderForModels,
    // 使用 ValueGetter 允许显式设置 null
    ValueGetter<String?>? errorMessage,
    ValueGetter<String?>? actionErrorMessage,
    bool clearModels = false, // 添加标志以清除模型列表
    String? loadingConfigId, // <<< 添加此行
    Map<String, AIModelGroup>? modelGroups,
    Map<String, UserAIModelConfigModel>? providerDefaultConfigs,
  }) {
    return AiConfigState(
      status: status ?? this.status,
      actionStatus: actionStatus ?? this.actionStatus,
      configs: configs ?? this.configs,
      availableProviders: availableProviders ?? this.availableProviders,
      modelsForProvider:
          clearModels ? [] : modelsForProvider ?? this.modelsForProvider,
      selectedProviderForModels: clearModels
          ? null
          : selectedProviderForModels ?? this.selectedProviderForModels,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      actionErrorMessage: actionErrorMessage != null
          ? actionErrorMessage()
          : this.actionErrorMessage,
      loadingConfigId: loadingConfigId ?? this.loadingConfigId, // <<< 添加此行
      modelGroups: modelGroups ?? this.modelGroups,
      providerDefaultConfigs: providerDefaultConfigs ?? this.providerDefaultConfigs,
    );
  }

  @override
  List<Object?> get props => [
        status,
        actionStatus,
        configs,
        availableProviders,
        modelsForProvider,
        selectedProviderForModels,
        errorMessage,
        actionErrorMessage,
        loadingConfigId, // <<< 添加此行
        modelGroups,
        providerDefaultConfigs,
      ];
}
