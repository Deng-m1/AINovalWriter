import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/models/ai_model_group.dart';
import 'package:ainoval/models/model_info.dart'; // Import ModelInfo
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // For ValueGetter

part 'ai_config_event.dart';
part 'ai_config_state.dart';

class AiConfigBloc extends Bloc<AiConfigEvent, AiConfigState> {
  AiConfigBloc({required UserAIModelConfigRepository repository})
      : _repository = repository,
        super(const AiConfigState()) {
    on<LoadAiConfigs>(_onLoadAiConfigs);
    on<LoadAvailableProviders>(_onLoadAvailableProviders);
    on<LoadModelsForProvider>(_onLoadModelsForProvider);
    on<AddAiConfig>(_onAddAiConfig);
    on<UpdateAiConfig>(_onUpdateAiConfig);
    on<DeleteAiConfig>(_onDeleteAiConfig);
    on<ValidateAiConfig>(_onValidateAiConfig);
    on<SetDefaultAiConfig>(_onSetDefaultAiConfig);
    on<ClearProviderModels>(_onClearProviderModels);
    on<GetProviderDefaultConfig>(_onGetProviderDefaultConfig);
    on<LoadApiKeyForConfig>(_onLoadApiKeyForConfig);
    on<LoadProviderCapability>(_onLoadProviderCapability);
    on<TestApiKey>(_onTestApiKey);
    on<ClearApiKeyTestError>(_onClearApiKeyTestError);
  }
  final UserAIModelConfigRepository _repository;

