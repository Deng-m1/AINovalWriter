part of 'editor_bloc.dart';

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