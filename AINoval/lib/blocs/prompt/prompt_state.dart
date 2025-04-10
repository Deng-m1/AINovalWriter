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
  });

  final Map<AIFeatureType, PromptData> prompts;
  final AIFeatureType? selectedFeatureType;
  final bool isLoading;
  final String? errorMessage;
  final bool isGenerating;
  final String generatedContent;
  final String? generationError;

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
  }) {
    return PromptState(
      prompts: prompts ?? this.prompts,
      selectedFeatureType: selectedFeatureType ?? this.selectedFeatureType,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isGenerating: isGenerating ?? this.isGenerating,
      generatedContent: generatedContent ?? this.generatedContent,
      generationError: generationError,
    );
  }

  @override
  List<Object?> get props => [prompts, selectedFeatureType, isLoading, errorMessage, isGenerating, generatedContent, generationError];
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
  }) : super(
          prompts: prompts,
          selectedFeatureType: selectedFeatureType,
          isLoading: true,
        );
}

/// 加载完成状态
class PromptLoaded extends PromptState {
  const PromptLoaded({
    required Map<AIFeatureType, PromptData> prompts,
    AIFeatureType? selectedFeatureType,
  }) : super(
          prompts: prompts,
          selectedFeatureType: selectedFeatureType,
          isLoading: false,
        );
}

/// 错误状态
class PromptError extends PromptState {
  const PromptError({
    required String errorMessage,
    required Map<AIFeatureType, PromptData> prompts,
    AIFeatureType? selectedFeatureType,
  }) : super(
          prompts: prompts,
          selectedFeatureType: selectedFeatureType,
          isLoading: false,
          errorMessage: errorMessage,
        );
}