import 'package:ainoval/blocs/prompt/prompt_event.dart';
import 'package:ainoval/blocs/prompt/prompt_state.dart';
import 'package:ainoval/blocs/prompt/prompt_template_events.dart';
import 'package:ainoval/models/prompt_models.dart';
import 'package:ainoval/services/api_service/repositories/prompt_repository.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ainoval/config/app_config.dart';

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
    
    // 注册模板事件处理函数
    on<CopyPublicTemplateRequested>(_onCopyPublicTemplateRequested);
    on<ToggleTemplateFavoriteRequested>(_onToggleTemplateFavoriteRequested);
    on<CreatePromptTemplateRequested>(_onCreatePromptTemplateRequested);
    on<UpdatePromptTemplateRequested>(_onUpdatePromptTemplateRequested);
    on<DeleteTemplateRequested>(_onDeleteTemplateRequested);
    on<OptimizePromptStreamRequested>(_onOptimizePromptStreamRequested);
    on<CancelOptimizationRequested>(_onCancelOptimizationRequested);
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
      emit(PromptLoading(
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        promptTemplates: state.promptTemplates,
      ));
      
      // 当前暂无后端API，使用本地模拟数据，后续接入API后移除
      // TODO: 接入后端API获取提示词模板
      await Future.delayed(const Duration(milliseconds: 300)); // 模拟网络延迟
      
      final now = DateTime.now();
      final String systemAuthorId = 'system';
      
      // 模拟数据 - 场景摘要相关公共模板
      final List<PromptTemplate> publicTemplates = [
        PromptTemplate(
          id: 'public_summary_1',
          name: '标准场景摘要模板',
          content: '''请根据以下小说场景内容，生成一段简洁而全面的摘要。
          
场景内容:
{scene_content}

小说上下文:
{novel_context}

注意事项:
1. 捕捉场景的核心事件和关键人物
2. 突出情感变化和重要转折
3. 保持摘要的连贯性和逻辑性
4. 提炼出场景的主题和意义
5. 保留关键细节但省略次要内容''',
          featureType: AIFeatureType.sceneToSummary,
          isPublic: true,
          authorId: systemAuthorId,
          isVerified: true,
          createdAt: now,
          updatedAt: now,
        ),
        PromptTemplate(
          id: 'public_summary_2',
          name: '人物关系分析摘要',
          content: '''请根据以下小说场景，专注于分析和总结角色之间的关系发展与变化。
          
场景内容:
{scene_content}

小说上下文:
{novel_context}

请在摘要中重点关注:
1. 主要角色之间的互动和对话
2. 关系动态的变化和发展
3. 潜在的情感冲突或和解
4. 角色之间的权力结构变化
5. 对未来情节发展的关系铺垫''',
          featureType: AIFeatureType.sceneToSummary,
          isPublic: true,
          authorId: systemAuthorId,
          isVerified: true,
          createdAt: now,
          updatedAt: now,
        ),
        PromptTemplate(
          id: 'public_summary_3',
          name: '情节进展摘要',
          content: '''请根据以下小说场景，提炼出清晰的情节发展摘要，突出故事进展。
          
场景内容:
{scene_content}

小说上下文:
{novel_context}

请特别注意:
1. 标识情节的起承转合
2. 捕捉故事线索的推进方式
3. 突出关键决策点和转折
4. 分析场景如何推动整体故事发展
5. 简洁明了地总结场景的核心价值''',
          featureType: AIFeatureType.sceneToSummary,
          isPublic: true,
          authorId: systemAuthorId,
          isVerified: true,
          createdAt: now,
          updatedAt: now,
        ),
        
        // 场景生成相关公共模板
        PromptTemplate(
          id: 'public_scene_1',
          name: '标准场景生成模板',
          content: '''请根据以下摘要内容，创作一个详细且生动的小说场景。
          
摘要内容:
{summary}

小说上下文:
{novel_context}

请在场景创作中注意:
1. 丰富的环境描写和氛围营造
2. 自然流畅的对话和人物互动
3. 人物的内心活动和情感变化
4. 合理的情节发展和细节呈现
5. 与小说整体风格和上下文的一致性''',
          featureType: AIFeatureType.summaryToScene,
          isPublic: true,
          authorId: systemAuthorId,
          isVerified: true,
          createdAt: now,
          updatedAt: now,
        ),
        PromptTemplate(
          id: 'public_scene_2',
          name: '情感冲突场景',
          content: '''请根据以下摘要，创作一个以情感冲突为核心的小说场景。
          
摘要内容:
{summary}

小说上下文:
{novel_context}

在创作这个场景时，请着重:
1. 人物之间强烈的情感对立与冲突
2. 紧张而富有张力的对话与互动
3. 冲突升级的自然过程和细节
4. 人物面部表情和肢体语言的细致描写
5. 情感爆发点和可能的转机或和解''',
          featureType: AIFeatureType.summaryToScene,
          isPublic: true,
          authorId: systemAuthorId,
          isVerified: true,
          createdAt: now,
          updatedAt: now,
        ),
        PromptTemplate(
          id: 'public_scene_3',
          name: '悬疑氛围场景',
          content: '''请根据以下摘要，创作一个充满悬疑氛围的小说场景。
          
摘要内容:
{summary}

小说上下文:
{novel_context}

请特别关注以下元素:
1. 神秘而令人不安的环境描写
2. 缓慢而精心的悬念构建
3. 暗示性的对话和细节
4. 角色的疑惑、恐惧或不安情绪
5. 留下悬而未决的问题或线索''',
          featureType: AIFeatureType.summaryToScene,
          isPublic: true,
          authorId: systemAuthorId,
          isVerified: true,
          createdAt: now,
          updatedAt: now,
        ),
        PromptTemplate(
          id: 'public_scene_4',
          name: '转折点场景',
          content: '''请根据以下摘要，创作一个包含重要转折点的小说场景。
          
摘要内容:
{summary}

小说上下文:
{novel_context}

创作要点:
1. 铺垫转折前的情境和氛围
2. 自然而不突兀的转折点引入
3. 角色对转折的反应和情感变化
4. 转折对人物和情节的深远影响
5. 为后续发展埋下合理的伏笔''',
          featureType: AIFeatureType.summaryToScene,
          isPublic: true,
          authorId: systemAuthorId,
          isVerified: true,
          createdAt: now,
          updatedAt: now,
        ),
        PromptTemplate(
          id: 'public_scene_5',
          name: '日常互动场景',
          content: '''请根据以下摘要，创作一个自然流畅的日常互动小说场景。
          
摘要内容:
{summary}

小说上下文:
{novel_context}

请注意以下几点:
1. 自然真实的对话和互动
2. 日常生活中的小细节与质感
3. 通过日常互动展现人物性格特点
4. 在平淡中蕴含深意和情感发展
5. 为人物关系的发展提供自然铺垫''',
          featureType: AIFeatureType.summaryToScene,
          isPublic: true,
          authorId: systemAuthorId,
          isVerified: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      
      // 模拟数据 - 提示词类型模板
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
        promptTemplates: publicTemplates,
        isLoading: false,
      ));
      
      AppLogger.i(_tag, '成功加载提示词模板: ${summaryTemplates.length}个摘要模板, ${styleTemplates.length}个风格模板, ${publicTemplates.length}个公共模板');
    } catch (e) {
      AppLogger.e(_tag, '加载提示词模板失败', e);
      // 失败时不修改当前模板，只添加错误信息
      emit(PromptError(
        errorMessage: '加载提示词模板失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        summaryPrompts: state.summaryPrompts,
        stylePrompts: state.stylePrompts,
        promptTemplates: state.promptTemplates,
      ));
    }
  }

  /// 处理选择功能类型事件
  Future<void> _onSelectFeatureRequested(
    SelectFeatureRequested event,
    Emitter<PromptState> emit,
  ) async {
    final featureType = event.featureType;
    if (!state.prompts.containsKey(featureType)) {
      // 如果当前没有这个类型的提示词，尝试获取
      await _loadPromptForFeature(featureType, emit);
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

  /// 处理复制公共模板事件
  Future<void> _onCopyPublicTemplateRequested(
    CopyPublicTemplateRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      AppLogger.i(_tag, '复制公共模板: ${event.templateId}');
      
      // 查找对应的公共模板
      final publicTemplate = state.promptTemplates.firstWhere(
        (template) => template.id == event.templateId && template.isPublic,
        orElse: () => throw Exception('公共模板不存在'),
      );
      
      // 调用存储库复制模板
      final newTemplate = await _promptRepository.copyPublicTemplate(publicTemplate);
      
      // 更新状态
      final updatedTemplates = List<PromptTemplate>.from(state.promptTemplates)..add(newTemplate);
      emit(state.copyWith(promptTemplates: updatedTemplates));
      
      AppLogger.i(_tag, '成功复制公共模板: ${newTemplate.id}');
    } catch (e) {
      AppLogger.e(_tag, '复制公共模板失败', e);
      emit(PromptError(
        errorMessage: '复制公共模板失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        promptTemplates: state.promptTemplates,
      ));
    }
  }
  
  /// 处理切换模板收藏状态事件
  Future<void> _onToggleTemplateFavoriteRequested(
    ToggleTemplateFavoriteRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      AppLogger.i(_tag, '切换模板收藏状态: ${event.templateId}');
      
      // 查找对应的模板
      final templateIndex = state.promptTemplates.indexWhere(
        (template) => template.id == event.templateId,
      );
      
      if (templateIndex < 0) {
        throw Exception('模板不存在');
      }
      
      final template = state.promptTemplates[templateIndex];
      
      // 仅允许切换私有模板的收藏状态
      if (template.isPublic) {
        throw Exception('公共模板不能收藏');
      }
      
      // 切换收藏状态
      final updatedTemplate = await _promptRepository.toggleTemplateFavorite(template);
      
      // 更新状态
      final updatedTemplates = List<PromptTemplate>.from(state.promptTemplates);
      updatedTemplates[templateIndex] = updatedTemplate;
      
      emit(state.copyWith(promptTemplates: updatedTemplates));
      
      AppLogger.i(_tag, '成功切换模板收藏状态: ${updatedTemplate.isFavorite}');
    } catch (e) {
      AppLogger.e(_tag, '切换模板收藏状态失败', e);
      emit(PromptError(
        errorMessage: '切换模板收藏状态失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        promptTemplates: state.promptTemplates,
      ));
    }
  }
  
  /// 处理创建提示词模板事件
  Future<void> _onCreatePromptTemplateRequested(
    CreatePromptTemplateRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      AppLogger.i(_tag, '创建提示词模板: ${event.name}');
      
      // 检查用户ID是否存在
      final String authorId = AppConfig.userId ?? 'anonymous';
      
      // 创建新模板
      final newTemplate = await _promptRepository.createPromptTemplate(
        name: event.name,
        content: event.content,
        featureType: event.featureType,
        authorId: authorId, // 使用非空的用户ID
      );
      
      // 更新状态
      final updatedTemplates = List<PromptTemplate>.from(state.promptTemplates)..add(newTemplate);
      emit(state.copyWith(promptTemplates: updatedTemplates));
      
      AppLogger.i(_tag, '成功创建提示词模板: ${newTemplate.id}');
    } catch (e) {
      AppLogger.e(_tag, '创建提示词模板失败', e);
      emit(PromptError(
        errorMessage: '创建提示词模板失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        promptTemplates: state.promptTemplates,
      ));
    }
  }
  
  /// 处理更新提示词模板事件
  Future<void> _onUpdatePromptTemplateRequested(
    UpdatePromptTemplateRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      AppLogger.i(_tag, '更新提示词模板: ${event.templateId}');
      
      // 查找对应的模板
      final templateIndex = state.promptTemplates.indexWhere(
        (template) => template.id == event.templateId,
      );
      
      if (templateIndex < 0) {
        throw Exception('模板不存在');
      }
      
      final template = state.promptTemplates[templateIndex];
      
      // 仅允许更新私有模板
      if (template.isPublic) {
        throw Exception('公共模板不能更新');
      }
      
      // 更新模板
      final updatedTemplate = await _promptRepository.updatePromptTemplate(
        templateId: event.templateId,
        name: event.name,
        content: event.content,
      );
      
      // 更新状态
      final updatedTemplates = List<PromptTemplate>.from(state.promptTemplates);
      updatedTemplates[templateIndex] = updatedTemplate;
      
      emit(state.copyWith(promptTemplates: updatedTemplates));
      
      AppLogger.i(_tag, '成功更新提示词模板: ${updatedTemplate.id}');
    } catch (e) {
      AppLogger.e(_tag, '更新提示词模板失败', e);
      emit(PromptError(
        errorMessage: '更新提示词模板失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        promptTemplates: state.promptTemplates,
      ));
    }
  }
  
  /// 处理删除模板事件
  Future<void> _onDeleteTemplateRequested(
    DeleteTemplateRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      AppLogger.i(_tag, '删除模板: ${event.templateId}');
      
      // 查找对应的模板
      final templateIndex = state.promptTemplates.indexWhere(
        (template) => template.id == event.templateId,
      );
      
      if (templateIndex < 0) {
        throw Exception('模板不存在');
      }
      
      final template = state.promptTemplates[templateIndex];
      
      // 仅允许删除私有模板
      if (template.isPublic) {
        throw Exception('公共模板不能删除');
      }
      
      // 删除模板
      await _promptRepository.deletePromptTemplate(event.templateId);
      
      // 更新状态
      final updatedTemplates = List<PromptTemplate>.from(state.promptTemplates)..removeAt(templateIndex);
      emit(state.copyWith(promptTemplates: updatedTemplates));
      
      AppLogger.i(_tag, '成功删除模板');
    } catch (e) {
      AppLogger.e(_tag, '删除模板失败', e);
      emit(PromptError(
        errorMessage: '删除模板失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        promptTemplates: state.promptTemplates,
      ));
    }
  }
  
  /// 处理优化提示词事件
  Future<void> _onOptimizePromptStreamRequested(
    OptimizePromptStreamRequested event,
    Emitter<PromptState> emit,
  ) async {
    try {
      AppLogger.i(_tag, '流式优化提示词: ${event.templateId}');
      
      // 检查是否正在优化中
      if (state.isOptimizing) {
        throw Exception('正在优化中');
      }
      
      // 设置为优化中状态
      emit(state.copyWith(isOptimizing: true));
      
      // 进度回调
      final onProgress = (double progress) {
        if (event.onProgress != null) {
          event.onProgress!(progress);
        }
      };
      
      // 结果回调
      final onResult = (OptimizationResult result) {
        if (event.onResult != null) {
          event.onResult!(result);
        }
        
        // 优化完成，更新状态
        emit(state.copyWith(isOptimizing: false));
      };
      
      // 错误回调
      final onError = (String error) {
        if (event.onError != null) {
          event.onError!(error);
        }
        
        // 优化失败，更新状态
        emit(state.copyWith(
          isOptimizing: false,
          errorMessage: '优化提示词失败: $error',
        ));
      };
      
      // 调用存储库执行优化
      _promptRepository.optimizePromptStream(
        event.templateId,
        event.request,
        onProgress: onProgress,
        onResult: onResult,
        onError: onError,
      );
      
    } catch (e) {
      AppLogger.e(_tag, '开始优化提示词失败', e);
      
      if (event.onError != null) {
        event.onError!(e.toString());
      }
      
      emit(PromptError(
        errorMessage: '开始优化提示词失败: ${e.toString()}',
        prompts: state.prompts,
        selectedFeatureType: state.selectedFeatureType,
        promptTemplates: state.promptTemplates,
        isOptimizing: false,
      ));
    }
  }
  
  /// 处理取消优化事件
  void _onCancelOptimizationRequested(
    CancelOptimizationRequested event,
    Emitter<PromptState> emit,
  ) {
    AppLogger.i(_tag, '取消优化提示词');
    
    // 取消优化
    _promptRepository.cancelOptimization();
    
    // 更新状态
    emit(state.copyWith(isOptimizing: false));
  }
}