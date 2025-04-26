import 'dart:async';

import 'package:ainoval/blocs/next_outline/next_outline_event.dart';
import 'package:ainoval/blocs/next_outline/next_outline_state.dart';

import 'package:ainoval/models/next_outline/next_outline_dto.dart';
import 'package:ainoval/models/next_outline/outline_generation_chunk.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/services/api_service/base/api_exception.dart';
import 'package:ainoval/services/api_service/repositories/editor_repository.dart';
import 'package:ainoval/services/api_service/repositories/next_outline_repository.dart';
import 'package:ainoval/services/api_service/repositories/user_ai_model_config_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/config/app_config.dart';

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

      // 获取小说数据，从中提取章节列表
      final novel = await _editorRepository.getNovel(event.novelId);
      List<novel_models.Chapter> chapters = [];
      String? startChapterId;
      String? endChapterId;

      if (novel != null) {
        // 提取所有章节
        for (final act in novel.acts) {
          chapters.addAll(act.chapters);
        }
      }

      // 默认选择第一章和最后一章
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

      // 从AppConfig获取当前用户ID，而不是使用硬编码的"current"
      final String userId = AppConfig.userId ?? '';
      final configs = await _userAIModelConfigRepository.listConfigurations(userId: userId);

      emit(state.copyWith(
        aiModelConfigs: configs,
        generationStatus: GenerationStatus.idle,
        clearError: true,
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
    // 验证章节顺序
    String? errorMessage;
    
    if (event.startChapterId != null && event.endChapterId != null && state.chapters.isNotEmpty) {
      // 查找章节索引
      int? startIndex;
      int? endIndex;
      
      for (int i = 0; i < state.chapters.length; i++) {
        if (state.chapters[i].id == event.startChapterId) {
          startIndex = i;
        }
        if (state.chapters[i].id == event.endChapterId) {
          endIndex = i;
        }
        
        // 如果两个索引都找到了，可以提前结束循环
        if (startIndex != null && endIndex != null) {
          break;
        }
      }
      
      // 检查有效性
      if (startIndex != null && endIndex != null && startIndex > endIndex) {
        errorMessage = '起始章节不能晚于结束章节';
        AppLogger.w(_tag, errorMessage);
      }
    }

    emit(state.copyWith(
      startChapterId: event.startChapterId,
      endChapterId: event.endChapterId,
      errorMessage: errorMessage,
      clearError: errorMessage == null,
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
            error: chunk.error,
          ));
        },
        onError: (error) {
          AppLogger.e(_tag, '生成剧情大纲流错误', error);
          String errorMessage = error.toString();
          if (error is ApiException) {
             errorMessage = error.message;
          }
          // 不再尝试关联特定选项，直接触发全局错误处理
          add(GenerationErrorOccurred(error: errorMessage));
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
      // 构建重新生成请求
      final request = GenerateNextOutlinesRequest(
        startChapterId: state.startChapterId,
        endChapterId: state.endChapterId,
        numOptions: state.numOptions,
        authorGuidance: state.authorGuidance,
        regenerateHint: event.regenerateHint,
        selectedConfigIds: state.aiModelConfigs
            .take(state.numOptions)
            .map((config) => config.id)
            .toList(),
      );

      // 调用生成事件
      add(GenerateNextOutlinesRequested(request: request));
    } catch (e) {
      AppLogger.e(_tag, '重新生成所有剧情大纲失败', e);
      emit(state.copyWith(
        generationStatus: GenerationStatus.error,
        errorMessage: '重新生成所有剧情大纲失败: $e',
      ));
    }
  }

  /// 重新生成单个剧情大纲
  Future<void> _onRegenerateSingleOutlineRequested(
    RegenerateSingleOutlineRequested event,
    Emitter<NextOutlineState> emit,
  ) async {
    try {
      // 找到要重新生成的选项
      final optionIndex = state.outlineOptions
          .indexWhere((option) => option.optionId == event.request.optionId);

      if (optionIndex == -1) {
        throw Exception('未找到指定的剧情选项');
      }

      // 取消该选项的现有订阅
      final subKey = 'regenerate_${event.request.optionId}';
      if (_activeSubscriptions.containsKey(subKey)) {
        _activeSubscriptions[subKey]?.cancel();
        _activeSubscriptions.remove(subKey);
      }

      // 更新选项状态为生成中
      final updatedOptions = List<OutlineOptionState>.from(state.outlineOptions);
      updatedOptions[optionIndex] = updatedOptions[optionIndex].copyWith(
        isGenerating: true,
        isComplete: false,
      );

      emit(state.copyWith(
        outlineOptions: updatedOptions,
        generationStatus: GenerationStatus.generatingSingle,
        clearError: true,
      ));

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
            error: chunk.error,
          ));
        },
        onError: (error) {
          AppLogger.e(_tag, '重新生成单个剧情大纲流错误', error);
          String errorMessage = error.toString();
          if (error is ApiException) {
              errorMessage = error.message;
          }

          // 更新对应选项的错误状态，而不是全局错误
          final errorOptionIndex = state.outlineOptions
              .indexWhere((option) => option.optionId == event.request.optionId);

          if (errorOptionIndex != -1) {
            final updatedErrorOptions = List<OutlineOptionState>.from(state.outlineOptions);
            updatedErrorOptions[errorOptionIndex] = updatedErrorOptions[errorOptionIndex].copyWith(
              isGenerating: false,
              isComplete: true,
              errorMessage: errorMessage,
            );

            emit(state.copyWith(
              outlineOptions: updatedErrorOptions,
            ));
             _checkAllOptionsComplete(emit);
          } else {
            // 如果找不到选项，回退到全局错误
            add(GenerationErrorOccurred(error: errorMessage));
          }
        },
        onDone: () {
          AppLogger.i(_tag, '重新生成单个剧情大纲流完成');
          // 检查是否所有选项都已完成
          _checkAllOptionsComplete(emit);
        },
      );

      // 存储订阅
      _activeSubscriptions[subKey] = subscription;
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

      // 调用保存API
      final response = await _nextOutlineRepository.saveNextOutline(
        state.novelId,
        event.request,
      );

      // 保存成功
      AppLogger.i(_tag, '剧情大纲保存成功');
      emit(state.copyWith(
        generationStatus: GenerationStatus.idle,
      ));
    } catch (e) {
      AppLogger.e(_tag, '保存剧情大纲失败', e);
      emit(state.copyWith(
        generationStatus: GenerationStatus.error,
        errorMessage: '保存剧情大纲失败: $e',
      ));
    }
  }

  /// 处理生成块接收事件
  void _onOutlineGenerationChunkReceived(
    OutlineGenerationChunkReceived event,
    Emitter<NextOutlineState> emit,
  ) {
    try {
      final List<OutlineOptionState> currentOptions = List.from(state.outlineOptions);
      int optionIndex = currentOptions.indexWhere((option) => option.optionId == event.optionId);

      OutlineOptionState updatedOption;

      if (optionIndex == -1) {
        // ---- 新增：动态创建新的选项状态 ---- 
        AppLogger.i(_tag, '首次接收到选项 ${event.optionId} 的数据块，创建新的状态');
        updatedOption = OutlineOptionState(
          optionId: event.optionId,
          title: event.optionTitle,
          content: event.textChunk,
          isGenerating: !event.isFinalChunk,
          isComplete: event.isFinalChunk,
          errorMessage: event.error, // 处理可能直接在chunk中传来的错误
        );
        currentOptions.add(updatedOption);
        // -------------------------------
      } else {
        // ---- 更新现有选项状态 ----
        final existingOption = currentOptions[optionIndex];
        updatedOption = existingOption.copyWith(
          // 追加内容
          content: existingOption.content + event.textChunk,
          // 更新标题（如果新的标题非空且不同）
          title: (event.optionTitle != null && event.optionTitle!.isNotEmpty && event.optionTitle != existingOption.title) 
                 ? event.optionTitle 
                 : existingOption.title,
          // 更新状态
          isGenerating: !event.isFinalChunk,
          isComplete: event.isFinalChunk,
          // 更新错误信息（如果新的错误信息非空）
          errorMessage: event.error ?? existingOption.errorMessage,
        );
        currentOptions[optionIndex] = updatedOption;
        // ------------------------
      }

      emit(state.copyWith(outlineOptions: currentOptions));

      // 检查是否所有选项都已完成 (可以在这里检查，或者依赖 onDone)
      if (currentOptions.every((o) => o.isComplete)) {
         _checkAllOptionsComplete(emit);
      }

    } catch (e, stackTrace) {
      AppLogger.e(_tag, '处理生成块失败 for ${event.optionId}', e, stackTrace);
      // 考虑是否要将此错误设置到对应的option上或触发全局错误
      // 为了避免影响其他流，暂时只记录日志
    }
  }

  /// 处理生成错误事件
  void _onGenerationErrorOccurred(
    GenerationErrorOccurred event,
    Emitter<NextOutlineState> emit,
  ) {
    AppLogger.e(_tag, '全局生成错误: ${event.error}');

    // 停止所有仍在进行的生成，并标记错误
    final updatedOptions = state.outlineOptions.map((option) {
      if (option.isGenerating) { // 只处理还在生成中的选项
        return option.copyWith(
          isGenerating: false,
          isComplete: true, // 标记为完成（即使是失败）
          errorMessage: event.error,
        );
      }
      return option; // 其他选项保持不变
    }).toList();

    emit(state.copyWith(
      generationStatus: GenerationStatus.error, // 设置全局状态为错误
      errorMessage: event.error,
      outlineOptions: updatedOptions, // 更新选项列表
    ));
  }

  /// 检查所有选项是否已完成生成
  void _checkAllOptionsComplete(Emitter<NextOutlineState> emit) {
    if (state.outlineOptions.every((option) => option.isComplete)) {
      // 所有选项都已完成生成
      emit(state.copyWith(
        generationStatus: GenerationStatus.idle,
      ));
    }
  }

  /// 取消所有活跃的流订阅
  void _cancelAllSubscriptions() {
    _activeSubscriptions.forEach((key, subscription) {
      subscription.cancel();
    });
    _activeSubscriptions.clear();
  }

  @override
  Future<void> close() {
    _cancelAllSubscriptions();
    return super.close();
  }
}
