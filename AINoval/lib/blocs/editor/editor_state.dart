import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:equatable/equatable.dart';

// 编辑器状态枚举
enum EditorStatus {
  initial,
  loading,
  loaded,
  saving,
  saved,
  error,
}

// 编辑器状态类
class EditorState extends Equatable {
  
  const EditorState({
    this.novel,
    this.currentChapterId = '',
    this.content = '',
    this.settings = const EditorSettings(),
    this.status = EditorStatus.initial,
    this.errorMessage = '',
    this.canUndo = false,
    this.canRedo = false,
    this.wordCount = 0,
    this.isModified = false,
  });
  
  final novel_models.Novel? novel;
  final String currentChapterId;
  final String content;
  final EditorSettings settings;
  final EditorStatus status;
  final String errorMessage;
  final bool canUndo;
  final bool canRedo;
  final int wordCount;
  final bool isModified;
  
  // 获取小说标题
  String get novelTitle => novel?.title ?? '加载中...';
  
  @override
  List<Object?> get props => [
    novel,
    currentChapterId,
    content,
    settings,
    status,
    errorMessage,
    canUndo,
    canRedo,
    wordCount,
    isModified,
  ];
  
  // 创建状态副本
  EditorState copyWith({
    novel_models.Novel? novel,
    String? currentChapterId,
    String? content,
    EditorSettings? settings,
    EditorStatus? status,
    String? errorMessage,
    bool? canUndo,
    bool? canRedo,
    int? wordCount,
    bool? isModified,
  }) {
    return EditorState(
      novel: novel ?? this.novel,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      content: content ?? this.content,
      settings: settings ?? this.settings,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      wordCount: wordCount ?? this.wordCount,
      isModified: isModified ?? this.isModified,
    );
  }
}

class EditorInitial extends EditorState {}

class EditorLoading extends EditorState {}

class EditorLoaded extends EditorState {
  
  const EditorLoaded({
    required this.novel,
    required this.settings,
    this.activeActId,
    this.activeChapterId,
    this.isDirty = false,
    this.isSaving = false,
    this.lastSaveTime,
    this.errorMessage,
  });
  final novel_models.Novel novel;
  final Map<String, dynamic> settings;
  final String? activeActId;
  final String? activeChapterId;
  final bool isDirty;
  final bool isSaving;
  final DateTime? lastSaveTime;
  final String? errorMessage;
  
  @override
  List<Object?> get props => [
    novel,
    settings,
    activeActId,
    activeChapterId,
    isDirty,
    isSaving,
    lastSaveTime,
    errorMessage,
  ];
  
  EditorLoaded copyWith({
    novel_models.Novel? novel,
    Map<String, dynamic>? settings,
    String? activeActId,
    String? activeChapterId,
    bool? isDirty,
    bool? isSaving,
    DateTime? lastSaveTime,
    String? errorMessage,
  }) {
    return EditorLoaded(
      novel: novel ?? this.novel,
      settings: settings ?? this.settings,
      activeActId: activeActId ?? this.activeActId,
      activeChapterId: activeChapterId ?? this.activeChapterId,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
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
    this.isDirty = false,
  });
  final novel_models.Novel novel;
  final Map<String, dynamic> settings;
  final String? activeActId;
  final String? activeChapterId;
  final bool isDirty;
  
  @override
  List<Object?> get props => [
    novel,
    settings,
    activeActId,
    activeChapterId,
    isDirty,
  ];
  
  EditorSettingsOpen copyWith({
    novel_models.Novel? novel,
    Map<String, dynamic>? settings,
    String? activeActId,
    String? activeChapterId,
    bool? isDirty,
  }) {
    return EditorSettingsOpen(
      novel: novel ?? this.novel,
      settings: settings ?? this.settings,
      activeActId: activeActId ?? this.activeActId,
      activeChapterId: activeChapterId ?? this.activeChapterId,
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