import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/utils/logger.dart';

/// 提示词管理Bloc
class PromptBloc extends Bloc<PromptEvent, PromptState> {
  final PromptRepository _promptRepository;
  static const String _tag = 'PromptBloc';

  PromptBloc({required PromptRepository promptRepository}) 
      : _promptRepository = promptRepository,
        super(const PromptInitial()) {
    on<LoadAllPromptsRequested>(_onLoadAllPromptsRequested);
    on<SelectFeatureRequested>(_onSelectFeatureRequested);
    on<SavePromptRequested>(_onSavePromptRequested);
    on<ResetPromptRequested>(_onResetPromptRequested);
  }

  /// 处理加载所有提示词事件
  Future<void> _onLoadAllPromptsRequested(
    LoadAllPromptsRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      emit(PromptLoading(
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
      ));

      final prompts = await _promptRepository.getAllPrompts();
      
      emit(PromptLoaded(
        prompts: prompts,
        selectedFeatureType: state.selectedFeatureType,
      ));
      
      AppLogger.i(_tag, '成功加载所有提示词: ${prompts.length}个');
    } catch (e) {
      AppLogger.e(_tag, '加载所有提示词失败', e);
      emit(PromptError(
        errorMessage: '加载提示词失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
      ));
    }
  }

  /// 处理选择功能类型事件
  void _onSelectFeatureRequested(
    SelectFeatureRequested event,
    Emitter<PromptState> emit,
  ) {
    final featureType = event.featureType;
    if (!state.prompts.containsKey(featureType)) {
      // 如果当前没有这个类型的提示词，尝试获取
      _loadPromptForFeature(featureType, emit);
    } else {
      // 否则直接更新选中的功能类型
      emit(state.copyWith(selectedFeatureType: featureType));
      AppLogger.i(_tag, '选择功能类型: $featureType');
    }
  }

  /// 加载指定功能类型的提示词
  Future<void> _loadPromptForFeature(
    AIFeatureType featureType,
    Emitter<PromptState> emit,
  ) async {
    try {
      emit(PromptLoading(
        prompts: state.prompts,
        selectedFeatureType: featureType,
      ));

      final promptData = await _promptRepository.getPrompt(featureType);
      
      final updatedPrompts = Map<AIFeatureType, PromptData>.from(state.prompts);
      updatedPrompts[featureType] = promptData;
      
      emit(PromptLoaded(
        prompts: updatedPrompts,
        selectedFeatureType: featureType,
      ));
      
      AppLogger.i(_tag, '成功加载功能类型提示词: $featureType');
    } catch (e) {
      AppLogger.e(_tag, '加载功能类型提示词失败: $featureType', e);
      emit(PromptError(
        errorMessage: '加载提示词失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: featureType,
      ));
    }
  }

  /// 处理保存提示词事件
  Future<void> _onSavePromptRequested(
    SavePromptRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      emit(PromptLoading(
        prompts: state.prompts,
        selectedFeatureType: event.featureType,
      ));

      final promptData = await _promptRepository.savePrompt(
        event.featureType,
        event.promptText,
      );
      
      final updatedPrompts = Map<AIFeatureType, PromptData>.from(state.prompts);
      updatedPrompts[event.featureType] = promptData;
      
      emit(PromptLoaded(
        prompts: updatedPrompts,
        selectedFeatureType: event.featureType,
      ));
      
      AppLogger.i(_tag, '成功保存提示词: ${event.featureType}');
    } catch (e) {
      AppLogger.e(_tag, '保存提示词失败: ${event.featureType}', e);
      emit(PromptError(
        errorMessage: '保存提示词失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: event.featureType,
      ));
    }
  }

  /// 处理重置提示词事件
  Future<void> _onResetPromptRequested(
    ResetPromptRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      emit(PromptLoading(
        prompts: state.prompts,
        selectedFeatureType: event.featureType,
      ));

      await _promptRepository.deletePrompt(event.featureType);
      
      // 重新获取提示词（应该返回默认提示词）
      final promptData = await _promptRepository.getPrompt(event.featureType);
      
      final updatedPrompts = Map<AIFeatureType, PromptData>.from(state.prompts);
      updatedPrompts[event.featureType] = promptData;
      
      emit(PromptLoaded(
        prompts: updatedPrompts,
        selectedFeatureType: event.featureType,
      ));
      
      AppLogger.i(_tag, '成功重置提示词: ${event.featureType}');
    } catch (e) {
      AppLogger.e(_tag, '重置提示词失败: ${event.featureType}', e);
      emit(PromptError(
        errorMessage: '重置提示词失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: event.featureType,
      ));
    }
  }
} 