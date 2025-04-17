import 'package:equatable/equatable.dart';
import 'package:ainoval/models/prompt_models.dart';

/// 提示词管理状态基类
abstract class PromptState extends Equatable {
  /// 提示词数据映射
  final Map<AIFeatureType, PromptData> prompts;
  
  /// 当前选中的功能类型
  final AIFeatureType? selectedFeatureType;
  
  /// 摘要类型提示词列表
  final List<PromptItem> summaryPrompts;
  
  /// 风格类型提示词列表
  final List<PromptItem> stylePrompts;
  
  /// 提示词模板列表
  final List<PromptTemplate> promptTemplates;
  
  /// 是否正在加载
  final bool isLoading;
  
  /// 是否正在优化
  final bool isOptimizing;
  
  /// 是否正在生成内容
  final bool isGenerating;
  
  /// 生成的内容
  final String generatedContent;
  
  /// 生成错误信息
  final String? generationError;
  
  /// 错误信息
  final String? errorMessage;

  const PromptState({
    this.prompts = const {},
    this.selectedFeatureType,
    this.summaryPrompts = const [],
    this.stylePrompts = const [],
    this.promptTemplates = const [],
    this.isLoading = false,
    this.isOptimizing = false,
    this.isGenerating = false,
    this.generatedContent = '',
    this.generationError,
    this.errorMessage,
  });

  /// 获取当前选择的提示词
  PromptData? get selectedPrompt {
    if (selectedFeatureType == null) return null;
    return prompts[selectedFeatureType];
  }

  @override
  List<Object?> get props => [
    prompts, 
    selectedFeatureType, 
    summaryPrompts, 
    stylePrompts, 
    promptTemplates,
    isLoading,
    isOptimizing,
    isGenerating,
    generatedContent,
    generationError,
    errorMessage,
  ];
  
  /// 创建新状态
  PromptState copyWith({
    Map<AIFeatureType, PromptData>? prompts,
    AIFeatureType? selectedFeatureType,
    List<PromptItem>? summaryPrompts,
    List<PromptItem>? stylePrompts,
    List<PromptTemplate>? promptTemplates,
    bool? isLoading,
    bool? isOptimizing,
    bool? isGenerating,
    String? generatedContent,
    String? generationError,
    String? errorMessage,
  });
}

/// 初始状态
class PromptInitial extends PromptState {
  const PromptInitial() : super(isLoading: false);
  
  @override
  PromptState copyWith({
    Map<AIFeatureType, PromptData>? prompts,
    AIFeatureType? selectedFeatureType,
    List<PromptItem>? summaryPrompts,
    List<PromptItem>? stylePrompts,
    List<PromptTemplate>? promptTemplates,
    bool? isLoading,
    bool? isOptimizing,
    bool? isGenerating,
    String? generatedContent,
    String? generationError,
    String? errorMessage,
  }) {
    return PromptInitial();
  }
}

/// 加载中状态
class PromptLoading extends PromptState {
  const PromptLoading({
    Map<AIFeatureType, PromptData> prompts = const {},
    AIFeatureType? selectedFeatureType,
    List<PromptItem> summaryPrompts = const [],
    List<PromptItem> stylePrompts = const [],
    List<PromptTemplate> promptTemplates = const [],
    bool isOptimizing = false,
    bool isGenerating = false,
    String generatedContent = '',
    String? generationError,
  }) : super(
    prompts: prompts,
    selectedFeatureType: selectedFeatureType,
    summaryPrompts: summaryPrompts,
    stylePrompts: stylePrompts,
    promptTemplates: promptTemplates,
    isLoading: true,
    isOptimizing: isOptimizing,
    isGenerating: isGenerating,
    generatedContent: generatedContent,
    generationError: generationError,
  );
  
  @override
  PromptState copyWith({
    Map<AIFeatureType, PromptData>? prompts,
    AIFeatureType? selectedFeatureType,
    List<PromptItem>? summaryPrompts,
    List<PromptItem>? stylePrompts,
    List<PromptTemplate>? promptTemplates,
    bool? isLoading,
    bool? isOptimizing,
    bool? isGenerating,
    String? generatedContent,
    String? generationError,
    String? errorMessage,
  }) {
    return PromptLoading(
      prompts: prompts ?? this.prompts,
      selectedFeatureType: selectedFeatureType ?? this.selectedFeatureType,
      summaryPrompts: summaryPrompts ?? this.summaryPrompts,
      stylePrompts: stylePrompts ?? this.stylePrompts,
      promptTemplates: promptTemplates ?? this.promptTemplates,
      isOptimizing: isOptimizing ?? this.isOptimizing,
      isGenerating: isGenerating ?? this.isGenerating,
      generatedContent: generatedContent ?? this.generatedContent,
      generationError: generationError ?? this.generationError,
    );
  }
}

