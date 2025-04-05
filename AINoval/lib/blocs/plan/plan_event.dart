part of 'plan_bloc.dart';

abstract class PlanEvent extends Equatable {
  const PlanEvent();

  @override
  List<Object?> get props => [];
}

class LoadPlanContent extends PlanEvent {
  const LoadPlanContent();
}

class UpdateActTitle extends PlanEvent {
  const UpdateActTitle({
    required this.actId,
    required this.title,
  });
  final String actId;
  final String title;

  @override
  List<Object?> get props => [actId, title];
}

class UpdateChapterTitle extends PlanEvent {
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

class UpdateSceneSummary extends PlanEvent {
  const UpdateSceneSummary({
    required this.novelId,
    required this.actId,
    required this.chapterId,
    required this.sceneId,
    required this.summary,
  });
  final String novelId;
  final String actId;
  final String chapterId;
  final String sceneId;
  final String summary;

  @override
  List<Object?> get props => [novelId, actId, chapterId, sceneId, summary];
}

class AddNewAct extends PlanEvent {
  const AddNewAct({this.title = '新Act'});
  final String title;

  @override
  List<Object?> get props => [title];
}

class AddNewChapter extends PlanEvent {
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

class AddNewScene extends PlanEvent {
  const AddNewScene({
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

class MoveScene extends PlanEvent {
  const MoveScene({
    required this.novelId,
    required this.sourceActId,
    required this.sourceChapterId,
    required this.sourceSceneId,
    required this.targetActId,
    required this.targetChapterId,
    required this.targetIndex,
  });
  final String novelId;
  final String sourceActId;
  final String sourceChapterId;
  final String sourceSceneId;
  final String targetActId;
  final String targetChapterId;
  final int targetIndex;

  @override
  List<Object?> get props => [
        novelId,
        sourceActId,
        sourceChapterId,
        sourceSceneId,
        targetActId,
        targetChapterId,
        targetIndex,
      ];
}

class DeleteScene extends PlanEvent {
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