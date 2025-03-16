part of 'editor_version_bloc.dart';

/// 编辑器版本控制事件
abstract class EditorVersionEvent extends Equatable {
  const EditorVersionEvent();

  @override
  List<Object?> get props => [];
}

/// 获取版本历史记录事件
class EditorVersionFetchHistory extends EditorVersionEvent {

  const EditorVersionFetchHistory({
    required this.novelId,
    required this.chapterId,
    required this.sceneId,
  });
  final String novelId;
  final String chapterId;
  final String sceneId;

  @override
  List<Object?> get props => [novelId, chapterId, sceneId];
}

/// 比较版本差异事件
class EditorVersionCompare extends EditorVersionEvent {

  const EditorVersionCompare({
    required this.novelId,
    required this.chapterId,
    required this.sceneId,
    required this.versionIndex1,
    required this.versionIndex2,
  });
  final String novelId;
  final String chapterId;
  final String sceneId;
  final int versionIndex1;
  final int versionIndex2;

  @override
  List<Object?> get props => [
    novelId, 
    chapterId, 
    sceneId, 
    versionIndex1, 
    versionIndex2,
  ];
}

/// 恢复版本事件
class EditorVersionRestore extends EditorVersionEvent {

  const EditorVersionRestore({
    required this.novelId,
    required this.chapterId,
    required this.sceneId,
    required this.historyIndex,
    required this.userId,
    required this.reason,
  });
  final String novelId;
  final String chapterId;
  final String sceneId;
  final int historyIndex;
  final String userId;
  final String reason;

  @override
  List<Object?> get props => [
    novelId, 
    chapterId, 
    sceneId, 
    historyIndex, 
    userId, 
    reason,
  ];
}

/// 保存版本事件
class EditorVersionSave extends EditorVersionEvent {

  const EditorVersionSave({
    required this.novelId,
    required this.chapterId,
    required this.sceneId,
    required this.content,
    required this.userId,
    required this.reason,
  });
  final String novelId;
  final String chapterId;
  final String sceneId;
  final String content;
  final String userId;
  final String reason;

  @override
  List<Object?> get props => [
    novelId, 
    chapterId, 
    sceneId, 
    content, 
    userId, 
    reason,
  ];
} 