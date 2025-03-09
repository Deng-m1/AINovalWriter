import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/repositories/editor_repository.dart';

// 事件定义
abstract class EditorEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadEditorContent extends EditorEvent {}

class UpdateContent extends EditorEvent {
  
  UpdateContent({required this.newContent});
  final String newContent;
  
  @override
  List<Object?> get props => [newContent];
}

class SaveContent extends EditorEvent {}

class ToggleEditorSettings extends EditorEvent {}

class UpdateEditorSettings extends EditorEvent {
  
  UpdateEditorSettings({required this.settings});
  final EditorSettings settings;
  
  @override
  List<Object?> get props => [settings];
}

class ApplyAISuggestion extends EditorEvent {
  
  ApplyAISuggestion({required this.suggestion});
  final String suggestion;
  
  @override
  List<Object?> get props => [suggestion];
}

class LoadRevisionHistory extends EditorEvent {}

class RestoreRevision extends EditorEvent {
  
  RestoreRevision({required this.revisionId});
  final String revisionId;
  
  @override
  List<Object?> get props => [revisionId];
}

// 状态定义
abstract class EditorState extends Equatable {
  @override
  List<Object?> get props => [];
}

class EditorInitial extends EditorState {}

class EditorLoading extends EditorState {}

class EditorLoaded extends EditorState {
  
  EditorLoaded({
    required this.content,
    required this.settings,
    this.isDirty = false,
    this.isSaving = false,
    this.lastSaveTime,
    this.errorMessage,
  });
  final EditorContent content;
  final EditorSettings settings;
  final bool isDirty;
  final bool isSaving;
  final DateTime? lastSaveTime;
  final String? errorMessage;
  
  @override
  List<Object?> get props => [
    content, 
    settings, 
    isDirty, 
    isSaving, 
    lastSaveTime, 
    errorMessage
  ];
  
  EditorLoaded copyWith({
    EditorContent? content,
    EditorSettings? settings,
    bool? isDirty,
    bool? isSaving,
    DateTime? lastSaveTime,
    String? errorMessage,
  }) {
    return EditorLoaded(
      content: content ?? this.content,
      settings: settings ?? this.settings,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      lastSaveTime: lastSaveTime ?? this.lastSaveTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class EditorSettingsOpen extends EditorState { // 添加content属性，以便于切换回EditorLoaded状态
  
  EditorSettingsOpen({
    required this.settings,
    required this.content,
  });
  final EditorSettings settings;
  final EditorContent content;
  
  @override
  List<Object?> get props => [settings, content];
}

class EditorError extends EditorState {
  
  EditorError({required this.message});
  final String message;
  
  @override
  List<Object?> get props => [message];
}

class EditorRevisionsLoaded extends EditorState {
  
  EditorRevisionsLoaded({required this.revisions});
  final List<Revision> revisions;
  
  @override
  List<Object?> get props => [revisions];
}

// Bloc实现
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  
  EditorBloc({
    required this.repository,
    required this.novelId,
    required this.chapterId,
  }) : super(EditorInitial()) {
    on<LoadEditorContent>(_onLoadContent);
    on<UpdateContent>(_onUpdateContent);
    on<SaveContent>(_onSaveContent);
    on<ToggleEditorSettings>(_onToggleSettings);
    on<UpdateEditorSettings>(_onUpdateSettings);
    on<ApplyAISuggestion>(_onApplyAISuggestion);
    on<LoadRevisionHistory>(_onLoadRevisionHistory);
    on<RestoreRevision>(_onRestoreRevision);
  }
  final EditorRepository repository;
  final String novelId;
  final String chapterId;
  Timer? _autoSaveTimer;
  
  Future<void> _onLoadContent(LoadEditorContent event, Emitter<EditorState> emit) async {
    emit(EditorLoading());
    try {
      final content = await repository.getEditorContent(novelId, chapterId);
      final settings = await repository.getEditorSettings();
      emit(EditorLoaded(
        content: content,
        settings: settings,
        isDirty: false,
        isSaving: false,
      ));
      
      // 设置自动保存
      if (settings.autoSaveEnabled) {
        _setupAutoSave();
      }
    } catch (e) {
      emit(EditorError(message: e.toString()));
    }
  }
  
  Future<void> _onUpdateContent(UpdateContent event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(currentState.copyWith(
        content: currentState.content.copyWith(content: event.newContent),
        isDirty: true,
      ));
    }
  }
  
  Future<void> _onSaveContent(SaveContent event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded && currentState.isDirty) {
      emit(currentState.copyWith(isSaving: true));
      try {
        final savedContent = await repository.saveEditorContent(
          novelId,
          chapterId,
          currentState.content.content,
        );
        emit(currentState.copyWith(
          content: savedContent,
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }
  
  void _onToggleSettings(ToggleEditorSettings event, Emitter<EditorState> emit) {
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(EditorSettingsOpen(
        settings: currentState.settings,
        content: currentState.content,
      ));
    } else if (currentState is EditorSettingsOpen) {
      emit(EditorLoaded(
        content: currentState.content,
        settings: currentState.settings,
      ));
    }
  }
  
  Future<void> _onUpdateSettings(UpdateEditorSettings event, Emitter<EditorState> emit) async {
    try {
      await repository.saveEditorSettings(event.settings);
      
      final currentState = state;
      if (currentState is EditorLoaded) {
        // 更新设置
        emit(currentState.copyWith(settings: event.settings));
        
        // 重新设置自动保存
        if (event.settings.autoSaveEnabled) {
          _setupAutoSave();
        } else {
          _autoSaveTimer?.cancel();
          _autoSaveTimer = null;
        }
      } else if (currentState is EditorSettingsOpen) {
        emit(EditorSettingsOpen(
          settings: event.settings,
          content: currentState.content,
        ));
      }
    } catch (e) {
      emit(EditorError(message: '保存设置失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onApplyAISuggestion(ApplyAISuggestion event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 简单实现：将AI建议追加到内容末尾
      final updatedContent = '${currentState.content.content}\n${event.suggestion}';
      
      emit(currentState.copyWith(
        content: currentState.content.copyWith(content: updatedContent),
        isDirty: true,
      ));
    }
  }
  
  Future<void> _onLoadRevisionHistory(LoadRevisionHistory event, Emitter<EditorState> emit) async {
    try {
      final revisions = await repository.getRevisionHistory(novelId, chapterId);
      emit(EditorRevisionsLoaded(revisions: revisions));
    } catch (e) {
      emit(EditorError(message: '加载修订历史失败: ${e.toString()}'));
    }
  }
  
  Future<void> _onRestoreRevision(RestoreRevision event, Emitter<EditorState> emit) async {
    try {
      final restoredContent = await repository.restoreRevision(
        novelId,
        chapterId,
        event.revisionId,
      );
      
      final currentState = state;
      if (currentState is EditorLoaded) {
        emit(currentState.copyWith(
          content: restoredContent,
          isDirty: true,
        ));
      }
    } catch (e) {
      emit(EditorError(message: '恢复修订版本失败: ${e.toString()}'));
    }
  }
  
  // 设置自动保存
  void _setupAutoSave() {
    final currentState = state;
    if (currentState is EditorLoaded) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer.periodic(
        currentState.settings.autoSaveInterval,
        (timer) {
          if (state is EditorLoaded && (state as EditorLoaded).isDirty) {
            add(SaveContent());
          }
        },
      );
    }
  }
  
  @override
  Future<void> close() {
    _autoSaveTimer?.cancel();
    return super.close();
  }
} 