  Future<void> _onLoadAiConfigs(
      LoadAiConfigs event, Emitter<AiConfigState> emit) async {
    emit(state.copyWith(status: AiConfigStatus.loading));
    try {
      final configs =
          await _repository.listConfigurations(userId: event.userId);
      
      // 按提供商分组用户配置
      final Map<String, UserAIModelConfigModel> providerDefaultConfigs = {};
      
      // 按提供商分组
      final configsByProvider = <String, List<UserAIModelConfigModel>>{};
      for (final config in configs) {
        if (!configsByProvider.containsKey(config.provider)) {
          configsByProvider[config.provider] = [];
        }
        configsByProvider[config.provider]!.add(config);
      }
      
      // 为每个提供商选择一个默认配置
      configsByProvider.forEach((provider, providerConfigs) {
        // 优先选择默认配置，其次是已验证的配置，最后选择第一个配置
        final defaultConfig = providerConfigs.firstWhere(
          (c) => c.isDefault, 
          orElse: () => providerConfigs.firstWhere(
            (c) => c.isValidated,
            orElse: () => providerConfigs.first,
          ),
        );
        
        providerDefaultConfigs[provider] = defaultConfig;
      });
      
      emit(state.copyWith(
        status: AiConfigStatus.loaded,
        configs: configs,
        providerDefaultConfigs: providerDefaultConfigs,
        errorMessage: () => null, // Clear previous error
      ));
    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '加载配置失败', e, stackTrace);
      emit(state.copyWith(
          status: AiConfigStatus.error, errorMessage: () => e.toString()));
    }
  }

  Future<void> _onLoadAvailableProviders(
      LoadAvailableProviders event, Emitter<AiConfigState> emit) async {
    // 不需要将主状态设为 loading，这通常在对话框中进行
    // emit(state.copyWith(status: AiConfigStatus.loading)); // Maybe not needed
    try {
      final providers = await _repository.listAvailableProviders();
      emit(state.copyWith(
        availableProviders: providers,
        errorMessage: () => null,
      ));
    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '加载提供商失败', e, stackTrace);
      // 可以考虑添加一个 providerSpecificError 状态字段
      emit(state.copyWith(errorMessage: () => '加载提供商列表失败: ${e.toString()}'));
    }
  }

  Future<void> _onLoadModelsForProvider(
      LoadModelsForProvider event, Emitter<AiConfigState> emit) async {
    emit(state.copyWith(
        modelsForProviderInfo: [], 
        selectedProviderForModels: event.provider,
        apiKeyTestSuccessProviderClearable: () => null,
        apiKeyTestErrorClearable: () => null,
      ));
    try {
      final models = await _repository.listModelsForProvider(event.provider);
      AppLogger.i('AiConfigBloc', '成功获取模型列表，provider=${event.provider}，模型数量=${models.length}');

      // Use the new factory for ModelInfo list
      final modelGroup = AIModelGroup.fromModelInfoList(event.provider, models); 
      final updatedModelGroups = Map<String, AIModelGroup>.from(state.modelGroups);
      updatedModelGroups[event.provider] = modelGroup;

      emit(state.copyWith(
        modelsForProviderInfo: models, 
        modelGroups: updatedModelGroups, // Update model groups
        errorMessage: () => null
      ));
      
      AppLogger.i('AiConfigBloc', '模型加载完成，触发GetProviderDefaultConfig，provider=${event.provider}');
      add(GetProviderDefaultConfig(provider: event.provider));
    } catch (e, stackTrace) {
      AppLogger.e(
          'AiConfigBloc', '加载模型失败 for ${event.provider}', e, stackTrace);
      AppLogger.w('AiConfigBloc', '加载模型失败，provider=${event.provider}，错误：$e');
      emit(state.copyWith(
          modelsForProviderInfo: [], 
          errorMessage: () => '加载模型列表失败: ${e.toString()}'));
    }
  }

  Future<void> _onAddAiConfig(
      AddAiConfig event, Emitter<AiConfigState> emit) async {
    emit(state.copyWith(
        actionStatus: AiConfigActionStatus.loading,
        actionErrorMessage: () => null));
    try {
      final newConfig = await _repository.addConfiguration(
        userId: event.userId,
        provider: event.provider,
        modelName: event.modelName,
        alias: event.alias,
        apiKey: event.apiKey,
        apiEndpoint: event.apiEndpoint,
      );
      // 添加新配置后重新加载列表或直接添加到现有列表
      // 重新加载更简单，保证数据一致性
      emit(state.copyWith(actionStatus: AiConfigActionStatus.success));
      add(LoadAiConfigs(userId: event.userId)); // Trigger reload
    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '添加配置失败', e, stackTrace);
      emit(state.copyWith(
          actionStatus: AiConfigActionStatus.error,
          actionErrorMessage: () => '添加失败: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateAiConfig(
      UpdateAiConfig event, Emitter<AiConfigState> emit) async {
    emit(state.copyWith(
        actionStatus: AiConfigActionStatus.loading,
        actionErrorMessage: () => null));
    try {
      final updatedConfig = await _repository.updateConfiguration(
        userId: event.userId,
        configId: event.configId,
        alias: event.alias,
        apiKey: event.apiKey,
        apiEndpoint: event.apiEndpoint,
      );
      // 更新列表中的特定项
      final currentConfigs = List<UserAIModelConfigModel>.from(state.configs);
      final index = currentConfigs.indexWhere((c) => c.id == updatedConfig.id);
      if (index != -1) {
        currentConfigs[index] = updatedConfig;
        emit(state.copyWith(
            actionStatus: AiConfigActionStatus.success,
            configs: currentConfigs));
      } else {
        // 如果找不到，最好还是重新加载
        emit(state.copyWith(actionStatus: AiConfigActionStatus.success));
        add(LoadAiConfigs(userId: event.userId));
      }
    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '更新配置失败', e, stackTrace);
      emit(state.copyWith(
          actionStatus: AiConfigActionStatus.error,
          actionErrorMessage: () => '更新失败: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteAiConfig(
      DeleteAiConfig event, Emitter<AiConfigState> emit) async {
    emit(state.copyWith(
        actionStatus: AiConfigActionStatus.loading,
        actionErrorMessage: () => null));
    try {
      await _repository.deleteConfiguration(
          userId: event.userId, configId: event.configId);
      // 从列表中移除
      final currentConfigs = List<UserAIModelConfigModel>.from(state.configs);
      currentConfigs.removeWhere((c) => c.id == event.configId);
      emit(state.copyWith(
          actionStatus: AiConfigActionStatus.success, configs: currentConfigs));
      // 如果删除的是默认配置，可能需要清除默认状态或重新加载以确认新的默认（如果后端自动处理）
      // 这里暂时只移除
    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '删除配置失败', e, stackTrace);
      emit(state.copyWith(
          actionStatus: AiConfigActionStatus.error,
          actionErrorMessage: () => '删除失败: ${e.toString()}'));
    }
  }

  Future<void> _onValidateAiConfig(
      ValidateAiConfig event, Emitter<AiConfigState> emit) async {
    try {
      emit(state.copyWith(
          actionStatus: AiConfigActionStatus.loading,
          actionErrorMessage: null,
          loadingConfigId: event.configId));

      final validatedConfig = await _repository.validateConfiguration(
          userId: event.userId, configId: event.configId);
      // 更新列表中的特定项
      final currentConfigs = List<UserAIModelConfigModel>.from(state.configs);
      final index =
          currentConfigs.indexWhere((c) => c.id == validatedConfig.id);
      if (index != -1) {
        currentConfigs[index] = validatedConfig;
        emit(state.copyWith(
            actionStatus: AiConfigActionStatus.success,
            configs: currentConfigs,
            loadingConfigId: null));
      } else {
        emit(state.copyWith(
            actionStatus: AiConfigActionStatus.success,
            loadingConfigId: null)); // Mark success but maybe reload
        add(LoadAiConfigs(userId: event.userId));
      }
    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '验证配置失败', e, stackTrace);
      // 即使验证失败，API可能也会返回更新后的带有错误信息的Config，所以尝试更新UI
      final currentConfigs = List<UserAIModelConfigModel>.from(state.configs);
      final index = currentConfigs.indexWhere((c) => c.id == event.configId);
      if (index != -1) {
        // 尝试从错误中获取更新后的状态，或者至少标记为未验证
        // 这里简化处理：如果验证调用失败，我们不改变列表状态，只显示错误
        emit(state.copyWith(
            actionStatus: AiConfigActionStatus.error,
            actionErrorMessage: () => '验证请求失败: ${e.toString()}',
            loadingConfigId: null));
      } else {
        emit(state.copyWith(
            actionStatus: AiConfigActionStatus.error,
            actionErrorMessage: () => '验证失败且找不到配置: ${e.toString()}',
            loadingConfigId: null));
      }
    }
  }

  Future<void> _onSetDefaultAiConfig(
      SetDefaultAiConfig event, Emitter<AiConfigState> emit) async {
    emit(state.copyWith(
        actionStatus: AiConfigActionStatus.loading,
        actionErrorMessage: () => null));
    try {
      final newDefaultConfig = await _repository.setDefaultConfiguration(
          userId: event.userId, configId: event.configId);
      // 重新加载整个列表以确保旧的默认值被取消
      emit(state.copyWith(actionStatus: AiConfigActionStatus.success));
      add(LoadAiConfigs(userId: event.userId));
    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '设置默认配置失败', e, stackTrace);
      emit(state.copyWith(
          actionStatus: AiConfigActionStatus.error,
          actionErrorMessage: () => '设置默认失败: ${e.toString()}'));
    }
  }

  void _onClearProviderModels(
      ClearProviderModels event, Emitter<AiConfigState> emit) {
    // 清除模型列表和当前选中的提供商
    emit(state.copyWith(
      clearModels: true,
      // 保留模型分组信息，因为它可能在其他地方被使用
      // 如果需要清除特定提供商的模型分组，可以在这里处理
    ));
  }

  // 根据provider查找第一个可用的配置，用于显示该提供商的API密钥和URL
  Future<void> _onGetProviderDefaultConfig(
      GetProviderDefaultConfig event, Emitter<AiConfigState> emit) async {
    final provider = event.provider;
    print('⚠️ 开始处理GetProviderDefaultConfig事件，provider=$provider');
    
    // 获取当前状态的providerDefaultConfigs副本
    final providerDefaultConfigs = Map<String, UserAIModelConfigModel>.from(state.providerDefaultConfigs);
    
    // 从已加载的配置中查找
    final providerConfigs = state.configs.where((c) => c.provider == provider).toList();
    print('⚠️ 查找provider=$provider的配置，找到${providerConfigs.length}个配置');
    
    if (providerConfigs.isEmpty) {
      print('⚠️ 没有找到provider=$provider的配置');
      // 没有找到该提供商的配置，从Map中移除这个提供商的配置（如果有）
      if (providerDefaultConfigs.containsKey(provider)) {
        providerDefaultConfigs.remove(provider);
        emit(state.copyWith(
          providerDefaultConfigs: providerDefaultConfigs,
        ));
        print('⚠️ 已从providerDefaultConfigs中移除provider=$provider的配置');
      }
      return;
    }
    
    // 首先寻找默认的
    final defaultConfig = providerConfigs.firstWhere(
      (c) => c.isDefault, 
      orElse: () => providerConfigs.firstWhere(
        (c) => c.isValidated,
        orElse: () => providerConfigs.first,
      ),
    );
    
    print('⚠️ 找到provider=$provider的默认配置，id=${defaultConfig.id}，apiEndpoint=${defaultConfig.apiEndpoint}，hasApiKey=${defaultConfig.apiKey != null}');
    
    // 更新或添加该提供商的默认配置
    providerDefaultConfigs[provider] = defaultConfig;
    
    // 更新状态
    emit(state.copyWith(
      providerDefaultConfigs: providerDefaultConfigs,
    ));
    
    print('⚠️ 已更新状态中的providerDefaultConfigs，当前包含的提供商：${providerDefaultConfigs.keys.join(", ")}');
  }

  // 处理加载API密钥的事件
  Future<void> _onLoadApiKeyForConfig(
      LoadApiKeyForConfig event, Emitter<AiConfigState> emit) async {
    try {
      // 从已加载的配置中查找
      final config = state.configs.firstWhereOrNull(
        (config) => config.id == event.configId
      );
      
      if (config != null && config.apiKey != null) {
        // 如果已加载的配置中有API密钥，直接使用
        // event.onApiKeyLoaded(config.apiKey!); // Commenting out: ValueGetter<void> takes no arguments
        print("API Key found in state for ${event.configId}");
        // TODO: Decide how to actually return/use this key - maybe emit a state?
        return;
      }
      
      // 如果没有找到配置或者没有API密钥，提示用户手动输入
      // event.onApiKeyLoaded("请手动输入API密钥"); // Commenting out: ValueGetter<void> takes no arguments
      print("API Key NOT found in state for ${event.configId}");
       // TODO: Decide how to handle missing key - maybe emit an error state?
    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '获取API密钥失败', e, stackTrace);
      // 如果失败，返回一个错误提示
      // event.onApiKeyLoaded("获取失败，请手动输入"); // Commenting out: ValueGetter<void> takes no arguments
      print("Error loading API Key for ${event.configId}: $e");
       // TODO: Decide how to handle error - maybe emit an error state?
    }
  }

  // --- Handlers for New Events ---

  Future<void> _onLoadProviderCapability(
      LoadProviderCapability event, Emitter<AiConfigState> emit) async {
    // Reset previous capability and test status for the new provider
    emit(state.copyWith(
      providerCapabilityClearable: () => null,
      isTestingApiKey: false,
      apiKeyTestSuccessProviderClearable: () => null,
      apiKeyTestErrorClearable: () => null,
    ));
    try {
      // 调用repository方法获取提供商能力
      final capability = await _repository.getProviderCapability(event.providerName);
      
      AppLogger.i('AiConfigBloc', '加载提供商 ${event.providerName} 能力成功: $capability');
      emit(state.copyWith(providerCapability: capability));

      // --- 修改开始 ---
      bool shouldLoadWithKey = false;
      UserAIModelConfigModel? defaultConfig;

      // 优先从 providerDefaultConfigs 获取，因为它是为这个场景设计的
      defaultConfig = state.providerDefaultConfigs[event.providerName];
      
      // 如果默认配置里没key，再尝试从完整列表里捞一个有效的 (可能不是最优选择，但作为后备)
      // if (defaultConfig == null || defaultConfig.apiKey == null || defaultConfig.apiKey!.isEmpty) {
      //    final providerConfigs = state.configs.where((c) => c.provider == event.providerName).toList();
      //    if (providerConfigs.isNotEmpty) {
      //      defaultConfig = providerConfigs.firstWhere(
      //        (c) => c.isDefault && c.apiKey != null && c.apiKey!.isNotEmpty,
      //        orElse: () => providerConfigs.firstWhere(
      //          (c) => c.isValidated && c.apiKey != null && c.apiKey!.isNotEmpty,
      //          orElse: () => providerConfigs.firstWhere(
      //             (c) => c.apiKey != null && c.apiKey!.isNotEmpty,
      //             orElse: () => providerConfigs.first // Last resort: first config even without key
      //           )
      //        )
      //      );
      //    }
      // }


      if (capability == ModelListingCapability.listingWithKey) {
        // 检查找到的配置（优先是 providerDefaultConfigs 里的）是否有有效的 API Key
        if (defaultConfig != null && defaultConfig.apiKey != null && defaultConfig.apiKey!.isNotEmpty) {
           shouldLoadWithKey = true;
           AppLogger.i('AiConfigBloc', 'Provider ${event.providerName} 需要 Key，且找到已配置的 Key (来自 providerDefaultConfigs 或查找)，将尝试使用 Key 加载模型');
        } else {
           AppLogger.i('AiConfigBloc', 'Provider ${event.providerName} 需要 Key，但未找到带 Key 的默认/有效配置，将加载默认模型');
        }
      } else {
         AppLogger.i('AiConfigBloc', 'Provider ${event.providerName} 不需要 Key 或不支持列表，将加载默认模型');
      }

      // 清除之前的测试状态和错误信息，避免残留
      emit(state.copyWith(
          apiKeyTestSuccessProviderClearable: () => null,
          apiKeyTestErrorClearable: () => null,
          isTestingApiKey: shouldLoadWithKey // 如果用key加载，状态设为testing
      ));


      if (shouldLoadWithKey && defaultConfig != null) {
         // 使用 TestApiKey 事件来加载模型列表
         // 注意：确保 _onTestApiKey 处理器能正确更新模型列表状态
         AppLogger.i('AiConfigBloc', '触发 TestApiKey (用作加载模型) for ${event.providerName}');
         add(TestApiKey(
           providerName: event.providerName,
           apiKey: defaultConfig.apiKey!,
           apiEndpoint: defaultConfig.apiEndpoint,
         ));
      } else {
        // 不需要 Key 或没有找到 Key，加载默认模型
        AppLogger.i('AiConfigBloc', '触发加载 ${event.providerName} 的默认模型列表 (LoadModelsForProvider)');
        add(LoadModelsForProvider(provider: event.providerName));
      }
      // --- 修改结束 ---

    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '加载提供商 ${event.providerName} 能力失败', e, stackTrace);
      emit(state.copyWith(errorMessage: () => '加载提供商能力失败: ${e.toString()}'));
      // 即使能力加载失败，也尝试加载默认模型列表，避免界面空白
      AppLogger.w('AiConfigBloc', '能力加载失败，仍尝试加载 ${event.providerName} 的默认模型列表');
      add(LoadModelsForProvider(provider: event.providerName));
    }
  }

  Future<void> _onTestApiKey(
      TestApiKey event, Emitter<AiConfigState> emit) async {
    emit(state.copyWith(
      isTestingApiKey: true,
      apiKeyTestSuccessProviderClearable: () => null, 
      apiKeyTestErrorClearable: () => null, 
    ));
    try {
      final models = await _repository.listModelsWithApiKey(
        provider: event.providerName,
        apiKey: event.apiKey,
        apiEndpoint: event.apiEndpoint,
      );

      AppLogger.i('AiConfigBloc', '测试 API Key 成功 for ${event.providerName}, 获取到 ${models.length} 个模型');
      
      // Use the new factory for ModelInfo list
      final modelGroup = AIModelGroup.fromModelInfoList(event.providerName, models);
      final updatedModelGroups = Map<String, AIModelGroup>.from(state.modelGroups);
      updatedModelGroups[event.providerName] = modelGroup;

      emit(state.copyWith(
        isTestingApiKey: false,
        apiKeyTestSuccessProvider: event.providerName, 
        modelsForProviderInfo: models, 
        modelGroups: updatedModelGroups, // Update model groups
        selectedProviderForModels: event.providerName, 
      ));
    } catch (e, stackTrace) {
      AppLogger.e('AiConfigBloc', '测试 API Key 异常 for ${event.providerName}', e, stackTrace);
      emit(state.copyWith(
        isTestingApiKey: false,
        apiKeyTestError: 'API Key 测试失败: ${e.toString()}',
        modelsForProviderInfo: [], 
      ));
    }
  }

  // Handler to clear the API key test error
  void _onClearApiKeyTestError(
      ClearApiKeyTestError event, Emitter<AiConfigState> emit) {
    // Use ValueGetter to explicitly set the error to null
    emit(state.copyWith(apiKeyTestErrorClearable: () => null));
  }

  // Optional: Modify _onLoadModelsForProvider if needed
  // Example: Reset API key test status when models are loaded without a key test
  // Future<void> _onLoadModelsForProvider(
  //     LoadModelsForProvider event, Emitter<AiConfigState> emit) async {
  //   emit(state.copyWith(
  //       modelsForProvider: [],
  //       selectedProviderForModels: event.provider,
  //       // Reset test status if loading models without key
  //       apiKeyTestSuccessProviderClearable: () => null,
  //       apiKeyTestErrorClearable: () => null
  //     ));
  //    // ... rest of the existing logic ...
  // }
}
