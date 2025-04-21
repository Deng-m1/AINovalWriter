import 'dart:async';

import 'package:ainoval/blocs/next_outline/next_outline_event.dart';
import 'package:ainoval/blocs/next_outline/next_outline_state.dart';
import 'package:ainoval/models/editor/chapter.dart';
import 'package:ainoval/models/next_outline/next_outline_dto.dart';
import 'package:ainoval/models/next_outline/outline_generation_chunk.dart';
import 'package:ainoval/models/user_ai_model_config.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/next_outline_repository.dart';
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';
import 'package:ainoval/utils/app_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 剧情推演BLoC
class NextOutlineBloc extends Bloc<NextOutlineEvent, NextOutlineState> {
  final NextOutlineRepository _nextOutlineRepository;
  final EditorRepository _editorRepository;
  final UserAIModelConfigRepository _userAIModelConfigRepository;

  // 存储活跃的流订阅
  final Map<String, StreamSubscription> _activeSubscriptions = {};

  final String _tag = 'NextOutlineBloc';

  NextOutlineBloc({
    required NextOutlineRepository nextOutlineRepository,
    required EditorRepository editorRepository,
    required UserAIModelConfigRepository userAIModelConfigRepository,
  }) : _nextOutlineRepository = nextOutlineRepository,
       _editorRepository = editorRepository,
       _userAIModelConfigRepository = userAIModelConfigRepository,
       super(NextOutlineState.initial(novelId: '')) {
    on<NextOutlineInitialized>(_onInitialized);
    on<LoadChaptersRequested>(_onLoadChaptersRequested);
    on<LoadAIModelConfigsRequested>(_onLoadAIModelConfigsRequested);
    on<UpdateChapterRangeRequested>(_onUpdateChapterRangeRequested);
    on<GenerateNextOutlinesRequested>(_onGenerateNextOutlinesRequested);
    on<RegenerateAllOutlinesRequested>(_onRegenerateAllOutlinesRequested);
    on<RegenerateSingleOutlineRequested>(_onRegenerateSingleOutlineRequested);
    on<OutlineSelected>(_onOutlineSelected);
    on<SaveSelectedOutlineRequested>(_onSaveSelectedOutlineRequested);
    on<OutlineGenerationChunkReceived>(_onOutlineGenerationChunkReceived);
    on<GenerationErrorOccurred>(_onGenerationErrorOccurred);
  }

  /// 初始化
  Future<void> _onInitialized(
    NextOutlineInitialized event,
    Emitter<NextOutlineState> emit,
  ) async {
    emit(NextOutlineState.initial(novelId: event.novelId));

    // 加载章节和AI模型配置
    add(LoadChaptersRequested(novelId: event.novelId));
    add(const LoadAIModelConfigsRequested());
  }

  /// 加载章节列表
  Future<void> _onLoadChaptersRequested(
    LoadChaptersRequested event,
    Emitter<NextOutlineState> emit,
  ) async {
    try {
      emit(state.copyWith(
        generationStatus: GenerationStatus.loadingChapters,
        clearError: true,
      ));

      final chapters = await _editorRepository.getChapters(event.novelId);

      // 默认选择第一章和最后一章
      String? startChapterId;
      String? endChapterId;

      if (chapters.isNotEmpty) {
        startChapterId = chapters.first.id;
        endChapterId = chapters.last.id;
      }

      emit(state.copyWith(
        chapters: chapters,
        startChapterId: startChapterId,
        endChapterId: endChapterId,
        generationStatus: GenerationStatus.idle,
      ));
    } catch (e) {
      AppLogger.e(_tag, '加载章节失败', e);
      emit(state.copyWith(
        generationStatus: GenerationStatus.error,
        errorMessage: '加载章节失败: $e',
      ));
    }
  }

  /// 加载AI模型配置
  Future<void> _onLoadAIModelConfigsRequested(
    LoadAIModelConfigsRequested event,
    Emitter<NextOutlineState> emit,
  ) async {
    try {
      emit(state.copyWith(
        generationStatus: GenerationStatus.loadingModels,
      ));

      final configs = await _userAIModelConfigRepository.getUserAIModelConfigs();

      emit(state.copyWith(
        aiModelConfigs: configs,
        generationStatus: GenerationStatus.idle,
      ));
    } catch (e) {
      AppLogger.e(_tag, '加载AI模型配置失败', e);
      emit(state.copyWith(
        generationStatus: GenerationStatus.error,
        errorMessage: '加载AI模型配置失败: $e',
      ));
    }
  }

