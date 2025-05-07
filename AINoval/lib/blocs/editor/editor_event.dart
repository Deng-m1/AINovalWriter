part of 'editor_bloc.dart';

abstract class EditorEvent extends Equatable {
  const EditorEvent();

  @override
  List<Object?> get props => [];
}

class LoadEditorContent extends EditorEvent {
  const LoadEditorContent();
}

/// 使用分页加载编辑器内容事件
class LoadEditorContentPaginated extends EditorEvent {

  const LoadEditorContentPaginated({
    required this.novelId,
    this.lastEditedChapterId,
    this.chaptersLimit = 5,
    this.loadAllSummaries = false,
  });
  final String novelId;
  final String? lastEditedChapterId;
  final int chaptersLimit;
  final bool loadAllSummaries;

  @override
  List<Object?> get props => [novelId, lastEditedChapterId, chaptersLimit, loadAllSummaries];
}

/// 加载更多场景事件
class LoadMoreScenes extends EditorEvent {

  const LoadMoreScenes({
    required this.fromChapterId,
    required this.direction,
    this.chaptersLimit = 3,
    this.targetActId,
    this.targetChapterId,
    this.targetSceneId,
    this.preventFocusChange = false,
    this.loadFromLocalOnly = false,
    this.skipIfLoading = false,
    this.skipAPIFallback = false,
  });
  final String fromChapterId;
  final String direction; // "up" 或 "down" 或 "center"
  final int chaptersLimit;
  final String? targetActId;
  final String? targetChapterId;
  final String? targetSceneId;
  final bool preventFocusChange;
  final bool loadFromLocalOnly; // 是否只从本地加载，避免网络请求
  final bool skipIfLoading; // 如果已经有加载任务，是否跳过此次加载
  final bool skipAPIFallback; // 当loadFromLocalOnly为true且本地加载失败时，是否跳过API回退

  @override
  List<Object?> get props => [
    fromChapterId,
    direction,
    chaptersLimit,
    targetActId,
    targetChapterId,
    targetSceneId,
    preventFocusChange,
    loadFromLocalOnly,
    skipIfLoading,
    skipAPIFallback,
  ];
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
    this.wordCount,
    this.shouldRebuild = true,
    this.isMinorChange,
  });
  final String novelId;
  final String actId;
  final String chapterId;
  final String sceneId;
  final String content;
  final String? wordCount;
  final bool shouldRebuild;
  final bool? isMinorChange; // 是否为微小改动，微小改动可以不刷新保存状态UI

  @override
  List<Object?> get props =>
      [novelId, actId, chapterId, sceneId, content, wordCount, shouldRebuild, isMinorChange];
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
  List<Object?> get props =>
      [novelId, actId, chapterId, sceneId, summary, shouldRebuild];
}

class SetActiveChapter extends EditorEvent {
  const SetActiveChapter({
    required this.actId,
    required this.chapterId,
    this.shouldScroll = true,
  });
  final String actId;
  final String chapterId;
  final bool shouldScroll;

  @override
  List<Object?> get props => [actId, chapterId, shouldScroll];
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
    this.shouldScroll = true,
  });
  final String actId;
  final String chapterId;
  final String sceneId;
  final bool shouldScroll;

  @override
  List<Object?> get props => [actId, chapterId, sceneId, shouldScroll];
}

// 删除场景事件 (New Event)
class DeleteScene extends EditorEvent {
  const DeleteScene({
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

// 删除章节事件
class DeleteChapter extends EditorEvent {
  const DeleteChapter({
    required this.novelId,
    required this.actId,
    required this.chapterId,
  });
  final String novelId;
  final String actId;
  final String chapterId;

  @override
  List<Object?> get props => [novelId, actId, chapterId];
}

// 生成场景摘要事件
class GenerateSceneSummaryRequested extends EditorEvent {
  final String sceneId;
  final String? styleInstructions;

  const GenerateSceneSummaryRequested({
    required this.sceneId,
    this.styleInstructions,
  });

  @override
  List<Object?> get props => [sceneId, styleInstructions];
}

// 从摘要生成场景内容事件
class GenerateSceneFromSummaryRequested extends EditorEvent {
  final String novelId;
  final String summary;
  final String? chapterId;
  final String? styleInstructions;
  final bool useStreamingMode;

  const GenerateSceneFromSummaryRequested({
    required this.novelId,
    required this.summary,
    this.chapterId,
    this.styleInstructions,
    this.useStreamingMode = true,
  });

  @override
  List<Object?> get props => [novelId, summary, chapterId, styleInstructions, useStreamingMode];
}

// 更新生成的场景内容事件 (用于流式响应)
class UpdateGeneratedSceneContent extends EditorEvent {
  final String content;

  const UpdateGeneratedSceneContent(this.content);

  @override
  List<Object?> get props => [content];
}

// 完成场景生成事件
class SceneGenerationCompleted extends EditorEvent {
  final String content;

  const SceneGenerationCompleted(this.content);

  @override
  List<Object?> get props => [content];
}

// 场景生成失败事件
class SceneGenerationFailed extends EditorEvent {
  final String error;

  const SceneGenerationFailed(this.error);

  @override
  List<Object?> get props => [error];
}

// 场景摘要生成完成事件
class SceneSummaryGenerationCompleted extends EditorEvent {
  final String summary;

  const SceneSummaryGenerationCompleted(this.summary);

  @override
  List<Object?> get props => [summary];
}

// 场景摘要生成失败事件
class SceneSummaryGenerationFailed extends EditorEvent {
  final String error;

  const SceneSummaryGenerationFailed(this.error);

  @override
  List<Object?> get props => [error];
}

// 停止场景生成事件
class StopSceneGeneration extends EditorEvent {
  const StopSceneGeneration();

  @override
  List<Object?> get props => [];
}

// 刷新编辑器事件
class RefreshEditor extends EditorEvent {
  const RefreshEditor();

  @override
  List<Object?> get props => [];
}

// 设置待处理的摘要内容事件
class SetPendingSummary extends EditorEvent {
  final String summary;

  const SetPendingSummary({
    required this.summary,
  });

  @override
  List<Object?> get props => [summary];
}

/// 保存场景内容事件
class SaveSceneContent extends EditorEvent {
  final String novelId;
  final String actId;
  final String chapterId;
  final String sceneId;
  final String content;
  final String wordCount;
  final bool localOnly; // 添加参数：是否只保存到本地

  const SaveSceneContent({
    required this.novelId,
    required this.actId,
    required this.chapterId,
    required this.sceneId,
    required this.content,
    required this.wordCount,
    this.localOnly = false, // 默认为false，表示同时同步到服务器
  });

  @override
  List<Object> get props => [novelId, actId, chapterId, sceneId, content, wordCount, localOnly];
}

class UpdateVisibleRange extends EditorEvent {
  const UpdateVisibleRange({
    required this.startIndex,
    required this.endIndex,
  });
  final int startIndex;
  final int endIndex;
  
  @override
  List<Object?> get props => [startIndex, endIndex];
}

/// 重置章节加载标记
class ResetActLoadingFlags extends EditorEvent {
  const ResetActLoadingFlags();
}

/// 设置章节加载边界标记
class SetActLoadingFlags extends EditorEvent {
  final bool? hasReachedEnd;
  final bool? hasReachedStart;

  const SetActLoadingFlags({
    this.hasReachedEnd,
    this.hasReachedStart,
  });
}

// 设置焦点章节事件
class SetFocusChapter extends EditorEvent {
  const SetFocusChapter({
    required this.chapterId,
  });
  final String chapterId;

  @override
  List<Object?> get props => [chapterId];
}
