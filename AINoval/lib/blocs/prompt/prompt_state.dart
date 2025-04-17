import 'package:ainoval/models/prompt_models.dart';
import 'package:equatable/equatable.dart';

/// 提示词管理状态基类
class PromptState extends Equatable {
  const PromptState({
    this.prompts = const {},
    this.selectedFeatureType,
    this.isLoading = false,
    this.errorMessage,
    this.isGenerating = false,
    this.generatedContent = '',
    this.generationError,
    this.summaryPrompts = const [],
    this.stylePrompts = const [],
  });

  final Map<AIFeatureType, PromptData> prompts;
  final AIFeatureType? selectedFeatureType;
  final bool isLoading;
  final String? errorMessage;
  final bool isGenerating;
  final String generatedContent;
  final String? generationError;
  final List<PromptItem> summaryPrompts; // 摘要提示词列表
  final List<PromptItem> stylePrompts;   // 风格提示词列表

  /// 获取当前选中功能类型的提示词，如果未选择则返回null
  PromptData? get selectedPrompt =>
      selectedFeatureType != null ? prompts[selectedFeatureType] : null;

  /// 创建新的实例，复制当前状态并更新指定字段
  PromptState copyWith({
    Map<AIFeatureType, PromptData>? prompts,
    AIFeatureType? selectedFeatureType,
    bool? isLoading,
    String? errorMessage,
    bool? isGenerating,
    String? generatedContent,
    String? generationError,
    List<PromptItem>? summaryPrompts,
    List<PromptItem>? stylePrompts,
  }) {
    return PromptState(
      prompts: prompts ?? this.prompts,
      selectedFeatureType: selectedFeatureType ?? this.selectedFeatureType,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isGenerating: isGenerating ?? this.isGenerating,
      generatedContent: generatedContent ?? this.generatedContent,
      generationError: generationError,
      summaryPrompts: summaryPrompts ?? this.summaryPrompts,
      stylePrompts: stylePrompts ?? this.stylePrompts,
    );
  }

  @override
  List<Object?> get props => [
    prompts, 
    selectedFeatureType, 
    isLoading, 
    errorMessage, 
    isGenerating, 
    generatedContent, 
    generationError,
    summaryPrompts,
    stylePrompts
  ];
}

/// 初始提示词状态
class PromptInitial extends PromptState {
  const PromptInitial() : super(isLoading: false);
}

/// 加载中状态
class PromptLoading extends PromptState {
  const PromptLoading({
    required Map<AIFeatureType, PromptData> prompts,
    AIFeatureType? selectedFeatureType,
    List<PromptItem> summaryPrompts = const [],
    List<PromptItem> stylePrompts = const [],
  }) : super(
          prompts: prompts,
          selectedFeatureType: selectedFeatureType,
          isLoading: true,
          summaryPrompts: summaryPrompts,
          stylePrompts: stylePrompts,
        );
}

/// 加载完成状态
class PromptLoaded extends PromptState {
  const PromptLoaded({
    required Map<AIFeatureType, PromptData> prompts,
    AIFeatureType? selectedFeatureType,
    List<PromptItem> summaryPrompts = const [],
    List<PromptItem> stylePrompts = const [],
  }) : super(
          prompts: prompts,
          selectedFeatureType: selectedFeatureType,
          isLoading: false,
          summaryPrompts: summaryPrompts,
          stylePrompts: stylePrompts,
        );
}

/// 错误状态
class PromptError extends PromptState {
  const PromptError({
    required String errorMessage,
    required Map<AIFeatureType, PromptData> prompts,
    AIFeatureType? selectedFeatureType,
    List<PromptItem> summaryPrompts = const [],
    List<PromptItem> stylePrompts = const [],
  }) : super(
          prompts: prompts,
          selectedFeatureType: selectedFeatureType,
          isLoading: false,
          errorMessage: errorMessage,
          summaryPrompts: summaryPrompts,
          stylePrompts: stylePrompts,
        );
}