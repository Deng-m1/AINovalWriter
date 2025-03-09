import 'package:ainoval/models/editor_settings.dart';
import 'package:equatable/equatable.dart';

// 编辑器事件基类
abstract class EditorEvent extends Equatable {
  const EditorEvent();
  
  @override
  List<Object?> get props => [];
}

// 加载小说事件
class LoadNovel extends EditorEvent {
  
  const LoadNovel({required this.novelId});
  final String novelId;
  
  @override
  List<Object?> get props => [novelId];
}

// 加载章节事件
class LoadChapter extends EditorEvent {
  
  const LoadChapter({required this.chapterId});
  final String chapterId;
  
  @override
  List<Object?> get props => [chapterId];
}

// 更新内容事件
class UpdateContent extends EditorEvent {
  
  const UpdateContent({required this.content});
  final String content;
  
  @override
  List<Object?> get props => [content];
}

// 保存内容事件
class SaveContent extends EditorEvent {
  const SaveContent();
}

// 撤销编辑事件
class UndoEdit extends EditorEvent {
  const UndoEdit();
}

// 重做编辑事件
class RedoEdit extends EditorEvent {
  const RedoEdit();
}

// 更新设置事件
class UpdateSettings extends EditorEvent {
  
  const UpdateSettings({required this.settings});
  final EditorSettings settings;
  
  @override
  List<Object?> get props => [settings];
}

// 添加章节事件
class AddChapter extends EditorEvent {
  
  const AddChapter({
    required this.actId,
    required this.title,
  });
  final String actId;
  final String title;
  
  @override
  List<Object?> get props => [actId, title];
}

// 删除章节事件
class DeleteChapter extends EditorEvent {
  
  const DeleteChapter({required this.chapterId});
  final String chapterId;
  
  @override
  List<Object?> get props => [chapterId];
}

// 重命名章节事件
class RenameChapter extends EditorEvent {
  
  const RenameChapter({
    required this.chapterId,
    required this.newTitle,
  });
  final String chapterId;
  final String newTitle;
  
  @override
  List<Object?> get props => [chapterId, newTitle];
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