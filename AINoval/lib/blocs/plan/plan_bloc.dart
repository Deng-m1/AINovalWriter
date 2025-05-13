import 'dart:async';

import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../utils/logger.dart';

part 'plan_event.dart';
part 'plan_state.dart';

class PlanBloc extends Bloc<PlanEvent, PlanState> {
  PlanBloc({
    required EditorRepositoryImpl repository,
    required this.novelId,
  })  : repository = repository,
        super(PlanInitial()) {
    on<LoadPlanContent>(_onLoadContent);
    on<UpdateActTitle>(_onUpdateActTitle);
    on<UpdateChapterTitle>(_onUpdateChapterTitle);
    on<UpdateSceneSummary>(_onUpdateSceneSummary);
    on<AddNewAct>(_onAddNewAct);
    on<AddNewChapter>(_onAddNewChapter);
    on<AddNewScene>(_onAddNewScene);
    on<MoveScene>(_onMoveScene);
    on<DeleteScene>(_onDeleteScene);
  }
  
  final EditorRepositoryImpl repository;
  final String novelId;

  Future<void> _onLoadContent(
      LoadPlanContent event, Emitter<PlanState> emit) async {
    emit(PlanLoading());

    try {
      AppLogger.i('PlanBloc/_onLoadContent', '开始加载小说大纲数据');
      // 获取小说数据（带场景摘要）
      final novel = await repository.getNovelWithSceneSummaries(novelId);

      if (novel == null) {
        emit(const PlanError(message: '无法加载小说大纲数据'));
        return;
      }

      emit(PlanLoaded(
        novel: novel,
        isDirty: false,
        isSaving: false,
      ));
    } catch (e) {
      emit(PlanError(message: e.toString()));
    }
  }

