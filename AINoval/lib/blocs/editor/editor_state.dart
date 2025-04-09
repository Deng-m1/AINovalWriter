part of 'editor_bloc.dart';

// AI生成状态
enum AIGenerationStatus {
  /// 初始状态
  initial,
  
  /// 生成中
  generating,
  
  /// 生成完成
  completed,
  
  /// 生成失败
  failed,
}

abstract class EditorState extends Equatable {
  const EditorState();
  
  @override
  List<Object?> get props => [];
}

class EditorInitial extends EditorState {}

class EditorLoading extends EditorState {}

class EditorLoaded extends EditorState {
  
  const EditorLoaded({
    required this.novel,
    required this.settings,
    this.activeActId,
    this.activeChapterId,
    this.activeSceneId,
    this.isDirty = false,
    this.isSaving = false,
    this.isLoading = false,
    this.lastSaveTime,
    this.errorMessage,
    this.aiSummaryGenerationStatus = AIGenerationStatus.initial,
    this.aiSceneGenerationStatus = AIGenerationStatus.initial,
    this.generatedSummary,
    this.generatedSceneContent,
    this.aiGenerationError,
    this.isStreamingGeneration = false,
  });
  final novel_models.Novel novel;
  final Map<String, dynamic> settings;
  final String? activeActId;
  final String? activeChapterId;
  final String? activeSceneId;
  final bool isDirty;
  final bool isSaving;
  final bool isLoading;
  final DateTime? lastSaveTime;
  final String? errorMessage;
  
  /// AI生成状态
  final AIGenerationStatus aiSummaryGenerationStatus;
  
  /// AI生成场景状态
  final AIGenerationStatus aiSceneGenerationStatus;
  
  /// AI生成的摘要内容
  final String? generatedSummary;
  
  /// AI生成的场景内容
  final String? generatedSceneContent;
  
  /// AI生成过程中的错误消息
  final String? aiGenerationError;
  
  /// 是否正在使用流式生成
  final bool isStreamingGeneration;
  
  @override
  List<Object?> get props => [
    novel,
    settings,
    activeActId,
    activeChapterId,
    activeSceneId,
    isDirty,
    isSaving,
    isLoading,
    lastSaveTime,
    errorMessage,
    aiSummaryGenerationStatus,
    aiSceneGenerationStatus,
    generatedSummary,
    generatedSceneContent,
    aiGenerationError,
    isStreamingGeneration,
  ];
  
  EditorLoaded copyWith({
    novel_models.Novel? novel,
    Map<String, dynamic>? settings,
    String? activeActId,
    String? activeChapterId,
    String? activeSceneId,
    bool? isDirty,
    bool? isSaving,
    bool? isLoading,
    DateTime? lastSaveTime,
    String? errorMessage,
    AIGenerationStatus? aiSummaryGenerationStatus,
    AIGenerationStatus? aiSceneGenerationStatus,
    String? generatedSummary,
    String? generatedSceneContent,
    String? aiGenerationError,
    bool? isStreamingGeneration,
  }) {
    return EditorLoaded(
      novel: novel ?? this.novel,
      settings: settings ?? this.settings,
      activeActId: activeActId ?? this.activeActId,
      activeChapterId: activeChapterId ?? this.activeChapterId,
      activeSceneId: activeSceneId ?? this.activeSceneId,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      lastSaveTime: lastSaveTime ?? this.lastSaveTime,
      errorMessage: errorMessage ?? this.errorMessage,
      aiSummaryGenerationStatus: aiSummaryGenerationStatus ?? this.aiSummaryGenerationStatus,
      aiSceneGenerationStatus: aiSceneGenerationStatus ?? this.aiSceneGenerationStatus,
      generatedSummary: generatedSummary ?? this.generatedSummary,
      generatedSceneContent: generatedSceneContent ?? this.generatedSceneContent,
      aiGenerationError: aiGenerationError,
      isStreamingGeneration: isStreamingGeneration ?? this.isStreamingGeneration,
    );
  }
}

class EditorSettingsOpen extends EditorState {
  
  const EditorSettingsOpen({
    required this.novel,
    required this.settings,
    this.activeActId,
    this.activeChapterId,
    this.activeSceneId,
    this.isDirty = false,
  });
  final novel_models.Novel novel;
  final Map<String, dynamic> settings;
  final String? activeActId;
  final String? activeChapterId;
  final String? activeSceneId;
  final bool isDirty;
  
  @override
  List<Object?> get props => [
    novel,
    settings,
    activeActId,
    activeChapterId,
    activeSceneId,
    isDirty,
  ];
  
  EditorSettingsOpen copyWith({
    novel_models.Novel? novel,
    Map<String, dynamic>? settings,
    String? activeActId,
    String? activeChapterId,
    String? activeSceneId,
    bool? isDirty,
  }) {
    return EditorSettingsOpen(
      novel: novel ?? this.novel,
      settings: settings ?? this.settings,
      activeActId: activeActId ?? this.activeActId,
      activeChapterId: activeChapterId ?? this.activeChapterId,
      activeSceneId: activeSceneId ?? this.activeSceneId,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

class EditorError extends EditorState {
  
  const EditorError({required this.message});
  final String message;
  
  @override
  List<Object?> get props => [message];
} 