  /// 更新上下文章节范围
  void _onUpdateChapterRangeRequested(
    UpdateChapterRangeRequested event,
    Emitter<NextOutlineState> emit,
  ) {
    emit(state.copyWith(
      startChapterId: event.startChapterId,
      endChapterId: event.endChapterId,
      clearError: true,
    ));
  }

  /// 生成剧情大纲
  Future<void> _onGenerateNextOutlinesRequested(
    GenerateNextOutlinesRequested event,
    Emitter<NextOutlineState> emit,
  ) async {
    try {
      // 取消所有活跃的流订阅
      _cancelAllSubscriptions();

      emit(state.copyWith(
        generationStatus: GenerationStatus.generatingInitial,
        outlineOptions: [],
        clearSelectedOption: true,
        clearError: true,
        numOptions: event.request.numOptions,
        authorGuidance: event.request.authorGuidance,
      ));

      // 创建初始选项状态
      final initialOptions = List.generate(
        event.request.numOptions,
        (index) => OutlineOptionState(
          optionId: 'option_${DateTime.now().millisecondsSinceEpoch}_$index',
          isGenerating: true,
        ),
      );

      emit(state.copyWith(outlineOptions: initialOptions));

      // 订阅流式响应
      final stream = _nextOutlineRepository.generateNextOutlinesStream(
        state.novelId,
        event.request,
      );

      final subscription = stream.listen(
        (chunk) {
          // 处理接收到的块
          add(OutlineGenerationChunkReceived(
            optionId: chunk.optionId,
            optionTitle: chunk.optionTitle,
            textChunk: chunk.textChunk,
            isFinalChunk: chunk.isFinalChunk,
          ));
        },
        onError: (error) {
          AppLogger.e(_tag, '生成剧情大纲流错误', error);
          add(GenerationErrorOccurred(error: error.toString()));
        },
        onDone: () {
          AppLogger.i(_tag, '生成剧情大纲流完成');
          // 检查是否所有选项都已完成
          _checkAllOptionsComplete(emit);
        },
      );

      // 存储订阅
      _activeSubscriptions['generate'] = subscription;
    } catch (e) {
      AppLogger.e(_tag, '生成剧情大纲失败', e);
      emit(state.copyWith(
        generationStatus: GenerationStatus.error,
        errorMessage: '生成剧情大纲失败: $e',
      ));
    }
  }

  /// 重新生成全部剧情大纲
  Future<void> _onRegenerateAllOutlinesRequested(
    RegenerateAllOutlinesRequested event,
    Emitter<NextOutlineState> emit,
  ) async {
    try {
      // 构建请求
      final request = GenerateNextOutlinesRequest(
        startChapterId: state.startChapterId,
        endChapterId: state.endChapterId,
        numOptions: state.numOptions,
        authorGuidance: state.authorGuidance,
        regenerateHint: event.regenerateHint,
      );

      // 调用生成事件
      add(GenerateNextOutlinesRequested(request: request));
    } catch (e) {
      AppLogger.e(_tag, '重新生成全部剧情大纲失败', e);
      emit(state.copyWith(
        generationStatus: GenerationStatus.error,
        errorMessage: '重新生成全部剧情大纲失败: $e',
      ));
    }
  }

  /// 重新生成单个剧情大纲
  Future<void> _onRegenerateSingleOutlineRequested(
    RegenerateSingleOutlineRequested event,
    Emitter<NextOutlineState> emit,
  ) async {
    try {
      // 查找选项索引
      final optionIndex = state.outlineOptions.indexWhere(
        (option) => option.optionId == event.request.optionId
      );

      if (optionIndex == -1) {
        throw Exception('找不到选项ID: ${event.request.optionId}');
      }

      // 更新选项状态为生成中
      final updatedOptions = List<OutlineOptionState>.from(state.outlineOptions);
      updatedOptions[optionIndex] = updatedOptions[optionIndex].copyWith(
        isGenerating: true,
        isComplete: false,
        content: '',
      );

      emit(state.copyWith(
        outlineOptions: updatedOptions,
        generationStatus: GenerationStatus.generatingSingle,
        clearError: true,
      ));

      // 取消该选项的现有订阅
      _cancelSubscription(event.request.optionId);

      // 订阅流式响应
      final stream = _nextOutlineRepository.regenerateOutlineOption(
        state.novelId,
        event.request,
      );

      final subscription = stream.listen(
        (chunk) {
          // 处理接收到的块
          add(OutlineGenerationChunkReceived(
            optionId: chunk.optionId,
            optionTitle: chunk.optionTitle,
            textChunk: chunk.textChunk,
            isFinalChunk: chunk.isFinalChunk,
          ));
        },
        onError: (error) {
          AppLogger.e(_tag, '重新生成单个剧情大纲流错误', error);
          add(GenerationErrorOccurred(error: error.toString()));
        },
        onDone: () {
          AppLogger.i(_tag, '重新生成单个剧情大纲流完成');
          // 检查是否所有选项都已完成
          _checkAllOptionsComplete(emit);
        },
      );

      // 存储订阅
      _activeSubscriptions[event.request.optionId] = subscription;
    } catch (e) {
      AppLogger.e(_tag, '重新生成单个剧情大纲失败', e);
      emit(state.copyWith(
        generationStatus: GenerationStatus.error,
        errorMessage: '重新生成单个剧情大纲失败: $e',
      ));
    }
  }

