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
    required this.novelId,
    required this.actId,
    required this.chapterId,
    required this.sceneId,
    required this.content,
    this.shouldRebuild = true,
  });
  final String novelId;
  final String actId;
  final String chapterId;
  final String sceneId;
  final String content;
  final bool shouldRebuild;
  
  @override
  List<Object?> get props => [novelId, actId, chapterId, sceneId, content, shouldRebuild];
}

class UpdateSummary extends EditorEvent {
  
  const UpdateSummary({
    required this.novelId,
    required this.actId,
    required this.chapterId,
    required this.sceneId,
    required this.summary,
    this.shouldRebuild = true,
  });
  final String novelId;
  final String actId;
  final String chapterId;
  final String sceneId;
  final String summary;
  final bool shouldRebuild;
  
  @override
  List<Object?> get props => [novelId, actId, chapterId, sceneId, summary, shouldRebuild];
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

// 添加新的Act事件
class AddNewAct extends EditorEvent {
  const AddNewAct({this.title = '新Act'});
  final String title;
  
  @override
  List<Object?> get props => [title];
}

// 添加新的Chapter事件
class AddNewChapter extends EditorEvent {
  const AddNewChapter({
    required this.novelId,
    required this.actId,
    this.title = '新章节',
  });
  final String novelId;
  final String actId;
  final String title;
  
  @override
  List<Object?> get props => [novelId, actId, title];
}

// 添加新的Scene事件
class AddNewScene extends EditorEvent {
  const AddNewScene({
    required this.novelId,
    required this.actId,
    required this.chapterId,
    required this.sceneId,
  });
  final String novelId;
  final String actId;
  final String chapterId;
  final String sceneId;
  
  @override
  List<Object?> get props => [novelId, actId, chapterId, sceneId];
}

// 设置活动场景事件
class SetActiveScene extends EditorEvent {
  
  const SetActiveScene({
    required this.actId,
    required this.chapterId,
    required this.sceneId,
  });
  final String actId;
  final String chapterId;
  final String sceneId;
  
  @override
  List<Object?> get props => [actId, chapterId, sceneId];
} 