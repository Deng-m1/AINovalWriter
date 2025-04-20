import 'package:ainoval/models/user_ai_model_config_model.dart';
import 'package:ainoval/models/ai_model_group.dart';
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
  }
  final UserAIModelConfigRepository _repository;

  Future<void> _onLoadAiConfigs(
      LoadAiConfigs event, Emitter<AiConfigState> emit) async {
    emit(state.copyWith(status: AiConfigStatus.loading));
    try {
      final configs =
          await _repository.listConfigurations(userId: event.userId);
      emit(state.copyWith(
        status: AiConfigStatus.loaded,
        configs: configs,
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
    // Emit state clearing old models and setting the selected provider
    emit(state.copyWith(
        modelsForProvider: [], selectedProviderForModels: event.provider));
    try {
      final models = await _repository.listModelsForProvider(event.provider);

      // 创建模型分组
      final modelGroup = AIModelGroup.fromModelList(event.provider, models);

      // 更新状态中的模型分组
      final updatedModelGroups = Map<String, AIModelGroup>.from(state.modelGroups);
      updatedModelGroups[event.provider] = modelGroup;

      // Emit state with new models and model groups, clearing any previous error message
      emit(state.copyWith(
        modelsForProvider: models,
        modelGroups: updatedModelGroups,
        errorMessage: () => null
      ));
    } catch (e, stackTrace) {
      AppLogger.e(
          'AiConfigBloc', '加载模型失败 for ${event.provider}', e, stackTrace);
      // Emit state clearing models and setting an error message
      emit(state.copyWith(
          modelsForProvider: [],
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
}