  /// 选择剧情大纲
  void _onOutlineSelected(
    OutlineSelected event,
    Emitter<NextOutlineState> emit,
  ) {
    emit(state.copyWith(
      selectedOptionId: event.optionId,
      clearError: true,
    ));
  }

  /// 保存选中的剧情大纲
  Future<void> _onSaveSelectedOutlineRequested(
    SaveSelectedOutlineRequested event,
    Emitter<NextOutlineState> emit,
  ) async {
    try {
      emit(state.copyWith(
        generationStatus: GenerationStatus.saving,
        clearError: true,
      ));

      final response = await _nextOutlineRepository.saveNextOutline(
        state.novelId,
        event.request,
      );

      if (response.success) {
        AppLogger.i(_tag, '保存剧情大纲成功: ${response.outlineId}');

        // 重新加载章节列表
        add(LoadChaptersRequested(novelId: state.novelId));
      } else {
        throw Exception('保存剧情大纲失败');
      }
    } catch (e) {
      AppLogger.e(_tag, '保存剧情大纲失败', e);
      emit(state.copyWith(
        generationStatus: GenerationStatus.error,
        errorMessage: '保存剧情大纲失败: $e',
      ));
    }
  }

  /// 接收到大纲生成块
  void _onOutlineGenerationChunkReceived(
    OutlineGenerationChunkReceived event,
    Emitter<NextOutlineState> emit,
  ) {
    try {
      // 查找选项索引
      final optionIndex = state.outlineOptions.indexWhere(
        (option) => option.optionId == event.optionId
      );

      if (optionIndex == -1) {
        AppLogger.w(_tag, '找不到选项ID: ${event.optionId}');
        return;
      }

      // 更新选项状态
      final updatedOptions = List<OutlineOptionState>.from(state.outlineOptions);
      final currentOption = updatedOptions[optionIndex];

      updatedOptions[optionIndex] = currentOption.addContent(event.textChunk).copyWith(
        title: event.optionTitle ?? currentOption.title,
        isGenerating: !event.isFinalChunk,
        isComplete: event.isFinalChunk,
      );

      emit(state.copyWith(outlineOptions: updatedOptions));

      // 如果是最终块，检查是否所有选项都已完成
      if (event.isFinalChunk) {
        _checkAllOptionsComplete(emit);
      }
    } catch (e) {
      AppLogger.e(_tag, '处理大纲生成块失败', e);
    }
  }

  /// 生成错误
  void _onGenerationErrorOccurred(
    GenerationErrorOccurred event,
    Emitter<NextOutlineState> emit,
  ) {
    emit(state.copyWith(
      generationStatus: GenerationStatus.error,
      errorMessage: event.error,
    ));
  }

  /// 检查是否所有选项都已完成
  void _checkAllOptionsComplete(Emitter<NextOutlineState> emit) {
    final allComplete = state.outlineOptions.every((option) => option.isComplete);

    if (allComplete) {
      emit(state.copyWith(
        generationStatus: GenerationStatus.idle,
      ));
    }
  }

  /// 取消所有流订阅
  void _cancelAllSubscriptions() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
  }

  /// 取消特定选项的流订阅
  void _cancelSubscription(String optionId) {
    if (_activeSubscriptions.containsKey(optionId)) {
      _activeSubscriptions[optionId]?.cancel();
      _activeSubscriptions.remove(optionId);
    }
  }

  @override
  Future<void> close() {
    _cancelAllSubscriptions();
    return super.close();
  }
}
