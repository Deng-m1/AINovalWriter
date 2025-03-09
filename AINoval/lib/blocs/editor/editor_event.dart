part of 'editor_bloc.dart';

abstract class EditorEvent extends Equatable {
  const EditorEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadEditorContent extends EditorEvent {
  const LoadEditorContent();
}

class UpdateContent extends EditorEvent {
  
  const UpdateContent({required this.content});
  final String content;
  
  @override
  List<Object?> get props => [content];
}

class SaveContent extends EditorEvent {
  const SaveContent();
}

class UpdateSceneContent extends EditorEvent {
  
  const UpdateSceneContent({
    required this.actId,
    required this.chapterId,
    required this.content,
  });
  final String actId;
  final String chapterId;
  final String content;
  
  @override
  List<Object?> get props => [actId, chapterId, content];
}

class UpdateSummary extends EditorEvent {
  
  const UpdateSummary({
    required this.actId,
    required this.chapterId,
    required this.summary,
  });
  final String actId;
  final String chapterId;
  final String summary;
  
  @override
  List<Object?> get props => [actId, chapterId, summary];
}

class SetActiveChapter extends EditorEvent {
  
  const SetActiveChapter({
    required this.actId,
    required this.chapterId,
  });
  final String actId;
  final String chapterId;
  
  @override
  List<Object?> get props => [actId, chapterId];
}

class ToggleEditorSettings extends EditorEvent {
  const ToggleEditorSettings();
}

class UpdateEditorSettings extends EditorEvent {
  
  const UpdateEditorSettings({required this.settings});
  final Map<String, dynamic> settings;
  
  @override
  List<Object?> get props => [settings];
}

class UpdateActTitle extends EditorEvent {
  
  const UpdateActTitle({
    required this.actId,
    required this.title,
  });
  final String actId;
  final String title;
  
  @override
  List<Object?> get props => [actId, title];
}

class UpdateChapterTitle extends EditorEvent {
  
  const UpdateChapterTitle({
    required this.actId,
    required this.chapterId,
    required this.title,
  });
  final String actId;
  final String chapterId;
  final String title;
  
  @override
  List<Object?> get props => [actId, chapterId, title];
} 