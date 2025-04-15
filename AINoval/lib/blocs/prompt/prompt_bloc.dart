import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 提示词管理Bloc
class PromptBloc extends Bloc<PromptEvent, PromptState> {
  PromptBloc({required PromptRepository promptRepository})
      : _promptRepository = promptRepository,
        super(const PromptInitial()) {
    on<LoadAllPromptsRequested>(_onLoadAllPromptsRequested);
    on<LoadPromptTemplatesRequested>(_onLoadPromptTemplatesRequested);
    on<SelectFeatureRequested>(_onSelectFeatureRequested);
    on<SavePromptRequested>(_onSavePromptRequested);
    on<ResetPromptRequested>(_onResetPromptRequested);
    on<GenerateSceneSummary>(_onGenerateSceneSummary);
    on<GenerateSceneFromSummary>(_onGenerateSceneFromSummary);
    on<AddPromptTemplateRequested>(_onAddPromptTemplateRequested);
    on<DeletePromptTemplateRequested>(_onDeletePromptTemplateRequested);
  }

  final PromptRepository _promptRepository;
  static const String _tag = 'PromptBloc';

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

  /// 处理加载提示词模板事件
  Future<void> _onLoadPromptTemplatesRequested(
    LoadPromptTemplatesRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      // 当前暂无后端API，使用本地模拟数据，后续接入API后移除
      // TODO: 接入后端API获取提示词模板
      await Future.delayed(const Duration(milliseconds: 300)); // 模拟网络延迟
      
      // 模拟数据
      final List<PromptItem> summaryTemplates = [
        PromptItem(
          id: 'summary_1',
          title: '详细场景',
          content: '详细描述一个[场景类型]场景，包括环境描述、人物互动和情感变化。',
          type: PromptType.summary,
        ),
        PromptItem(
          id: 'summary_2',
          title: '转折点',
          content: '描述故事中的一个重要转折点，主角面临抉择，情节发生重要变化。',
          type: PromptType.summary,
        ),
        PromptItem(
          id: 'summary_3',
          title: '角色冲突',
          content: '描述两个主要角色之间的冲突场景，包括对话、内心活动和行动。',
          type: PromptType.summary,
        ),
      ];
      
      final List<PromptItem> styleTemplates = [
        PromptItem(
          id: 'style_1',
          title: '紧张悬疑',
          content: '紧张悬疑的风格，节奏紧凑，多用短句，留下悬念',
          type: PromptType.style,
        ),
        PromptItem(
          id: 'style_2',
          title: '细腻文艺',
          content: '细腻文艺的风格，多用优美词藻，着重心理描写',
          type: PromptType.style,
        ),
        PromptItem(
          id: 'style_3',
          title: '对话主导',
          content: '以对话为主，减少描写，突出人物个性',
          type: PromptType.style,
        ),
      ];
      
      // 发出新状态
      emit(state.copyWith(
        summaryPrompts: summaryTemplates,
        stylePrompts: styleTemplates,
      ));
      
      AppLogger.i(_tag, '成功加载提示词模板: ${summaryTemplates.length}个摘要模板, ${styleTemplates.length}个风格模板');
    } catch (e) {
      AppLogger.e(_tag, '加载提示词模板失败', e);
      // 失败时不修改当前模板，只添加错误信息
      emit(PromptError(
        errorMessage: '加载提示词模板失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        summaryPrompts: state.summaryPrompts,
        stylePrompts: state.stylePrompts,
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

  /// 处理生成场景摘要事件
  Future<void> _onGenerateSceneSummary(
    GenerateSceneSummary event,
    Emitter<PromptState> emit,
  ) async {
    try {
      // 开始生成，设置生成中状态
      emit(state.copyWith(
        isGenerating: true,
        generationError: null,
      ));

      // 调用仓库生成摘要
      final summary = await _promptRepository.generateSceneSummary(
        novelId: event.novelId,
        sceneId: event.sceneId,
      );

      // 生成成功，更新状态
      emit(state.copyWith(
        isGenerating: false,
        generatedContent: summary,
      ));

      AppLogger.i(_tag, '成功生成场景摘要');
    } catch (e) {
      AppLogger.e(_tag, '生成场景摘要失败', e);

      // 生成失败，更新状态，保留原有生成内容
      emit(state.copyWith(
        isGenerating: false,
        generationError: '生成摘要失败: ${e.toString()}',
      ));
    }
  }

  /// 处理摘要生成场景事件
  Future<void> _onGenerateSceneFromSummary(
    GenerateSceneFromSummary event,
    Emitter<PromptState> emit,
  ) async {
    try {
      // 开始生成，设置生成中状态
      emit(state.copyWith(
        isGenerating: true,
        generationError: null,
      ));

      // 调用仓库生成场景
      final sceneContent = await _promptRepository.generateSceneFromSummary(
        novelId: event.novelId,
        summary: event.summary,
      );

      // 生成成功，更新状态
      emit(state.copyWith(
        isGenerating: false,
        generatedContent: sceneContent,
      ));

      AppLogger.i(_tag, '成功生成场景内容');
    } catch (e) {
      AppLogger.e(_tag, '生成场景内容失败', e);

      // 生成失败，更新状态，保留原有生成内容
      emit(state.copyWith(
        isGenerating: false,
        generationError: '生成场景失败: ${e.toString()}',
      ));
    }
  }

  /// 处理添加提示词模板事件
  Future<void> _onAddPromptTemplateRequested(
    AddPromptTemplateRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      // 生成唯一ID
      final String id = '${event.type.toString().split('.').last}_${DateTime.now().millisecondsSinceEpoch}';
      
      // 创建新的提示词项
      final newTemplate = PromptItem(
        id: id,
        title: event.title,
        content: event.content,
        type: event.type,
      );
      
      // 根据类型更新对应的提示词列表
      if (event.type == PromptType.summary) {
        final updatedSummaryPrompts = List<PromptItem>.from(state.summaryPrompts)..add(newTemplate);
        emit(state.copyWith(summaryPrompts: updatedSummaryPrompts));
      } else {
        final updatedStylePrompts = List<PromptItem>.from(state.stylePrompts)..add(newTemplate);
        emit(state.copyWith(stylePrompts: updatedStylePrompts));
      }
      
      AppLogger.i(_tag, '成功添加${event.type == PromptType.summary ? "摘要" : "风格"}提示词模板: ${event.title}');
    } catch (e) {
      AppLogger.e(_tag, '添加提示词模板失败', e);
      emit(PromptError(
        errorMessage: '添加提示词模板失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        summaryPrompts: state.summaryPrompts,
        stylePrompts: state.stylePrompts,
      ));
    }
  }
  
  /// 处理删除提示词模板事件
  Future<void> _onDeletePromptTemplateRequested(
    DeletePromptTemplateRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      // 确定提示词类型并删除
      final String promptId = event.promptId;
      bool isSummary = false;
      
      // 检查是否存在于摘要提示词列表
      final summaryIndex = state.summaryPrompts.indexWhere((item) => item.id == promptId);
      if (summaryIndex >= 0) {
        isSummary = true;
        final updatedSummaryPrompts = List<PromptItem>.from(state.summaryPrompts)..removeAt(summaryIndex);
        emit(state.copyWith(summaryPrompts: updatedSummaryPrompts));
      } else {
        // 检查是否存在于风格提示词列表
        final styleIndex = state.stylePrompts.indexWhere((item) => item.id == promptId);
        if (styleIndex >= 0) {
          final updatedStylePrompts = List<PromptItem>.from(state.stylePrompts)..removeAt(styleIndex);
          emit(state.copyWith(stylePrompts: updatedStylePrompts));
        }
      }
      
      AppLogger.i(_tag, '成功删除${isSummary ? "摘要" : "风格"}提示词模板: $promptId');
    } catch (e) {
      AppLogger.e(_tag, '删除提示词模板失败', e);
      emit(PromptError(
        errorMessage: '删除提示词模板失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        summaryPrompts: state.summaryPrompts,
        stylePrompts: state.stylePrompts,
      ));
    }
  }
}