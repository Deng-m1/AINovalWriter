import 'dart:async';

import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/word_count_analyzer.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'editor_event.dart';
part 'editor_state.dart';

// Bloc实现
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({
    required EditorRepositoryImpl repository,
    required this.novelId,
  })  : repository = repository,
        super(EditorInitial()) {
    on<LoadEditorContent>(_onLoadContent);
    on<UpdateContent>(_onUpdateContent);
    on<SaveContent>(_onSaveContent);
    on<UpdateSceneContent>(_onUpdateSceneContent);
    on<UpdateSummary>(_onUpdateSummary);
    on<ToggleEditorSettings>(_onToggleSettings);
    on<UpdateEditorSettings>(_onUpdateSettings);
    on<SetActiveChapter>(_onSetActiveChapter);
    on<SetActiveScene>(_onSetActiveScene);
    on<UpdateActTitle>(_onUpdateActTitle);
    on<UpdateChapterTitle>(_onUpdateChapterTitle);
    on<AddNewAct>(_onAddNewAct);
    on<AddNewChapter>(_onAddNewChapter);
    on<AddNewScene>(_onAddNewScene);
    on<DeleteScene>(_onDeleteScene);
  }
  final EditorRepositoryImpl repository;
  final String novelId;
  Timer? _autoSaveTimer;
  novel_models.Novel? _novel;
  bool _isDirty = false;
  DateTime? _lastSaveTime;
  final EditorSettings _settings = const EditorSettings();

  Future<void> _onLoadContent(
      LoadEditorContent event, Emitter<EditorState> emit) async {
    emit(EditorLoading());

    try {
      // 获取小说数据
      final novel = await repository.getNovel(novelId);

      if (novel == null) {
        emit(const EditorError(message: '无法加载小说数据'));
        return;
      }

      // 获取编辑器设置
      final settings = await repository.getEditorSettings();

      // 设置默认的活动Act、Chapter和Scene
      String? activeActId;
      String? activeChapterId;
      String? activeSceneId;

      if (novel.acts.isNotEmpty) {
        activeActId = novel.acts.first.id;

        if (novel.acts.first.chapters.isNotEmpty) {
          activeChapterId = novel.acts.first.chapters.first.id;

          if (novel.acts.first.chapters.first.scenes.isNotEmpty) {
            activeSceneId = novel.acts.first.chapters.first.scenes.first.id;
          }
        }
      }

      emit(EditorLoaded(
        novel: novel,
        settings: settings,
        activeActId: activeActId,
        activeChapterId: activeChapterId,
        activeSceneId: activeSceneId,
        isDirty: false,
        isSaving: false,
      ));
    } catch (e) {
      emit(EditorError(message: e.toString()));
    }
  }

  Future<void> _onUpdateContent(
      UpdateContent event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 更新当前活动场景的内容
      if (currentState.activeActId != null &&
          currentState.activeChapterId != null) {
        final updatedNovel = _updateNovelContent(
          currentState.novel,
          currentState.activeActId!,
          currentState.activeChapterId!,
          event.content,
        );

        emit(currentState.copyWith(
          novel: updatedNovel,
          isDirty: true,
        ));
      }
    }
  }

  Future<void> _onSaveContent(
      SaveContent event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded && currentState.isDirty) {
      emit(currentState.copyWith(isSaving: true));

      try {
        // 保存整个小说数据
        await repository.saveNovel(currentState.novel);

        // 如果有活动章节，保存场景内容
        if (currentState.activeActId != null &&
            currentState.activeChapterId != null) {
          try {
            // 获取当前活动场景
            final act = currentState.novel.acts.firstWhere(
              (act) => act.id == currentState.activeActId,
            );
            final chapter = act.chapters.firstWhere(
              (chapter) => chapter.id == currentState.activeChapterId,
            );

            // 获取当前活动场景
            if (chapter.scenes.isEmpty) {
              AppLogger.i('Blocs/editor/editor_bloc', '章节没有场景，无法保存');
              return;
            }

            // 查找当前活动场景
            final scene = chapter.scenes.firstWhere(
              (s) => s.id == currentState.activeSceneId,
              orElse: () => chapter.scenes.first,
            );

            // 计算字数
            final wordCount = WordCountAnalyzer.countWords(scene.content);

            // 保存场景内容
            final updatedScene = await repository.saveSceneContent(
              currentState.novel.id,
              currentState.activeActId!,
              currentState.activeChapterId!,
              currentState.activeSceneId!,
              scene.content,
              wordCount.toString(),
              scene.summary,
            );

            // 更新小说数据
            final updatedNovel = _updateNovelScene(
              currentState.novel,
              currentState.activeActId!,
              currentState.activeChapterId!,
              updatedScene,
            );

            emit(currentState.copyWith(
              novel: updatedNovel,
              isDirty: false,
              isSaving: false,
              lastSaveTime: DateTime.now(),
            ));
          } catch (e) {
            AppLogger.e('Blocs/editor/editor_bloc', '保存场景内容失败', e);
            // 即使场景保存失败，也标记为已保存
            emit(currentState.copyWith(
              isDirty: false,
              isSaving: false,
              lastSaveTime: DateTime.now(),
            ));
          }
        } else {
          // 没有活动章节，只保存小说数据
          emit(currentState.copyWith(
            isDirty: false,
            isSaving: false,
            lastSaveTime: DateTime.now(),
          ));
        }
      } catch (e) {
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onUpdateSceneContent(
      UpdateSceneContent event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 记录输入的字数
      AppLogger.i('EditorBloc',
          '接收到场景内容更新 - 场景ID: ${event.sceneId}, 字数: ${event.wordCount}');

      // 立即将状态设为正在保存
      emit(currentState.copyWith(
        isSaving: true,
      ));

      // 更新指定场景的内容
      final updatedNovel = _updateSceneContent(
        currentState.novel,
        event.actId,
        event.chapterId,
        event.sceneId,
        event.content,
      );
      try {
        // 使用传递的字数或重新计算
        final wordCount = event.wordCount ??
            WordCountAnalyzer.countWords(event.content).toString();

        // 获取当前场景和章节
        final act = updatedNovel.acts.firstWhere((a) => a.id == event.actId);
        final chapter = act.chapters.firstWhere((c) => c.id == event.chapterId);
        final sceneSummary =
            chapter.scenes.firstWhere((s) => s.id == event.sceneId).summary;

        // 保存场景内容
        final updatedScene = await repository.saveSceneContent(
          event.novelId,
          event.actId,
          event.chapterId,
          event.sceneId,
          event.content,
          wordCount,
          sceneSummary,
        );

        // 更新小说数据
        final finalNovel = _updateNovelScene(
          updatedNovel,
          event.actId,
          event.chapterId,
          updatedScene,
        );

        // 保存成功后，更新状态为已保存
        AppLogger.i('EditorBloc',
            '场景保存成功，更新状态 - 场景ID: ${event.sceneId}, 最终字数: ${updatedScene.wordCount}');
        emit(currentState.copyWith(
          novel: finalNovel,
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
        ));
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '保存场景内容失败', e);
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onUpdateSummary(
      UpdateSummary event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 更新指定场景的摘要
      final updatedNovel = _updateSummaryContent(
        currentState.novel,
        event.actId,
        event.chapterId,
        event.sceneId,
        event.summary,
      );

      // 如果不需要重建UI，只更新内部状态，不触发emit
      if (!event.shouldRebuild) {
        _novel = updatedNovel;
        _isDirty = true;

        // 保存摘要，但不触发UI更新
        try {
          final updatedSummary = await repository.saveSummary(
            event.novelId,
            event.actId,
            event.chapterId,
            event.sceneId,
            event.summary,
          );

          // 更新小说数据
          final act = updatedNovel.acts.firstWhere((a) => a.id == event.actId);
          final chapter =
              act.chapters.firstWhere((c) => c.id == event.chapterId);

          // 查找当前活动场景
          final sceneIndex =
              chapter.scenes.indexWhere((s) => s.id == event.sceneId);
          if (sceneIndex < 0) {
            throw Exception('场景不存在');
          }

          // 更新场景
          final updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
          updatedScenes[sceneIndex] =
              updatedScenes[sceneIndex].copyWith(summary: updatedSummary);

          // 更新章节
          final updatedChapter = chapter.copyWith(scenes: updatedScenes);

          // 更新Act
          final updatedActs = updatedNovel.acts.map((a) {
            if (a.id == event.actId) {
              final updatedChapters = a.chapters.map((c) {
                if (c.id == event.chapterId) {
                  return updatedChapter;
                }
                return c;
              }).toList();
              return a.copyWith(chapters: updatedChapters);
            }
            return a;
          }).toList();

          // 更新小说
          _novel = updatedNovel.copyWith(acts: updatedActs);
          _isDirty = false;
          _lastSaveTime = DateTime.now();
        } catch (e) {
          AppLogger.e('Blocs/editor/editor_bloc', '保存摘要失败', e);
        }
        return;
      }

      // 需要重建UI的情况
      // 设置为脏状态
      emit(currentState.copyWith(
        novel: updatedNovel,
        isDirty: true,
        isSaving: true,
      ));

      // 保存摘要
      try {
        final updatedSummary = await repository.saveSummary(
          event.novelId,
          event.actId,
          event.chapterId,
          event.sceneId,
          event.summary,
        );

        // 更新小说数据
        final act = updatedNovel.acts.firstWhere((a) => a.id == event.actId);
        final chapter = act.chapters.firstWhere((c) => c.id == event.chapterId);

        // 查找当前活动场景
        final sceneIndex =
            chapter.scenes.indexWhere((s) => s.id == event.sceneId);
        if (sceneIndex < 0) {
          throw Exception('场景不存在');
        }

        // 更新场景
        final updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
        updatedScenes[sceneIndex] =
            updatedScenes[sceneIndex].copyWith(summary: updatedSummary);

        // 更新章节
        final updatedChapter = chapter.copyWith(scenes: updatedScenes);

        // 更新Act
        final updatedActs = updatedNovel.acts.map((a) {
          if (a.id == event.actId) {
            final updatedChapters = a.chapters.map((c) {
              if (c.id == event.chapterId) {
                return updatedChapter;
              }
              return c;
            }).toList();
            return a.copyWith(chapters: updatedChapters);
          }
          return a;
        }).toList();

        // 更新小说
        final finalNovel = updatedNovel.copyWith(
          acts: updatedActs,
          updatedAt: DateTime.now(),
        );

        // 保存成功后，更新状态为已保存
        emit((state as EditorLoaded).copyWith(
          novel: finalNovel,
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
        ));
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '保存摘要失败', e);
        emit((state as EditorLoaded).copyWith(
          isSaving: false,
        ));
      }
    }
  }

  Future<void> _onToggleSettings(
      ToggleEditorSettings event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(EditorSettingsOpen(
        settings: currentState.settings,
        novel: currentState.novel,
        activeActId: currentState.activeActId,
        activeChapterId: currentState.activeChapterId,
        isDirty: currentState.isDirty,
      ));
    } else if (currentState is EditorSettingsOpen) {
      emit(EditorLoaded(
        novel: currentState.novel,
        settings: currentState.settings,
        activeActId: currentState.activeActId,
        activeChapterId: currentState.activeChapterId,
        isDirty: currentState.isDirty,
        isSaving: false,
      ));
    }
  }

  Future<void> _onUpdateSettings(
      UpdateEditorSettings event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorSettingsOpen) {
      final updatedSettings = {...currentState.settings, ...event.settings};

      try {
        await repository.saveEditorSettings(updatedSettings);

        emit(currentState.copyWith(
          settings: updatedSettings,
        ));
      } catch (e) {
        emit(EditorError(message: e.toString()));
      }
    }
  }

  // 处理设置活动章节事件
  Future<void> _onSetActiveChapter(
      SetActiveChapter event, Emitter<EditorState> emit) async {
    AppLogger.i('Blocs/editor/editor_bloc',
        '设置活动章节: actId=${event.actId}, chapterId=${event.chapterId}');
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(currentState.copyWith(
        activeActId: event.actId,
        activeChapterId: event.chapterId,
      ));
    }
  }

  // 处理设置活动场景事件
  Future<void> _onSetActiveScene(
      SetActiveScene event, Emitter<EditorState> emit) async {
    AppLogger.i('Blocs/editor/editor_bloc',
        '设置活动场景: actId=${event.actId}, chapterId=${event.chapterId}, sceneId=${event.sceneId}');
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(currentState.copyWith(
        activeActId: event.actId,
        activeChapterId: event.chapterId,
        activeSceneId: event.sceneId,
      ));
    }
  }

  // 处理更新Act标题事件
  Future<void> _onUpdateActTitle(
      UpdateActTitle event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 保存原始小说数据，以便在失败时恢复
      final originalNovel = currentState.novel;

      // 更新小说数据
      final updatedNovel =
          _updateActTitle(originalNovel, event.actId, event.title);

      // 设置为脏状态，开始保存
      emit(currentState.copyWith(
        novel: updatedNovel,
        isDirty: true,
        isSaving: true,
      ));

      // 立即保存到本地存储
      try {
        await repository.saveNovel(updatedNovel);

        // 保存成功后，更新状态为已保存
        emit((state as EditorLoaded).copyWith(
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
        ));

        AppLogger.i('Blocs/editor/editor_bloc', 'Act标题保存成功: ${event.title}');
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '保存Act标题失败', e);

        // 保存失败，恢复原始数据
        emit((state as EditorLoaded).copyWith(
          novel: originalNovel,
          isSaving: false,
          errorMessage: '标题保存失败，请重试',
        ));
      }
    }
  }

  // 处理更新Chapter标题事件
  Future<void> _onUpdateChapterTitle(
      UpdateChapterTitle event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 保存原始小说数据，以便在失败时恢复
      final originalNovel = currentState.novel;

      // 更新小说数据
      final updatedNovel = _updateChapterTitle(
          originalNovel, event.actId, event.chapterId, event.title);

      // 设置为脏状态，开始保存
      emit(currentState.copyWith(
        novel: updatedNovel,
        isDirty: true,
        isSaving: true,
      ));

      // 立即保存到本地存储
      try {
        await repository.saveNovel(updatedNovel);

        // 保存成功后，更新状态为已保存
        emit((state as EditorLoaded).copyWith(
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
        ));

        AppLogger.i(
            'Blocs/editor/editor_bloc', 'Chapter标题保存成功: ${event.title}');
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '保存Chapter标题失败', e);

        // 保存失败，恢复原始数据
        emit((state as EditorLoaded).copyWith(
          novel: originalNovel,
          isSaving: false,
          errorMessage: '标题保存失败，请重试',
        ));
      }
    }
  }

  // 辅助方法：更新小说内容
  novel_models.Novel _updateNovelContent(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    String content,
  ) {
    final acts = novel.acts.map((act) {
      if (act.id == actId) {
        final chapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            if (chapter.scenes.isEmpty) {
              return chapter;
            }

            // 更新第一个场景的内容
            final updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
            updatedScenes[0] = updatedScenes[0].copyWith(
              content: content,
            );

            return chapter.copyWith(scenes: updatedScenes);
          }
          return chapter;
        }).toList();

        return act.copyWith(chapters: chapters);
      }
      return act;
    }).toList();

    return novel.copyWith(
      acts: acts,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新小说中指定场景
  novel_models.Novel _updateNovelScene(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    novel_models.Scene updatedScene,
  ) {
    AppLogger.i('EditorBloc/_updateNovelScene',
        '更新小说中的场景: actId=$actId, chapterId=$chapterId, sceneId=${updatedScene.id}, 字数=${updatedScene.wordCount}');

    final updatedActs = novel.acts.map((act) {
      if (act.id == actId) {
        final updatedChapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            final sceneIndex = chapter.scenes
                .indexWhere((scene) => scene.id == updatedScene.id);
            if (sceneIndex >= 0) {
              // 更新已有场景
              final updatedScenes =
                  List<novel_models.Scene>.from(chapter.scenes);
              updatedScenes[sceneIndex] = updatedScene;

              // 日志记录场景字数变化
              final oldWordCount = chapter.scenes[sceneIndex].wordCount;
              final newWordCount = updatedScene.wordCount;
              AppLogger.d('EditorBloc/_updateNovelScene',
                  '场景字数变化: ${updatedScene.id} - 从 $oldWordCount 变为 $newWordCount');

              return chapter.copyWith(scenes: updatedScenes);
            } else {
              // 添加新场景
              AppLogger.d('EditorBloc/_updateNovelScene',
                  '添加新场景: ${updatedScene.id}, 字数=${updatedScene.wordCount}');
              return chapter.copyWith(
                scenes: [...chapter.scenes, updatedScene],
              );
            }
          }
          return chapter;
        }).toList();
        return act.copyWith(chapters: updatedChapters);
      }
      return act;
    }).toList();

    final updatedNovel = novel.copyWith(
      acts: updatedActs,
      updatedAt: DateTime.now(),
    );

    // 记录更新后的总字数
    AppLogger.i(
        'EditorBloc/_updateNovelScene', '更新后小说总字数: ${updatedNovel.wordCount}');

    return updatedNovel;
  }

  // 辅助方法：更新小说场景内容
  novel_models.Novel _updateSceneContent(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    String sceneId,
    String content,
  ) {
    final acts = novel.acts.map((act) {
      if (act.id == actId) {
        final chapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            // 查找当前活动场景
            final sceneIndex =
                chapter.scenes.indexWhere((s) => s.id == sceneId);
            if (sceneIndex < 0) {
              // 如果找不到场景，不做任何修改
              return chapter;
            }

            // 更新场景
            final updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
            updatedScenes[sceneIndex] = updatedScenes[sceneIndex].copyWith(
              content: content,
            );

            return chapter.copyWith(scenes: updatedScenes);
          }
          return chapter;
        }).toList();

        return act.copyWith(chapters: chapters);
      }
      return act;
    }).toList();

    return novel.copyWith(
      acts: acts,
      updatedAt: DateTime.now(),
    );
  }

  // 辅助方法：更新小说摘要
  novel_models.Novel _updateSummaryContent(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    String sceneId,
    String summaryContent,
  ) {
    final acts = novel.acts.map((act) {
      if (act.id == actId) {
        final chapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            // 查找当前活动场景
            final sceneIndex =
                chapter.scenes.indexWhere((s) => s.id == sceneId);
            if (sceneIndex < 0) {
              // 如果找不到场景，不做任何修改
              return chapter;
            }

            // 更新摘要
            final updatedSummary = chapter.scenes[sceneIndex].summary.copyWith(
              content: summaryContent,
            );

            // 更新场景
            final updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
            updatedScenes[sceneIndex] = updatedScenes[sceneIndex].copyWith(
              summary: updatedSummary,
            );

            return chapter.copyWith(scenes: updatedScenes);
          }
          return chapter;
        }).toList();

        return act.copyWith(chapters: chapters);
      }
      return act;
    }).toList();

    return novel.copyWith(
      acts: acts,
      updatedAt: DateTime.now(),
    );
  }

  // 辅助方法：更新Act标题
  novel_models.Novel _updateActTitle(
    novel_models.Novel novel,
    String actId,
    String title,
  ) {
    final acts = novel.acts.map((act) {
      if (act.id == actId) {
        return act.copyWith(title: title);
      }
      return act;
    }).toList();

    return novel.copyWith(
      acts: acts,
      updatedAt: DateTime.now(),
    );
  }

  // 辅助方法：更新Chapter标题
  novel_models.Novel _updateChapterTitle(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    String title,
  ) {
    final acts = novel.acts.map((act) {
      if (act.id == actId) {
        final chapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            return chapter.copyWith(title: title);
          }
          return chapter;
        }).toList();

        return act.copyWith(chapters: chapters);
      }
      return act;
    }).toList();

    return novel.copyWith(
      acts: acts,
      updatedAt: DateTime.now(),
    );
  }

  // 启动自动保存计时器
  void _startAutoSaveTimer() {
    _isDirty = true;

    // 取消现有计时器
    _autoSaveTimer?.cancel();

    // 创建新计时器，3秒后自动保存
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      add(const SaveContent());
      _autoSaveTimer = null;
    });
  }

  // 处理添加新Act事件
  Future<void> _onAddNewAct(AddNewAct event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 保存原始小说数据，以便在失败时恢复
      final originalNovel = currentState.novel;

      // 使用Novel模型的addAct方法添加新Act
      final updatedNovel = originalNovel.addAct(event.title);

      // 设置为脏状态，开始保存
      emit(currentState.copyWith(
        novel: updatedNovel,
        isDirty: true,
        isSaving: true,
      ));

      // 立即保存到本地存储
      try {
        // 保存整个小说数据
        await repository.saveNovel(updatedNovel);

        // 获取新创建的Act
        final newAct = updatedNovel.acts.last;

        // 保存成功后，更新状态为已保存
        emit((state as EditorLoaded).copyWith(
          novel: updatedNovel,
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
          // 设置新创建的Act为活动Act，并将 Chapter 和 Scene 设为 null
          activeActId: newAct.id,
          activeChapterId: null,
          activeSceneId: null,
        ));

        AppLogger.i('Blocs/editor/editor_bloc',
            '新Act添加成功: ${event.title}, ID: ${newAct.id}');
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '添加新Act失败', e);

        // 保存失败，恢复原始数据
        emit((state as EditorLoaded).copyWith(
          novel: originalNovel,
          isSaving: false,
          errorMessage: '添加新Act失败，请重试',
        ));
      }
    }
  }

  // 处理添加新Chapter事件
  Future<void> _onAddNewChapter(
      AddNewChapter event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 保存原始小说数据，以便在失败时恢复
      final originalNovel = currentState.novel;

      // 查找对应的Act
      final actIndex =
          originalNovel.acts.indexWhere((act) => act.id == event.actId);
      if (actIndex == -1) {
        emit(currentState.copyWith(errorMessage: '找不到指定的Act'));
        return;
      }

      // 获取Act并添加新Chapter
      final act = originalNovel.acts[actIndex];
      final updatedAct = act.addChapter(event.title);

      // 获取新创建的Chapter
      final newChapter = updatedAct.chapters.last;

      // 获取新章节的第一个场景 (addChapter 应该创建了一个)
      final newScene =
          newChapter.scenes.isNotEmpty ? newChapter.scenes.first : null;

      final updatedActs = List<novel_models.Act>.from(originalNovel.acts);
      updatedActs[actIndex] = updatedAct;
      final updatedNovel = originalNovel.copyWith(
        acts: updatedActs,
        updatedAt: DateTime.now(),
      );

      emit(currentState.copyWith(
        novel: updatedNovel,
        isDirty: true,
        isSaving: true,
      ));

      try {
        await repository.saveNovel(updatedNovel);

        // 保存新场景内容 (如果存在)
        if (newScene != null) {
          final wordCount = WordCountAnalyzer.countWords(newScene.content);
          await repository.saveSceneContent(
            event.novelId,
            event.actId,
            newChapter.id,
            newScene.id, // 使用新场景的 ID
            newScene.content,
            wordCount.toString(),
            newScene.summary,
          );
        } else {
          AppLogger.w('Blocs/editor/editor_bloc',
              '新章节 ${newChapter.id} 没有默认场景，无法保存场景内容');
        }

        // 保存成功后，更新状态为已保存
        emit((state as EditorLoaded).copyWith(
          novel: updatedNovel,
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
          // 设置新创建的Chapter和Scene为活动项
          activeActId: event.actId,
          activeChapterId: newChapter.id,
          activeSceneId: newScene?.id,
        ));

        AppLogger.i('Blocs/editor/editor_bloc',
            '新Chapter添加成功: ${event.title}, ID: ${newChapter.id}, Active Scene: ${newScene?.id}');
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '添加新Chapter失败', e);
        emit((state as EditorLoaded).copyWith(
          novel: originalNovel,
          isSaving: false,
          errorMessage: '添加新Chapter失败，请重试',
        ));
      }
    }
  }

  // 处理添加新Scene事件
  Future<void> _onAddNewScene(
      AddNewScene event, Emitter<EditorState> emit) async {
    AppLogger.i('Blocs/editor/editor_bloc',
        '开始处理添加新Scene事件: actId=${event.actId}, chapterId=${event.chapterId}');
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 获取当前小说
      final novel = currentState.novel;
      AppLogger.i('Blocs/editor/editor_bloc',
          '当前小说: id=${novel.id}, title=${novel.title}, acts数量=${novel.acts.length}');

      // 查找对应的Act和Chapter
      final act = novel.getAct(event.actId);
      if (act == null) {
        AppLogger.e('Blocs/editor/editor_bloc',
            '找不到指定的Act: ${event.actId}'); // 使用 Error 级别
        // 保持当前状态，但显示错误信息
        emit(currentState.copyWith(errorMessage: '找不到指定的Act'));
        return;
      }

      final chapter = act.getChapter(event.chapterId);
      if (chapter == null) {
        AppLogger.e('Blocs/editor/editor_bloc',
            '找不到指定的Chapter: ${event.chapterId}'); // 使用 Error 级别
        // 保持当前状态，但显示错误信息
        emit(currentState.copyWith(errorMessage: '找不到指定的Chapter'));
        return;
      }

      // 创建一个临时的 saving 状态变量，用于最终的 emit
      bool wasSaving = true; // 开始时假设我们在保存

      try {
        // 1. 创建新场景实体
        AppLogger.i('Blocs/editor/editor_bloc', '创建新场景实体');
        final sceneId = event.sceneId;
        // 使用 Scene.createDefault 来创建，它现在应该包含正确的空内容 JSON
        final newScene = novel_models.Scene.createDefault(sceneId);
        // 确保摘要内容为空，如果 createDefault 没有处理的话
        final summary = newScene.summary.copyWith(content: ''); // 显式设置为空

        final finalNewScene = newScene.copyWith(summary: summary); // 使用更新后的摘要

        // 2. 更新本地小说模型，使用不可变方式
        final updatedScenes = List<novel_models.Scene>.from(chapter.scenes)
          ..add(finalNewScene);
        final updatedChapter = chapter.copyWith(scenes: updatedScenes);
        final chapterIndex =
            act.chapters.indexWhere((c) => c.id == event.chapterId);
        final updatedChapters = List<novel_models.Chapter>.from(act.chapters);
        if (chapterIndex != -1) {
          updatedChapters[chapterIndex] = updatedChapter;
        } else {
          // 理论上不应该发生，因为前面检查过 chapter 存在
          AppLogger.e('Blocs/editor/editor_bloc', '内部错误：找不到 Chapter Index');
          emit(currentState.copyWith(errorMessage: '内部错误，无法更新章节'));
          return;
        }
        final updatedAct = act.copyWith(chapters: updatedChapters);
        final actIndex = novel.acts.indexWhere((a) => a.id == event.actId);
        final updatedActs = List<novel_models.Act>.from(novel.acts);
        if (actIndex != -1) {
          updatedActs[actIndex] = updatedAct;
        } else {
          // 理论上不应该发生
          AppLogger.e('Blocs/editor/editor_bloc', '内部错误：找不到 Act Index');
          emit(currentState.copyWith(errorMessage: '内部错误，无法更新剧本'));
          return;
        }
        final updatedNovel = novel.copyWith(
          acts: updatedActs,
          updatedAt: DateTime.now(),
        );

        // 3. 直接使用repository保存到本地和远程
        final saveResult = await repository.saveNovel(updatedNovel);

        if (saveResult) {
          // 保存场景内容
          try {
            // 使用 finalNewScene 的内容和摘要
            await repository.saveSceneContent(
              event.novelId,
              event.actId,
              event.chapterId,
              sceneId,
              finalNewScene.content, // 使用创建时的默认内容
              '0', // 初始字数为0
              finalNewScene.summary, // 使用创建时的摘要
            );

            // 操作成功完成
            wasSaving = false; // 标记保存已结束
            // 更新UI状态 - 只 emit 一次最终状态
            emit(currentState.copyWith(
              novel: updatedNovel,
              isDirty: false,
              isSaving: false, // 明确设为 false
              lastSaveTime: DateTime.now(),
              // 设置新创建的Scene为活动Scene
              activeActId: event.actId,
              activeChapterId: event.chapterId,
              activeSceneId: sceneId,
              errorMessage: null, // 清除之前的错误信息（如果有）
            ));

            AppLogger.i(
                'Blocs/editor/editor_bloc', '新Scene添加成功并已保存, ID: $sceneId');
          } catch (e, stackTrace) {
            // 添加 stackTrace
            // 保存场景内容失败
            AppLogger.e(
                'Blocs/editor/editor_bloc', '保存场景内容失败', e, stackTrace); // 记录堆栈
            wasSaving = false; // 标记保存已结束（虽然失败了）
            emit(currentState.copyWith(
              novel: updatedNovel, // 仍然更新模型，因为小说结构已保存
              isDirty: false, // 结构已保存，内容未保存，是否算 dirty？取决于业务逻辑，暂时设为 false
              isSaving: false, // 明确设为 false
              lastSaveTime: currentState.lastSaveTime, // 保留上次成功保存的时间
              errorMessage: '场景结构已保存，但内容保存失败: ${e.toString()}',
              // 保持活动场景为新场景，让用户看到它
              activeActId: event.actId,
              activeChapterId: event.chapterId,
              activeSceneId: sceneId,
            ));
          }
        } else {
          // 保存小说失败
          wasSaving = false; // 标记保存已结束
          AppLogger.e('Blocs/editor/editor_bloc', '保存小说结构失败');
          emit(currentState.copyWith(
            isSaving: false, // 明确设为 false
            errorMessage: '保存小说结构失败',
            // 保持旧的小说状态？或者让用户知道失败了但UI已更新？这里保持UI更新，但提示错误
            novel: updatedNovel,
            activeActId: event.actId,
            activeChapterId: event.chapterId,
            activeSceneId: sceneId, // 尝试让用户看到新场景，即使保存失败
          ));
        }
      } catch (e, stackTrace) {
        // 添加 stackTrace
        // 创建场景或更新模型失败
        wasSaving = false; // 标记保存已结束
        AppLogger.e('Blocs/editor/editor_bloc', '添加新Scene或更新模型时出错', e,
            stackTrace); // 记录堆栈
        emit(currentState.copyWith(
          isSaving: false, // 明确设为 false
          errorMessage: '添加新场景失败: ${e.toString()}',
        ));
      }
    }
  }

  // 处理删除场景事件
  Future<void> _onDeleteScene(
      DeleteScene event, Emitter<EditorState> emit) async {
    AppLogger.i('Blocs/editor/editor_bloc',
        '开始处理删除Scene事件: actId=${event.actId}, chapterId=${event.chapterId}, sceneId=${event.sceneId}');
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 保存原始小说数据，以便在失败时恢复
      final originalNovel = currentState.novel;

      try {
        // 1. 查找 Act, Chapter, Scene Index
        final actIndex =
            originalNovel.acts.indexWhere((a) => a.id == event.actId);
        if (actIndex == -1) throw Exception('找不到指定的 Act: ${event.actId}');
        final act = originalNovel.acts[actIndex];

        final chapterIndex =
            act.chapters.indexWhere((c) => c.id == event.chapterId);
        if (chapterIndex == -1) {
          throw Exception('找不到指定的 Chapter: ${event.chapterId}');
        }
        final chapter = act.chapters[chapterIndex];

        final sceneIndex =
            chapter.scenes.indexWhere((s) => s.id == event.sceneId);
        if (sceneIndex == -1) throw Exception('找不到指定的 Scene: ${event.sceneId}');

        // 确定删除后的下一个活动 Scene ID
        String? nextActiveSceneId;
        if (chapter.scenes.length > 1) {
          // 如果删除后还有其他场景
          if (sceneIndex > 0) {
            // 优先选前一个
            nextActiveSceneId = chapter.scenes[sceneIndex - 1].id;
          } else {
            // 否则选后一个 (现在是索引 1)
            nextActiveSceneId = chapter.scenes[1].id;
          }
        } else {
          // 删除后章节为空
          nextActiveSceneId = null;
        }

        // 2. 更新本地小说模型 (不可变方式)
        final updatedScenes = List<novel_models.Scene>.from(chapter.scenes)
          ..removeAt(sceneIndex);
        final updatedChapter = chapter.copyWith(scenes: updatedScenes);
        final updatedChapters = List<novel_models.Chapter>.from(act.chapters)
          ..[chapterIndex] = updatedChapter;
        final updatedAct = act.copyWith(chapters: updatedChapters);
        final updatedActs = List<novel_models.Act>.from(originalNovel.acts)
          ..[actIndex] = updatedAct;
        final updatedNovel = originalNovel.copyWith(
          acts: updatedActs,
          updatedAt: DateTime.now(),
        );

        // 3. 更新UI状态为 "正在保存"
        emit(currentState.copyWith(
          novel: updatedNovel, // 显示删除后的状态
          isDirty: true, // 标记为脏
          isSaving: true, // 标记正在保存
          // 立即更新活动 Scene ID
          activeSceneId: currentState.activeSceneId == event.sceneId
              ? nextActiveSceneId
              : currentState.activeSceneId,
          activeChapterId: nextActiveSceneId != null
              ? event.chapterId
              : currentState.activeChapterId, // 如果章节空了，不改变活动 chapter?
          activeActId: nextActiveSceneId != null
              ? event.actId
              : currentState.activeActId,
        ));

        // 4. 保存更新后的小说数据 (这应该会处理后端删除)
        final saveResult = await repository.saveNovel(updatedNovel);

        if (saveResult) {
          // 5. 保存成功，更新最终状态
          emit((state as EditorLoaded).copyWith(
            isDirty: false,
            isSaving: false,
            lastSaveTime: DateTime.now(),
            errorMessage: null, // 清除错误信息
          ));
          AppLogger.i('Blocs/editor/editor_bloc',
              'Scene 删除成功并已保存, ID: ${event.sceneId}');
        } else {
          // 6. 保存失败
          AppLogger.e('Blocs/editor/editor_bloc', '删除 Scene 后保存小说结构失败');
          // 恢复到原始状态，并显示错误
          emit(currentState.copyWith(
            novel: originalNovel, // 恢复模型
            isDirty: currentState.isDirty, // 恢复原始脏状态
            isSaving: false,
            errorMessage: '删除场景失败，无法保存更改',
            // 活动元素也恢复
            activeActId: currentState.activeActId,
            activeChapterId: currentState.activeChapterId,
            activeSceneId: currentState.activeSceneId,
          ));
        }
      } catch (e, stackTrace) {
        // 捕获查找或更新过程中的错误
        AppLogger.e('Blocs/editor/editor_bloc', '删除场景时出错', e, stackTrace);
        // 恢复到原始状态，并显示错误
        emit(currentState.copyWith(
          novel: originalNovel,
          isDirty: currentState.isDirty,
          isSaving: false,
          errorMessage: '删除场景失败: ${e.toString()}',
          // 活动元素也恢复
          activeActId: currentState.activeActId,
          activeChapterId: currentState.activeChapterId,
          activeSceneId: currentState.activeSceneId,
        ));
      }
    }
  }

  @override
  Future<void> close() {
    _autoSaveTimer?.cancel();
    return super.close();
  }
}
