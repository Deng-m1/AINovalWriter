part of 'ai_config_bloc.dart';

// 枚举来定义 Provider 获取模型列表的能力
enum ModelListingCapability {
  noListing, // 不支持 API 获取
  listingWithoutKey, // 无需 Key 获取
  listingWithKey, // 需要 Key 获取
}

enum AiConfigStatus {
  initial,
  loading,
  loaded,
  error,
}

enum AiConfigActionStatus {
  idle, // 初始状态
  loading, // 操作进行中（例如保存、删除、验证）
  success, // 操作成功
  error // 操作失败
}

class AiConfigState extends Equatable {
  const AiConfigState({
    this.status = AiConfigStatus.initial,
    this.configs = const [],
    this.availableProviders = const [],
    this.modelsForProvider = const [],
    this.modelsForProviderInfo = const [],
    this.modelGroups = const {},
    this.selectedProviderForModels,
    this.providerDefaultConfigs = const {},
    this.loadingConfigId,
    this.actionStatus = AiConfigActionStatus.idle,
    this.errorMessage,
    this.actionErrorMessage,
    // New state fields
    this.providerCapability,
    this.isTestingApiKey = false,
    this.apiKeyTestSuccessProvider,
    this.apiKeyTestError,
  });

  final AiConfigStatus status;
  final List<UserAIModelConfigModel> configs;
  final List<String> availableProviders;
  final List<String> modelsForProvider; // For the currently selected provider
  final List<ModelInfo> modelsForProviderInfo; // New field for ModelInfo
  final Map<String, AIModelGroup> modelGroups; // Models grouped by provider
  final String? selectedProviderForModels; // Tracks which provider `modelsForProvider` belongs to
  final Map<String, UserAIModelConfigModel> providerDefaultConfigs; // Provider name -> one representative config
  final String? loadingConfigId; // ID of the config being validated
  final AiConfigActionStatus actionStatus; // Status for CRUD/Action operations
  final String? errorMessage; // General error message for loading etc.
  final String? actionErrorMessage; // Specific error for the last action

  // New state fields for dynamic loading and validation
  final ModelListingCapability? providerCapability; // Capability of the selected provider
  final bool isTestingApiKey; // Is an API key currently being tested?
  final String? apiKeyTestSuccessProvider; // Which provider's key was successfully tested?
  final String? apiKeyTestError; // Error message from the last API key test

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
    List<UserAIModelConfigModel>? configs,
    List<String>? availableProviders,
    List<String>? modelsForProvider,
    List<ModelInfo>? modelsForProviderInfo,
    Map<String, AIModelGroup>? modelGroups,
    String? selectedProviderForModels,
    // Use ValueGetter to allow clearing the value by passing () => null
    ValueGetter<String?>? selectedProviderForModelsClearable,
    Map<String, UserAIModelConfigModel>? providerDefaultConfigs,
    String? loadingConfigId,
    // Use ValueGetter for nullable loadingConfigId
    ValueGetter<String?>? loadingConfigIdClearable,
    AiConfigActionStatus? actionStatus,
    ValueGetter<String?>? errorMessage, // Use ValueGetter for nullable fields
    ValueGetter<String?>? actionErrorMessage,
    // New fields
    ModelListingCapability? providerCapability,
    ValueGetter<ModelListingCapability?>? providerCapabilityClearable,
    bool? isTestingApiKey,
    String? apiKeyTestSuccessProvider,
    ValueGetter<String?>? apiKeyTestSuccessProviderClearable,
    String? apiKeyTestError,
    ValueGetter<String?>? apiKeyTestErrorClearable,
    // Helper for clearing models - not a direct state field
    bool clearModels = false,
  }) {
    return AiConfigState(
      status: status ?? this.status,
      configs: configs ?? this.configs,
      availableProviders: availableProviders ?? this.availableProviders,
      modelsForProvider:
          clearModels ? [] : (modelsForProvider ?? this.modelsForProvider),
      modelsForProviderInfo:
          clearModels ? [] : (modelsForProviderInfo ?? this.modelsForProviderInfo),
      modelGroups: modelGroups ?? this.modelGroups,
      selectedProviderForModels:
          selectedProviderForModelsClearable != null
              ? selectedProviderForModelsClearable()
              : selectedProviderForModels ?? this.selectedProviderForModels,
      providerDefaultConfigs:
          providerDefaultConfigs ?? this.providerDefaultConfigs,
      loadingConfigId: loadingConfigIdClearable != null
          ? loadingConfigIdClearable()
          : loadingConfigId ?? this.loadingConfigId,
      actionStatus: actionStatus ?? this.actionStatus,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      actionErrorMessage:
          actionErrorMessage != null ? actionErrorMessage() : this.actionErrorMessage,
      // New fields
      providerCapability: providerCapabilityClearable != null
          ? providerCapabilityClearable()
          : providerCapability ?? this.providerCapability,
      isTestingApiKey: isTestingApiKey ?? this.isTestingApiKey,
      apiKeyTestSuccessProvider: apiKeyTestSuccessProviderClearable != null
          ? apiKeyTestSuccessProviderClearable()
          : apiKeyTestSuccessProvider ?? this.apiKeyTestSuccessProvider,
      apiKeyTestError: apiKeyTestErrorClearable != null
          ? apiKeyTestErrorClearable()
          : apiKeyTestError ?? this.apiKeyTestError,
    );
  }

  @override
  List<Object?> get props => [
        status,
        configs,
        availableProviders,
        modelsForProvider,
        modelsForProviderInfo,
        modelGroups,
        selectedProviderForModels,
        providerDefaultConfigs,
        loadingConfigId,
        actionStatus,
        errorMessage,
        actionErrorMessage,
        // New state fields
        providerCapability,
        isTestingApiKey,
        apiKeyTestSuccessProvider,
        apiKeyTestError,
      ];
}