/// 加载完成状态
class PromptLoaded extends PromptState {
  const PromptLoaded({
    Map<AIFeatureType, PromptData> prompts = const {},
    AIFeatureType? selectedFeatureType,
    List<PromptItem> summaryPrompts = const [],
    List<PromptItem> stylePrompts = const [],
    List<PromptTemplate> promptTemplates = const [],
    bool isOptimizing = false,
    bool isGenerating = false,
    String generatedContent = '',
    String? generationError,
  }) : super(
    prompts: prompts,
    selectedFeatureType: selectedFeatureType,
    summaryPrompts: summaryPrompts,
    stylePrompts: stylePrompts,
    promptTemplates: promptTemplates,
    isLoading: false,
    isOptimizing: isOptimizing,
    isGenerating: isGenerating,
    generatedContent: generatedContent,
    generationError: generationError,
  );
  
  @override
  PromptState copyWith({
    Map<AIFeatureType, PromptData>? prompts,
    AIFeatureType? selectedFeatureType,
    List<PromptItem>? summaryPrompts,
    List<PromptItem>? stylePrompts,
    List<PromptTemplate>? promptTemplates,
    bool? isLoading,
    bool? isOptimizing,
    bool? isGenerating,
    String? generatedContent,
    String? generationError,
    String? errorMessage,
  }) {
    return PromptLoaded(
      prompts: prompts ?? this.prompts,
      selectedFeatureType: selectedFeatureType ?? this.selectedFeatureType,
      summaryPrompts: summaryPrompts ?? this.summaryPrompts,
      stylePrompts: stylePrompts ?? this.stylePrompts,
      promptTemplates: promptTemplates ?? this.promptTemplates,
      isOptimizing: isOptimizing ?? this.isOptimizing,
      isGenerating: isGenerating ?? this.isGenerating,
      generatedContent: generatedContent ?? this.generatedContent,
      generationError: generationError ?? this.generationError,
    );
  }
}

/// 错误状态
class PromptError extends PromptState {
  const PromptError({
    required String errorMessage,
    Map<AIFeatureType, PromptData> prompts = const {},
    AIFeatureType? selectedFeatureType,
    List<PromptItem> summaryPrompts = const [],
    List<PromptItem> stylePrompts = const [],
    List<PromptTemplate> promptTemplates = const [],
    bool isOptimizing = false,
    bool isGenerating = false,
    String generatedContent = '',
    String? generationError,
  }) : super(
    errorMessage: errorMessage,
    prompts: prompts,
    selectedFeatureType: selectedFeatureType,
    summaryPrompts: summaryPrompts,
    stylePrompts: stylePrompts,
    promptTemplates: promptTemplates,
    isLoading: false,
    isOptimizing: isOptimizing,
    isGenerating: isGenerating,
    generatedContent: generatedContent,
    generationError: generationError,
  );
  
  @override
  PromptState copyWith({
    Map<AIFeatureType, PromptData>? prompts,
    AIFeatureType? selectedFeatureType,
    List<PromptItem>? summaryPrompts,
    List<PromptItem>? stylePrompts,
    List<PromptTemplate>? promptTemplates,
    bool? isLoading,
    bool? isOptimizing,
    bool? isGenerating,
    String? generatedContent,
    String? generationError,
    String? errorMessage,
  }) {
    return PromptError(
      errorMessage: errorMessage ?? this.errorMessage!,
      prompts: prompts ?? this.prompts,
      selectedFeatureType: selectedFeatureType ?? this.selectedFeatureType,
      summaryPrompts: summaryPrompts ?? this.summaryPrompts,
      stylePrompts: stylePrompts ?? this.stylePrompts,
      promptTemplates: promptTemplates ?? this.promptTemplates,
      isOptimizing: isOptimizing ?? this.isOptimizing,
      isGenerating: isGenerating ?? this.isGenerating,
      generatedContent: generatedContent ?? this.generatedContent,
      generationError: generationError ?? this.generationError,
    );
  }
}