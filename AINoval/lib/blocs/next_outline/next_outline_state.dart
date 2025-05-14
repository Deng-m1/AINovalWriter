import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../models/novel_structure.dart';
import '../../models/user_ai_model_config_model.dart';
import '../../models/next_outline/next_outline_dto.dart';

/// 大纲状态枚举
enum NextOutlineStatus {
  initial,
  loading,
  success,
  failure,
}

/// 剧情推演状态
class NextOutlineState extends Equatable {
  /// 小说ID
  final String novelId;
  
  /// 章节列表
  final List<Chapter> chapters;
  
  /// AI模型配置列表
  final List<UserAIModelConfigModel> aiModelConfigs;
  
  /// 当前选中的上下文开始章节ID
  final String? startChapterId;
  
  /// 当前选中的上下文结束章节ID
  final String? endChapterId;
  
  /// 生成状态
  final GenerationStatus generationStatus;
  
  /// 剧情选项列表
  final List<OutlineOptionState> outlineOptions;
  
  /// 当前选中的剧情选项ID
  final String? selectedOptionId;
  
  /// 错误信息
  final String? errorMessage;
  
  /// 生成选项数量
  final int numOptions;
  
  /// 作者引导
  final String? authorGuidance;
  
  /// 大纲状态
  final NextOutlineStatus status;
  
  /// 是否正在保存
  final bool isSaving;
  
  /// 输出的大纲生成结果
  final NextOutlineOutput? outputGeneration;

  const NextOutlineState({
    required this.novelId,
    this.chapters = const [],
    this.aiModelConfigs = const [],
    this.startChapterId,
    this.endChapterId,
    this.generationStatus = GenerationStatus.initial,
    this.outlineOptions = const [],
    this.selectedOptionId,
    this.errorMessage,
    this.numOptions = 3,
    this.authorGuidance,
    this.status = NextOutlineStatus.initial,
    this.isSaving = false,
    this.outputGeneration,
  });

  /// 初始状态
  factory NextOutlineState.initial({required String novelId}) {
    return NextOutlineState(
      novelId: novelId,
    );
  }

  /// 复制并修改状态
  NextOutlineState copyWith({
    String? novelId,
    List<Chapter>? chapters,
    List<UserAIModelConfigModel>? aiModelConfigs,
    String? startChapterId,
    String? endChapterId,
    GenerationStatus? generationStatus,
    List<OutlineOptionState>? outlineOptions,
    String? selectedOptionId,
    String? errorMessage,
    int? numOptions,
    String? authorGuidance,
    NextOutlineStatus? status,
    bool? isSaving,
    NextOutlineOutput? outputGeneration,
    bool clearError = false,
    bool clearSelectedOption = false,
  }) {
    return NextOutlineState(
      novelId: novelId ?? this.novelId,
      chapters: chapters ?? this.chapters,
      aiModelConfigs: aiModelConfigs ?? this.aiModelConfigs,
      startChapterId: startChapterId ?? this.startChapterId,
      endChapterId: endChapterId ?? this.endChapterId,
      generationStatus: generationStatus ?? this.generationStatus,
      outlineOptions: outlineOptions ?? this.outlineOptions,
      selectedOptionId: clearSelectedOption ? null : (selectedOptionId ?? this.selectedOptionId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      numOptions: numOptions ?? this.numOptions,
      authorGuidance: authorGuidance ?? this.authorGuidance,
      status: status ?? this.status,
      isSaving: isSaving ?? this.isSaving,
      outputGeneration: outputGeneration ?? this.outputGeneration,
    );
  }

  @override
  List<Object?> get props => [
    novelId,
    chapters,
    aiModelConfigs,
    startChapterId,
    endChapterId,
    generationStatus,
    outlineOptions,
    selectedOptionId,
    errorMessage,
    numOptions,
    authorGuidance,
    status,
    isSaving,
    outputGeneration,
  ];
}

/// 生成状态枚举
enum GenerationStatus {
  initial,
  loadingChapters,
  loadingModels,
  generatingInitial,
  generatingSingle,
  idle,
  error,
  saving,
}

/// 剧情选项状态
class OutlineOptionState extends Equatable {
  /// 选项ID
  final String optionId;
  
  /// 标题
  final String? title;
  
  /// 内容
  final String content;
  
  /// 是否正在生成
  final bool isGenerating;
  
  /// 是否生成完成
  final bool isComplete;
  
  /// 使用的模型配置ID
  final String? configId;
  
  /// 内容流控制器
  final ValueNotifier<String> contentStreamController;
  
  /// 错误信息
  final String? errorMessage;

  OutlineOptionState({
    required this.optionId,
    this.title = '',
    this.content = '',
    this.isGenerating = false,
    this.isComplete = false,
    this.configId,
    this.errorMessage,
  }) : contentStreamController = ValueNotifier<String>(content);

  /// 复制并修改状态
  OutlineOptionState copyWith({
    String? optionId,
    String? title,
    String? content,
    bool? isGenerating,
    bool? isComplete,
    String? configId,
    String? errorMessage,
  }) {
    final newContent = content ?? this.content;
    final result = OutlineOptionState(
      optionId: optionId ?? this.optionId,
      title: title ?? this.title,
      content: newContent,
      isGenerating: isGenerating ?? this.isGenerating,
      isComplete: isComplete ?? this.isComplete,
      configId: configId ?? this.configId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
    
    // 更新内容流
    if (content != null) {
      result.contentStreamController.value = newContent;
    }
    
    return result;
  }

  /// 添加内容
  OutlineOptionState addContent(String newContent) {
    final updatedContent = content + newContent;
    final result = copyWith(
      content: updatedContent,
    );
    
    // 更新内容流
    result.contentStreamController.value = updatedContent;
    
    return result;
  }

  @override
  List<Object?> get props => [
    optionId,
    title,
    content,
    isGenerating,
    isComplete,
    configId,
    errorMessage,
  ];
}