  Future<void> _onUpdateActTitle(
      UpdateActTitle event, Emitter<PlanState> emit) async {
    final currentState = state;
    if (currentState is PlanLoaded) {
      try {
        // 更新标题逻辑
        final acts = currentState.novel.acts.map((act) {
          if (act.id == event.actId) {
            return act.copyWith(title: event.title);
          }
          return act;
        }).toList();

        final updatedNovel = currentState.novel.copyWith(acts: acts);

        emit(currentState.copyWith(
          novel: updatedNovel,
          isDirty: true,
        ));
        
        // 保存到服务器
        await repository.updateActTitle(
          novelId,
          event.actId,
          event.title,
        );
        
        emit(currentState.copyWith(isDirty: false));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: '更新Act标题失败: ${e.toString()}',
        ));
      }
    }
  }

  Future<void> _onUpdateChapterTitle(
      UpdateChapterTitle event, Emitter<PlanState> emit) async {
    final currentState = state;
    if (currentState is PlanLoaded) {
      try {
        // 更新标题逻辑
        final acts = currentState.novel.acts.map((act) {
          if (act.id == event.actId) {
            final chapters = act.chapters.map((chapter) {
              if (chapter.id == event.chapterId) {
                return chapter.copyWith(title: event.title);
              }
              return chapter;
            }).toList();
            return act.copyWith(chapters: chapters);
          }
          return act;
        }).toList();

        final updatedNovel = currentState.novel.copyWith(acts: acts);

        emit(currentState.copyWith(
          novel: updatedNovel,
          isDirty: true,
        ));
        
        // 保存到服务器
        await repository.updateChapterTitle(
          novelId,
          event.actId,
          event.chapterId,
          event.title,
        );
        
        emit(currentState.copyWith(isDirty: false));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: '更新Chapter标题失败: ${e.toString()}',
        ));
      }
    }
  }

  Future<void> _onUpdateSceneSummary(
      UpdateSceneSummary event, Emitter<PlanState> emit) async {
    final currentState = state;
    if (currentState is PlanLoaded) {
      try {
        // 更新摘要逻辑
        bool updated = false;
        final acts = currentState.novel.acts.map((act) {
          if (act.id == event.actId) {
            final chapters = act.chapters.map((chapter) {
              if (chapter.id == event.chapterId) {
                final scenes = chapter.scenes.map((scene) {
                  if (scene.id == event.sceneId) {
                    updated = true;
                    final updatedSummary = novel_models.Summary(
                      id: scene.summary.id,
                      content: event.summary,
                    );
                    return scene.copyWith(summary: updatedSummary);
                  }
                  return scene;
                }).toList();
                return chapter.copyWith(scenes: scenes);
              }
              return chapter;
            }).toList();
            return act.copyWith(chapters: chapters);
          }
          return act;
        }).toList();

        if (!updated) {
          emit(currentState.copyWith(
            errorMessage: '未找到对应的场景',
          ));
          return;
        }

        final updatedNovel = currentState.novel.copyWith(acts: acts);

        // 先更新UI以立即反映更改
        emit(currentState.copyWith(
          novel: updatedNovel,
          isDirty: true,
        ));
        
        // 保存到服务器
        await repository.updateSummary(
          novelId,
          event.actId,
          event.chapterId,
          event.sceneId,
          event.summary,
        );
        
        // 只更新isDirty标志，保持更新后的novel对象
        emit(currentState.copyWith(
          novel: updatedNovel,
          isDirty: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          errorMessage: '更新场景摘要失败: ${e.toString()}',
        ));
      }
    }
  }

  Future<void> _onAddNewAct(
      AddNewAct event, Emitter<PlanState> emit) async {
    final currentState = state;
    if (currentState is PlanLoaded) {
      try {
        emit(currentState.copyWith(isSaving: true));
        
        // 调用API创建新Act
        final updatedNovel = await repository.addNewAct(
          novelId,
          event.title,
        );
        
        if (updatedNovel == null) {
          emit(currentState.copyWith(
            isSaving: false,
            errorMessage: '添加新Act失败',
          ));
          return;
        }
        
        emit(currentState.copyWith(
          novel: updatedNovel,
          isSaving: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '添加新Act失败: ${e.toString()}',
        ));
      }
    }
  }

  Future<void> _onAddNewChapter(
      AddNewChapter event, Emitter<PlanState> emit) async {
    final currentState = state;
    if (currentState is PlanLoaded) {
      try {
        emit(currentState.copyWith(isSaving: true));
        
        // 调用API创建新Chapter
        final updatedNovel = await repository.addNewChapter(
          novelId,
          event.actId,
          event.title,
        );
        
        if (updatedNovel == null) {
          emit(currentState.copyWith(
            isSaving: false,
            errorMessage: '添加新Chapter失败',
          ));
          return;
        }
        
        emit(currentState.copyWith(
          novel: updatedNovel,
          isSaving: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '添加新Chapter失败: ${e.toString()}',
        ));
      }
    }
  }

  Future<void> _onAddNewScene(
      AddNewScene event, Emitter<PlanState> emit) async {
    final currentState = state;
    if (currentState is PlanLoaded) {
      try {
        emit(currentState.copyWith(isSaving: true));
        
        // 调用API创建新Scene
        final updatedNovel = await repository.addNewScene(
          novelId,
          event.actId,
          event.chapterId,
        );
        
        if (updatedNovel == null) {
          emit(currentState.copyWith(
            isSaving: false,
            errorMessage: '添加新Scene失败',
          ));
          return;
        }
        
        emit(currentState.copyWith(
          novel: updatedNovel,
          isSaving: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '添加新Scene失败: ${e.toString()}',
        ));
      }
    }
  }

  Future<void> _onMoveScene(
      MoveScene event, Emitter<PlanState> emit) async {
    final currentState = state;
    if (currentState is PlanLoaded) {
      try {
        emit(currentState.copyWith(isSaving: true));
        
        // 调用API移动Scene
        final updatedNovel = await repository.moveScene(
          novelId,
          event.sourceActId,
          event.sourceChapterId,
          event.sourceSceneId,
          event.targetActId,
          event.targetChapterId,
          event.targetIndex,
        );
        
        if (updatedNovel == null) {
          emit(currentState.copyWith(
            isSaving: false,
            errorMessage: '移动场景失败',
          ));
          return;
        }
        
        emit(currentState.copyWith(
          novel: updatedNovel,
          isSaving: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '移动场景失败: ${e.toString()}',
        ));
      }
    }
  }

  Future<void> _onDeleteScene(
      DeleteScene event, Emitter<PlanState> emit) async {
    final currentState = state;
    if (currentState is PlanLoaded) {
      try {
        emit(currentState.copyWith(isSaving: true));
        
        // 调用API删除场景
        final success = await repository.deleteScene(
          novelId,
          event.actId,
          event.chapterId,
          event.sceneId,
        );
        
        if (!success) {
          emit(currentState.copyWith(
            isSaving: false,
            errorMessage: '删除场景失败',
          ));
          return;
        }
        
        // 从小说结构中删除场景
        final updatedActs = currentState.novel.acts.map((act) {
          if (act.id == event.actId) {
            final updatedChapters = act.chapters.map((chapter) {
              if (chapter.id == event.chapterId) {
                final updatedScenes = chapter.scenes
                    .where((scene) => scene.id != event.sceneId)
                    .toList();
                return chapter.copyWith(scenes: updatedScenes);
              }
              return chapter;
            }).toList();
            return act.copyWith(chapters: updatedChapters);
          }
          return act;
        }).toList();
        
        final updatedNovel = currentState.novel.copyWith(acts: updatedActs);
        
        emit(currentState.copyWith(
          novel: updatedNovel,
          isSaving: false,
        ));
      } catch (e) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '删除场景失败: ${e.toString()}',
        ));
      }
    }
  }
} 