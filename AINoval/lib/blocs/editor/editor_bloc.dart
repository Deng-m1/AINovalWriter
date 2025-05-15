import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/services/api_service/repositories/impl/editor_repository_impl.dart';
import 'package:ainoval/utils/logger.dart';
import 'package:ainoval/utils/word_count_analyzer.dart';
import 'package:ainoval/utils/quill_helper.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'editor_event.dart';
part 'editor_state.dart';

// Helper class to hold the two maps
class _ChapterMaps {
  final Map<String, int> chapterGlobalIndices;
  final Map<String, String> chapterToActMap;

  _ChapterMaps(this.chapterGlobalIndices, this.chapterToActMap);
}

// Bloc实现
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc({
    required EditorRepositoryImpl repository,
    required this.novelId,
  })  : repository = repository,
        super(EditorInitial()) {
    on<LoadEditorContentPaginated>(_onLoadContentPaginated);
    on<LoadMoreScenes>(_onLoadMoreScenes);
    on<UpdateContent>(_onUpdateContent);
    on<SaveContent>(_onSaveContent);
    on<UpdateSceneContent>(_onUpdateSceneContent);
    on<UpdateSummary>(_onUpdateSummary);
    on<UpdateEditorSettings>(_onUpdateSettings);
    on<SetActiveChapter>(_onSetActiveChapter);
    on<SetActiveScene>(_onSetActiveScene);
    on<SetFocusChapter>(_onSetFocusChapter); // 添加新的事件处理
    on<AddNewScene>(_onAddNewScene);
    on<DeleteScene>(_onDeleteScene);
    on<DeleteChapter>(_onDeleteChapter);
    on<SaveSceneContent>(_onSaveSceneContent);
    on<AddNewAct>(_onAddNewAct);
    on<AddNewChapter>(_onAddNewChapter);
    on<UpdateVisibleRange>(_onUpdateVisibleRange);
    on<ResetActLoadingFlags>(_onResetActLoadingFlags); // 添加新事件处理
    on<SetActLoadingFlags>(_onSetActLoadingFlags); // 添加新的事件处理器
    on<UpdateChapterTitle>(_onUpdateChapterTitle); // 添加Chapter标题更新事件处理
    on<UpdateActTitle>(_onUpdateActTitle); // 添加Act标题更新事件处理
  }
  final EditorRepositoryImpl repository;
  final String novelId;
  Timer? _autoSaveTimer;
  novel_models.Novel? _novel;
  bool _isDirty = false;
  DateTime? _lastSaveTime;
  final EditorSettings _settings = const EditorSettings();
  bool? hasReachedEnd;
  bool? hasReachedStart;

  StreamSubscription<String>? _generationStreamSubscription;

  /// 待保存场景的缓冲队列
  final Map<String, Map<String, dynamic>> _pendingSaveScenes = {};
  /// 上次保存时间映射
  final Map<String, DateTime> _lastSceneSaveTime = {};
  /// 批量保存防抖计时器
  Timer? _batchSaveDebounceTimer;
  /// 批量保存间隔
  static const Duration _batchSaveInterval = Duration(milliseconds: 2000);
  /// 单场景保存防抖间隔
  static const Duration _sceneSaveDebounceInterval = Duration(milliseconds: 800);

  /// 摘要更新防抖控制
  final Map<String, DateTime> _lastSummaryUpdateRequestTime = {};
  static const Duration _summaryUpdateRequestInterval = Duration(milliseconds: 800);

  // Helper method to calculate chapter maps
  _ChapterMaps _calculateChapterMaps(novel_models.Novel novel) {
    final Map<String, int> chapterGlobalIndices = {};
    final Map<String, String> chapterToActMap = {};
    int globalIndex = 0;

    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        chapterGlobalIndices[chapter.id] = globalIndex++;
        chapterToActMap[chapter.id] = act.id;
      }
    }
    return _ChapterMaps(chapterGlobalIndices, chapterToActMap);
  }

  Future<void> _onLoadContentPaginated(
      LoadEditorContentPaginated event, Emitter<EditorState> emit) async {
    emit(EditorLoading());

    try {
      final String lastEditedChapterId = event.lastEditedChapterId ?? '';

      novel_models.Novel? novel = await repository.getNovelWithPaginatedScenes(
        event.novelId,
        lastEditedChapterId,
        chaptersLimit: event.chaptersLimit,
      );

      if (novel == null) {
        emit(const EditorError(message: '无法加载小说数据'));
        return;
      }

      // 从此处开始，novel 不为 null
      if (novel.acts.isEmpty) { 
        AppLogger.i('EditorBloc/_onLoadContentPaginated', '检测到小说 (${novel.id}) 没有卷，尝试自动创建第一卷。');
        try {
          // novel.id 是安全的，因为 novel 在此不为 null
          final novelWithNewAct = await repository.addNewAct(
            novel.id, 
            "第一卷", 
          );
          if (novelWithNewAct != null) {
            novel = novelWithNewAct; // novel 可能被新对象（同样不为null）赋值
            // novel.id 和 novel.acts 在此也是安全的
            AppLogger.i('EditorBloc/_onLoadContentPaginated', '成功为小说 (${novel.id}) 自动创建第一卷。新的卷数量: ${novel.acts.length}');
          } else {
            AppLogger.w('EditorBloc/_onLoadContentPaginated', '为小说 (${novel.id}) 自动创建第一卷失败，repository.addNewAct 返回 null。');
          }
        } catch (e) {
          AppLogger.e('EditorBloc/_onLoadContentPaginated', '为小说 (${novel?.id}) 自动创建第一卷时发生错误。', e);
        }
      }

      final settings = await repository.getEditorSettings();

      String? activeActId;
      // novel 在此不为 null
      String? activeChapterId = novel?.lastEditedChapterId;
      String? activeSceneId;

      if (activeChapterId != null && activeChapterId.isNotEmpty) {
        for (final act_ in novel!.acts) { 
          for (final chapter in act_.chapters) {
            if (chapter.id == activeChapterId) {
              activeActId = act_.id;
              if (chapter.scenes.isNotEmpty) {
                activeSceneId = chapter.scenes.first.id;
              }
              break;
            }
          }
          if (activeActId != null) break;
        }
      }

      if (activeActId == null && novel!.acts.isNotEmpty) {
        activeActId = novel.acts.first.id;
        if (novel.acts.first.chapters.isNotEmpty) {
          activeChapterId = novel.acts.first.chapters.first.id;
          if (novel.acts.first.chapters.first.scenes.isNotEmpty) {
            activeSceneId = novel.acts.first.chapters.first.scenes.first.id;
          }
        } else {
          activeChapterId = null;
          activeSceneId = null;
        }
      }
      
      // novel 在此不为 null，因此 novel! 是安全的
      final chapterMaps = _calculateChapterMaps(novel!);

      emit(EditorLoaded(
        novel: novel,
        settings: settings,
        activeActId: activeActId,
        activeChapterId: activeChapterId,
        activeSceneId: activeSceneId,
        isDirty: false,
        isSaving: false,
        chapterGlobalIndices: chapterMaps.chapterGlobalIndices, // Added
        chapterToActMap: chapterMaps.chapterToActMap, // Added
      ));
    } catch (e) {
      emit(EditorError(message: '加载小说失败: ${e.toString()}'));
    }
  }

  Future<void> _onLoadMoreScenes(
      LoadMoreScenes event, Emitter<EditorState> emit) async {
    if (state is! EditorLoaded) {
      return;
    }

    // 获取当前加载状态
    final currentState = state as EditorLoaded;
    
    // 如果已经在加载中且skipIfLoading为true，则跳过
    if (currentState.isLoading && event.skipIfLoading) {
      AppLogger.d('Blocs/editor/editor_bloc', '加载请求过于频繁，已被节流');
      return;
    }

    // 增强边界检测逻辑，更严格地检查是否已到达边界
    if (event.direction == 'up') {
      if (currentState.hasReachedStart) {
        AppLogger.i('Blocs/editor/editor_bloc', '已到达内容顶部，跳过向上加载请求');
        // 再次明确设置hasReachedStart标志，以防之前的设置未生效
        emit(currentState.copyWith(
          hasReachedStart: true,
        ));
        return;
      }
    } else if (event.direction == 'down') {
      if (currentState.hasReachedEnd) {
        AppLogger.i('Blocs/editor/editor_bloc', '已到达内容底部，跳过向下加载请求');
        // 再次明确设置hasReachedEnd标志，以防之前的设置未生效
        emit(currentState.copyWith(
          hasReachedEnd: true,
        ));
        return;
      }
    }

    // 设置加载状态
    emit(currentState.copyWith(isLoading: true));

    try {
      AppLogger.i('Blocs/editor/editor_bloc', 
          '开始加载更多场景: 卷ID=${event.actId}, 章节ID=${event.fromChapterId}, 方向=${event.direction}, 章节限制=${event.chaptersLimit}, 防止焦点变化=${event.preventFocusChange}');
      
      // 添加超时处理，避免请求无响应
      final completer = Completer<Map<String, List<novel_models.Scene>>?>();
      
      // 使用Future.any同时处理正常结果和超时
      Future.delayed(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          AppLogger.w('Blocs/editor/editor_bloc', '加载请求超时，自动取消');
          completer.complete(null);
        }
      });
      
      // 尝试从本地加载
      if (event.loadFromLocalOnly) {
        AppLogger.i('Blocs/editor/editor_bloc', '尝试仅从本地加载卷 ${event.actId} 章节 ${event.fromChapterId} 的场景');
        // 实现本地加载逻辑
      } else {
        // 从API加载，使用正确的参数格式
        AppLogger.i('Blocs/editor/editor_bloc', '从API加载卷 ${event.actId} 章节 ${event.fromChapterId} 的场景 (方向=${event.direction})');
        
        // 开始API请求但不立即等待
        final futureResult = repository.loadMoreScenes(
          novelId,
          event.actId,
          event.fromChapterId,
          event.direction,
          chaptersLimit: event.chaptersLimit,
        );
        
        // 将API请求结果提交给completer
        futureResult.then((result) {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        }).catchError((e) {
          if (!completer.isCompleted) {
            AppLogger.e('Blocs/editor/editor_bloc', '加载API调用出错', e);
            completer.complete(null);
          }
        });
      }
      
      // 等待结果或超时
      final result = await completer.future;

      // 检查API返回结果
      if (result != null) {
        if (result.isNotEmpty) {
          // 获取当前状态（可能在API请求期间已经发生变化）
          final updatedState = state as EditorLoaded;

          // 合并新场景到小说结构
          final updatedNovel = _mergeNewScenes(updatedState.novel, result);
          
          // 更新活动章节ID（如果需要）
          String? newActiveChapterId = updatedState.activeChapterId;
          String? newActiveSceneId = updatedState.activeSceneId;
          String? newActiveActId = updatedState.activeActId;

          if (!event.preventFocusChange) {
            // 仅当允许改变焦点时才更新活动章节
            final firstChapterId = result.keys.first;
            final firstChapterScenes = result[firstChapterId];
            
            if (firstChapterScenes != null && firstChapterScenes.isNotEmpty) {
              newActiveChapterId = firstChapterId;
              newActiveSceneId = firstChapterScenes.first.id;
              
              // 查找活动章节所属的Act
              for (final act in updatedNovel.acts) {
                for (final chapter in act.chapters) {
                  if (chapter.id == newActiveChapterId) {
                    newActiveActId = act.id;
                    break;
                  }
                }
                if (newActiveActId != null) break;
              }
            }
          }

          // 设置加载边界标志
          bool hasReachedStart = updatedState.hasReachedStart;
          bool hasReachedEnd = updatedState.hasReachedEnd;
          
          // 根据方向和返回结果判断是否达到边界
          // 如果API返回的结果非常少（比如只有1章），可能也意味着接近边界
          if (event.direction == 'up' && result.length <= 1) {
            hasReachedStart = true;
            AppLogger.i('Blocs/editor/editor_bloc', '向上加载返回数据很少，可能已接近顶部，设置hasReachedStart=true');
          } else if (event.direction == 'down' && result.length <= 1) {
            hasReachedEnd = true;
            AppLogger.i('Blocs/editor/editor_bloc', '向下加载返回数据很少，可能已接近底部，设置hasReachedEnd=true');
          }
          
          // Calculate chapter maps for the updated novel
          final chapterMaps = _calculateChapterMaps(updatedNovel);
          
          // 发送更新后的状态
          emit(EditorLoaded(
            novel: updatedNovel,
            settings: updatedState.settings,
            activeActId: newActiveActId,
            activeChapterId: newActiveChapterId,
            activeSceneId: newActiveSceneId,
            isLoading: false,
            hasReachedStart: hasReachedStart,
            hasReachedEnd: hasReachedEnd,
            focusChapterId: updatedState.focusChapterId,
            chapterGlobalIndices: chapterMaps.chapterGlobalIndices, // Added
            chapterToActMap: chapterMaps.chapterToActMap, // Added
          ));
          
          AppLogger.i('Blocs/editor/editor_bloc', '加载更多场景成功，更新了 ${result.length} 个章节');
        } else {
          // API返回空结果，说明该方向没有更多内容了
          // 根据加载方向设置边界标志
          bool hasReachedStart = currentState.hasReachedStart;
          bool hasReachedEnd = currentState.hasReachedEnd;
          
          if (event.direction == 'up') {
            hasReachedStart = true;
            AppLogger.i('Blocs/editor/editor_bloc', '向上没有更多场景可加载，设置hasReachedStart=true');
          } else if (event.direction == 'down') {
            hasReachedEnd = true;
            AppLogger.i('Blocs/editor/editor_bloc', '向下没有更多场景可加载，设置hasReachedEnd=true');
          } else if (event.direction == 'center') {
            // 如果是center方向且返回为空，可能同时到达了顶部和底部
            hasReachedStart = true;
            hasReachedEnd = true;
            AppLogger.i('Blocs/editor/editor_bloc', '中心加载返回为空，设置hasReachedStart=true和hasReachedEnd=true');
          }
          
          // 发送更新状态，包含边界标志
          emit(currentState.copyWith(
            isLoading: false,
            hasReachedStart: hasReachedStart,
            hasReachedEnd: hasReachedEnd,
          ));
          
          AppLogger.i('Blocs/editor/editor_bloc', '没有更多场景可加载，API返回为空');
        }
      } else {
        // API返回null，表示请求失败或超时
        // 这种情况不应标记为已到达边界，因为可能是网络问题
        AppLogger.w('Blocs/editor/editor_bloc', '加载更多场景失败，API返回null');
        emit(currentState.copyWith(
          isLoading: false,
          errorMessage: '加载场景时出现错误，请稍后再试',
        ));
      }
    } catch (e) {
      // 处理异常
      AppLogger.e('Blocs/editor/editor_bloc', '加载更多场景出错', e);
      // 不要在出错时设置边界标志，以免误判
      emit(currentState.copyWith(
        isLoading: false,
        errorMessage: '加载场景时出现错误: ${e.toString()}',
      ));
    }
  }

  // 从本地加载场景数据（不触发网络请求）
  Future<Map<String, List<novel_models.Scene>>> _loadScenesFromLocal(
    String actId,
    String fromChapterId,
    String direction, {
    int chaptersLimit = 3,
  }) async {
    // 获取当前小说结构
    final novel = (state as EditorLoaded).novel;
    
    // 如果指定了actId，则只在该卷内查找章节
    List<novel_models.Chapter> allChapters = [];
    
    if (actId.isNotEmpty) {
      // 指定了actId，只在该卷内加载章节
      for (final act in novel.acts) {
        if (act.id == actId) {
          allChapters.addAll(act.chapters);
          break;
        }
      }
    } else {
      // 未指定actId，收集所有章节
      for (final act in novel.acts) {
        allChapters.addAll(act.chapters);
      }
    }
    
    // 如果找不到章节，返回空结果
    if (allChapters.isEmpty) {
      AppLogger.w('Blocs/editor/editor_bloc', '找不到卷 $actId 的章节，无法从本地加载场景');
      return {};
    }
    
    // 按顺序排序章节
    allChapters.sort((a, b) => a.order.compareTo(b.order));
    
    // 找到目标章节的索引
    final targetIndex = allChapters.indexWhere((chapter) => chapter.id == fromChapterId);
    if (targetIndex == -1) {
      AppLogger.w('Blocs/editor/editor_bloc', '在排序后的章节列表中找不到目标章节 $fromChapterId');
      return {};
    }
    
    // 确定要加载的章节范围
    List<novel_models.Chapter> chaptersToLoad = [];
    
    if (direction == 'up') {
      // 向上加载
      final startIndex = (targetIndex - chaptersLimit).clamp(0, allChapters.length - 1);
      chaptersToLoad = allChapters.sublist(startIndex, targetIndex);
    } else if (direction == 'down') {
      // 向下加载
      final endIndex = (targetIndex + chaptersLimit).clamp(0, allChapters.length - 1);
      chaptersToLoad = allChapters.sublist(targetIndex + 1, endIndex + 1);
    } else { // center
      // 以目标章节为中心加载
      final startIndex = (targetIndex - (chaptersLimit ~/ 2)).clamp(0, allChapters.length - 1);
      final endIndex = (targetIndex + (chaptersLimit ~/ 2)).clamp(0, allChapters.length - 1);
      chaptersToLoad = allChapters.sublist(startIndex, endIndex + 1);
    }
    
    // 创建结果集，保持原始接口返回格式
    final result = <String, List<novel_models.Scene>>{};
    for (final chapter in chaptersToLoad) {
      if (chapter.scenes.isEmpty) {
        // 对于空场景的章节，查询本地存储尝试加载场景
        try {
          final scenes = await repository.getLocalScenesForChapter(novelId, actId, chapter.id);
          if (scenes.isNotEmpty) {
            result[chapter.id] = scenes;
          }
        } catch (e) {
          AppLogger.e('Blocs/editor/editor_bloc', '从本地存储加载章节 ${chapter.id} 的场景失败', e);
        }
      } else {
        // 对于已经有场景的章节，直接加入结果集
        result[chapter.id] = chapter.scenes;
      }
    }
    
    return result;
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

  // 使用防抖动机制将场景加入批量保存队列
  void _enqueueSceneForBatchSave({
    required String novelId,
    required String actId,
    required String chapterId,
    required String sceneId,
    required String content,
    required String wordCount,
  }) {
    // 首先验证章节和场景是否仍然存在
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      
      // 查找章节是否存在
      bool chapterExists = false;
      bool sceneExists = false;

      for (final act in currentState.novel.acts) {
        if (act.id == actId) {
          for (final chapter in act.chapters) {
            if (chapter.id == chapterId) {
              chapterExists = true;
              // 检查场景是否存在
              for (final scene in chapter.scenes) {
                if (scene.id == sceneId) {
                  sceneExists = true;
                  break;
                }
              }
              break;
            }
          }
          break;
        }
      }

      if (!chapterExists) {
        AppLogger.w('EditorBloc', '无法保存场景${sceneId}：章节${chapterId}已不存在，跳过保存');
        return;
      }

      if (!sceneExists) {
        AppLogger.w('EditorBloc', '无法保存场景${sceneId}：场景已不存在，跳过保存');
        return;
      }
    }

    // 生成唯一键
    final sceneKey = '${novelId}_${actId}_${chapterId}_$sceneId';
    
    // 检查时间戳节流
    final now = DateTime.now();
    final lastSaveTime = _lastSceneSaveTime[sceneKey];
    if (lastSaveTime != null && now.difference(lastSaveTime) < _sceneSaveDebounceInterval) {
      AppLogger.d('EditorBloc', '场景${sceneId}的保存请求被节流，忽略此次保存');
      
      // 更新待保存数据，但不触发新的保存计时器
      _pendingSaveScenes[sceneKey] = {
        'novelId': novelId,
        'actId': actId,
        'chapterId': chapterId,
        'sceneId': sceneId,
        'id': sceneId, // 添加id字段，与repository.batchSaveSceneContents期望的格式一致
        'content': _ensureValidQuillJson(content),
        'wordCount': int.tryParse(wordCount) ?? 0, // 转换为整数
        'queuedAt': now,
      };
      return;
    }

    // 加入待保存队列
    _pendingSaveScenes[sceneKey] = {
      'novelId': novelId,
      'actId': actId,
      'chapterId': chapterId,
      'sceneId': sceneId,
      'id': sceneId, // 添加id字段，与repository.batchSaveSceneContents期望的格式一致
      'content': _ensureValidQuillJson(content),
      'wordCount': int.tryParse(wordCount) ?? 0, // 转换为整数
      'queuedAt': now,
    };
    
    AppLogger.i('EditorBloc', '将场景${sceneId}加入批量保存队列，当前队列中有${_pendingSaveScenes.length}个场景');
    
    // 取消现有计时器
    _batchSaveDebounceTimer?.cancel();
    
    // 创建新计时器
    _batchSaveDebounceTimer = Timer(_batchSaveInterval, () {
      _processBatchSaveQueue();
    });
  }
  
  // 确保内容是有效的Quill JSON格式
  String _ensureValidQuillJson(String content) {
    // 直接使用QuillHelper工具类处理内容格式
    return QuillHelper.ensureQuillFormat(content);
  }

  /// 处理批量保存队列
  Future<void> _processBatchSaveQueue() async {
    if (_pendingSaveScenes.isEmpty) return;
    
    AppLogger.i('EditorBloc', '开始处理批量保存队列，共${_pendingSaveScenes.length}个场景');
    
    // 处理前再次验证章节和场景存在性
    if (state is EditorLoaded) {
      final currentState = state as EditorLoaded;
      final novel = currentState.novel;
      
      // 创建需要移除的键列表
      final keysToRemove = <String>[];
      
      // 检查每个待保存场景
      for (final entry in _pendingSaveScenes.entries) {
        final key = entry.key;
        final sceneData = entry.value;
        final String actId = sceneData['actId'] as String;
        final String chapterId = sceneData['chapterId'] as String;
        final String sceneId = sceneData['sceneId'] as String;
        
        // 查找章节和场景是否仍然存在
        bool shouldKeep = false;
        
        for (final act in novel.acts) {
      if (act.id == actId) {
            for (final chapter in act.chapters) {
          if (chapter.id == chapterId) {
                for (final scene in chapter.scenes) {
                  if (scene.id == sceneId) {
                    shouldKeep = true;
                    break;
                  }
                }
                break;
              }
            }
            break;
          }
        }
        
        if (!shouldKeep) {
          keysToRemove.add(key);
          AppLogger.i('EditorBloc', '移除不存在的场景${sceneId}（章节${chapterId}）的保存请求');
        }
      }
      
      // 移除无效条目
      for (final key in keysToRemove) {
        _pendingSaveScenes.remove(key);
      }
      
      // 如果所有条目都被移除，直接返回
      if (_pendingSaveScenes.isEmpty) {
        AppLogger.i('EditorBloc', '批量保存队列为空（所有条目已被移除），跳过保存');
        return;
      }
    }
    
    // 按小说ID分组场景
    final Map<String, List<Map<String, dynamic>>> scenesByNovel = {};
    
    _pendingSaveScenes.forEach((sceneKey, sceneData) {
      final novelId = sceneData['novelId'] as String;
      if (!scenesByNovel.containsKey(novelId)) {
        scenesByNovel[novelId] = [];
      }
      scenesByNovel[novelId]!.add(sceneData);
      
      // 更新最后保存时间
      _lastSceneSaveTime[sceneKey] = DateTime.now();
    });
    
    // 清空待保存队列
    _pendingSaveScenes.clear();
    
    // 按小说批量保存
    for (final entry in scenesByNovel.entries) {
      final novelId = entry.key;
      final scenes = entry.value;
      
      AppLogger.i('EditorBloc', '批量保存小说${novelId}的${scenes.length}个场景');
      
      try {
        // 确保每个场景对象包含所有必要字段
        final List<Map<String, dynamic>> processedScenes = scenes.map((sceneData) {
          // 确保有id字段
          if (sceneData['id'] == null && sceneData['sceneId'] != null) {
            sceneData['id'] = sceneData['sceneId'];
          }
          
          // 移除队列特定的字段
          final processedData = Map<String, dynamic>.from(sceneData);
          processedData.remove('queuedAt'); // 移除仅用于队列的时间戳
          
          // 确保wordCount是整数
          if (processedData['wordCount'] is String) {
            processedData['wordCount'] = int.tryParse(processedData['wordCount']) ?? 0;
          }
          
          return processedData;
        }).toList();
        
        final success = await _batchSaveScenes(processedScenes, novelId);
        if (success) {
          AppLogger.i('EditorBloc', '小说${novelId}的${scenes.length}个场景批量保存成功');
          
          // 更新最后保存时间
          _lastSaveTime = DateTime.now();
          _isDirty = false;
          
          // 如果当前状态是EditorLoaded，更新保存状态
          if (state is EditorLoaded) {
            final currentState = state as EditorLoaded;
            if (currentState.isSaving) {
              emit(currentState.copyWith(
                isSaving: false,
                lastSaveTime: DateTime.now(),
                isDirty: false,
              ));
            }
          }
        } else {
          AppLogger.e('EditorBloc', '小说${novelId}的场景批量保存失败');
        }
      } catch (e) {
        AppLogger.e('EditorBloc', '批量保存出错: $e');
      }
    }
  }

  // 修改现有的_onUpdateSceneContent方法，使用优化的批量保存
  Future<void> _onUpdateSceneContent(
      UpdateSceneContent event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      final isMinorChange = event.isMinorChange ?? false;
      
      // 验证章节和场景是否仍然存在
      bool chapterExists = false;
      bool sceneExists = false;
      
      for (final act in currentState.novel.acts) {
        if (act.id == event.actId) {
          for (final chapter in act.chapters) {
            if (chapter.id == event.chapterId) {
              chapterExists = true;
              
              for (final scene in chapter.scenes) {
                if (scene.id == event.sceneId) {
                  sceneExists = true;
                  break;
                }
              }
              break;
            }
          }
          break;
        }
      }
      
      if (!chapterExists) {
        AppLogger.e('EditorBloc', '更新场景内容失败：找不到指定的Chapter');
        emit(currentState.copyWith(
            isSaving: false,
          errorMessage: '更新场景内容失败：找不到指定的Chapter',
        ));
        return;
      }
      
      if (!sceneExists) {
        AppLogger.e('EditorBloc', '更新场景内容失败：找不到指定的Scene');
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '更新场景内容失败：找不到指定的Scene',
        ));
        return;
      }
      
      // 记录输入的字数
      AppLogger.i('EditorBloc',
          '接收到场景内容更新 - 场景ID: ${event.sceneId}, 字数: ${event.wordCount}, 是否小改动: $isMinorChange');

      // 验证并确保内容是有效的Quill JSON格式
      final String validContent = _ensureValidQuillJson(event.content);

      // 更新指定场景的内容（现在_updateSceneContent会自动更新lastEditedChapterId）
      final updatedNovel = _updateSceneContent(
        currentState.novel,
        event.actId,
        event.chapterId,
          event.sceneId,
        validContent, // 使用验证后的内容
      );

      // 判断是否需要立即更新UI状态
      final bool shouldUpdateUiState = !isMinorChange || !currentState.isSaving;
      
      if (shouldUpdateUiState) {
        // 立即将状态设为正在保存（对于非小改动或当前非保存状态）
      emit(currentState.copyWith(
          novel: updatedNovel,
          isDirty: true,
          isSaving: true,
        ));
                } else {
        // 对于小改动且当前已处于保存状态，仅更新小说数据但不改变UI状态标志
      emit(currentState.copyWith(
          novel: updatedNovel,
          isDirty: true,
        ));
      }

      // 使用传递的字数或重新计算
      final wordCount = event.wordCount ??
          WordCountAnalyzer.countWords(event.content).toString();

      // 将场景加入批量保存队列
      _enqueueSceneForBatchSave(
        novelId: event.novelId,
        actId: event.actId,
        chapterId: event.chapterId,
        sceneId: event.sceneId,
        content: validContent, // 使用验证后的内容
        wordCount: wordCount,
      );
    }
  }

  Future<void> _onUpdateSummary(
      UpdateSummary event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      try {
        // 添加防抖控制 - 使用场景ID作为键
        final String cacheKey = event.sceneId;
        final now = DateTime.now();
        final lastRequestTime = _lastSummaryUpdateRequestTime[cacheKey];
        
        if (lastRequestTime != null && 
            now.difference(lastRequestTime) < _summaryUpdateRequestInterval) {
          AppLogger.i('Blocs/editor/editor_bloc', 
              '摘要更新请求频率过高，跳过此次请求: ${event.sceneId}');
          return;
        }
        
        // 记录本次请求时间
        _lastSummaryUpdateRequestTime[cacheKey] = now;
        
        emit(currentState.copyWith(isSaving: true));
        
        AppLogger.i('Blocs/editor/editor_bloc',
            '更新场景摘要: novelId=${event.novelId}, actId=${event.actId}, chapterId=${event.chapterId}, sceneId=${event.sceneId}');
        
        // 查找场景和对应的摘要
        novel_models.Scene? sceneToUpdate;
        for (final act in currentState.novel.acts) {
          if (act.id == event.actId) {
            for (final chapter in act.chapters) {
              if (chapter.id == event.chapterId) {
                for (final scene in chapter.scenes) {
                  if (scene.id == event.sceneId) {
                    sceneToUpdate = scene;
                    break;
                  }
                }
                break;
              }
            }
            break;
          }
        }
        
        if (sceneToUpdate == null) {
          AppLogger.e('Blocs/editor/editor_bloc',
              '找不到要更新摘要的场景: ${event.sceneId}');
          emit(currentState.copyWith(
            isSaving: false,
            errorMessage: '找不到要更新摘要的场景',
          ));
          return;
        }
        
        // 创建新的摘要对象
        final updatedSummary = novel_models.Summary(
          id: sceneToUpdate.summary.id,
          content: event.summary,
        );
        
        // 使用repository保存摘要
        final success = await repository.updateSummary(
          event.novelId,
          event.actId,
          event.chapterId,
          event.sceneId,
          event.summary,
        );
        
        if (!success) {
          throw Exception('更新摘要失败');
        }
        
        // 创建更新后的场景
        final updatedScene = sceneToUpdate.copyWith(
          summary: updatedSummary,
        );
        
        // 更新小说中的场景
        final updatedNovel = _updateNovelScene(
          currentState.novel,
          event.actId,
          event.chapterId,
          updatedScene,
        );
        
        // 保存成功后，更新状态
        emit(currentState.copyWith(
          novel: updatedNovel,
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
        ));
        
        AppLogger.i('Blocs/editor/editor_bloc',
            '场景摘要更新成功: ${event.sceneId}');
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '更新场景摘要失败', e);
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '更新场景摘要失败: ${e.toString()}',
        ));
      }
    }
  }

  // 辅助方法：查找章节所属的Act ID
  String? _findActIdForChapter(novel_models.Novel novel, String chapterId) {
    for (final act in novel.acts) {
      for (final chapter in act.chapters) {
        if (chapter.id == chapterId) {
          return act.id;
        }
      }
    }
    return null;
  }

  @override
  Future<void> close() {
    _autoSaveTimer?.cancel();
    _generationStreamSubscription?.cancel();
    return super.close();
  }

  // 批量保存多个场景内容的辅助方法
  Future<bool> _batchSaveScenes(List<Map<String, dynamic>> sceneUpdates, String novelId) async {
    if (sceneUpdates.isEmpty) return true;
    
    try {
      // 确保每个场景都有必要的字段
      final processedUpdates = sceneUpdates.map((scene) {
        // 确保每个场景都有novelId
        final updated = Map<String, dynamic>.from(scene);
        updated['novelId'] = novelId;
        
        // 确保每个场景都有chapterId和actId
        if (updated['chapterId'] == null || updated['chapterId'].toString().isEmpty) {
          AppLogger.w('EditorBloc/_batchSaveScenes', '场景缺少chapterId: ${updated['id']}，跳过该场景');
          return null; // 返回null表示这个场景无效
        }
        
        if (updated['actId'] == null || updated['actId'].toString().isEmpty) {
          AppLogger.w('EditorBloc/_batchSaveScenes', '场景缺少actId: ${updated['id']}，跳过该场景');
          return null; // 返回null表示这个场景无效
        }
        
        return updated;
      }).where((scene) => scene != null).cast<Map<String, dynamic>>().toList();
      
      if (processedUpdates.isEmpty) {
        AppLogger.w('EditorBloc/_batchSaveScenes', '处理后没有有效场景可以保存');
        return false;
      }
      
      // 记录一下要发送的数据，便于调试
      AppLogger.i('EditorBloc/_batchSaveScenes', '批量保存${processedUpdates.length}个场景，novelId=${novelId}');
      
      final result = await repository.batchSaveSceneContents(novelId, processedUpdates);
      if (result) {
        AppLogger.i('EditorBloc/_batchSaveScenes', '批量保存场景成功: ${processedUpdates.length}个场景');
      } else {
        AppLogger.e('EditorBloc/_batchSaveScenes', '批量保存场景失败');
      }
      return result;
    } catch (e) {
      AppLogger.e('EditorBloc/_batchSaveScenes', '批量保存场景出错', e);
      return false;
    }
  }

  // 优化的自动保存方法
  void _optimizedAutoSave() {
    // 被修改的内容优先级：场景内容 > 摘要 > 结构 > 元数据
    final currentState = state;
    if (currentState is! EditorLoaded || !_isDirty) return;
    
    // 场景内容和摘要变更时使用批量场景更新
    // 结构变更时使用结构更新
    // 元数据变更时使用元数据更新
    
    Set<String> changedComponents = {};
    
    // 检测变更类型
    if (_novel != null) {
      // 检测元数据变更
      if (_novel!.title != currentState.novel.title || 
          _novel!.author?.username != currentState.novel.author?.username) {
        changedComponents.add('metadata');
      }
      
      // 检测最后编辑章节变更
      if (_novel!.lastEditedChapterId != currentState.novel.lastEditedChapterId) {
        changedComponents.add('lastEditedChapterId');
      }
      
      // 检测Act标题变更
      bool actTitlesChanged = false;
      for (int i = 0; i < _novel!.acts.length && i < currentState.novel.acts.length; i++) {
        if (_novel!.acts[i].title != currentState.novel.acts[i].title) {
          actTitlesChanged = true;
          break;
        }
      }
      if (actTitlesChanged) {
        changedComponents.add('actTitles');
      }
      
      // 检测Chapter标题变更
      bool chapterTitlesChanged = false;
      for (int i = 0; i < _novel!.acts.length && i < currentState.novel.acts.length; i++) {
        final oldAct = currentState.novel.acts[i]; 
        final newAct = _novel!.acts[i];
        
        // 确保不会越界
        if (i < oldAct.chapters.length && i < newAct.chapters.length) {
        for (int j = 0; j < oldAct.chapters.length && j < newAct.chapters.length; j++) {
          if (oldAct.chapters[j].title != newAct.chapters[j].title) {
            chapterTitlesChanged = true;
            break;
            }
          }
        }
        if (chapterTitlesChanged) break;
      }
      if (chapterTitlesChanged) {
        changedComponents.add('chapterTitles');
      }
    }
    
    // 使用智能同步方法，根据变更类型选择最优策略
    repository.smartSyncNovel(_novel ?? currentState.novel, changedComponents: changedComponents)
      .then((success) {
        if (success) {
          _isDirty = false;
          _lastSaveTime = DateTime.now();
          AppLogger.i('EditorBloc/_optimizedAutoSave', '智能同步成功，组件: $changedComponents');
        } else {
          AppLogger.e('EditorBloc/_optimizedAutoSave', '智能同步失败');
        }
      })
      .catchError((e) {
        AppLogger.e('EditorBloc/_optimizedAutoSave', '智能同步出错', e);
      });
  }

  // 将新加载的场景合并到当前小说结构中
  novel_models.Novel _mergeNewScenes(
    novel_models.Novel novel,
    Map<String, List<novel_models.Scene>> newScenes) {
    
    // 创建当前小说acts的深拷贝，以便修改
    final List<novel_models.Act> updatedActs = novel.acts.map((act) {
      // 为每个Act创建深拷贝，以便修改其中的章节
      final List<novel_models.Chapter> updatedChapters = act.chapters.map((chapter) {
        // 检查是否有该章节的新场景
        if (newScenes.containsKey(chapter.id)) {
          // 合并新场景和现有场景
          List<novel_models.Scene> existingScenes = List.from(chapter.scenes);
          List<novel_models.Scene> scenesToAdd = List.from(newScenes[chapter.id]!);
          
          // 创建场景ID到场景的映射，用于快速查找和合并
          Map<String, novel_models.Scene> sceneMap = {};
          for (var scene in existingScenes) {
            sceneMap[scene.id] = scene;
          }
          
          // 合并场景列表，优先使用新加载的场景
          for (var scene in scenesToAdd) {
            sceneMap[scene.id] = scene;
          }
          
          // 将合并后的场景转换回列表
          List<novel_models.Scene> mergedScenes = sceneMap.values.toList();
          
          // 创建更新后的章节
          return chapter.copyWith(scenes: mergedScenes);
        }
        // 如果没有该章节的新场景，则返回原章节
        return chapter;
      }).toList();
      
      // 返回更新后的Act
      return act.copyWith(chapters: updatedChapters);
    }).toList();
    
    // 在返回更新后的小说之前记录一些渲染相关的日志
    AppLogger.i('EditorBloc', '合并了${newScenes.length}个章节的场景，可能需要重新渲染');
    return novel.copyWith(acts: updatedActs);
  }

  // 更新小说内容的辅助方法
  novel_models.Novel _updateNovelContent(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    String content) {
    
    // 创建当前小说acts的深拷贝以便修改
    final List<novel_models.Act> updatedActs = novel.acts.map((act) {
      if (act.id == actId) {
        // 更新指定Act的章节
        final List<novel_models.Chapter> updatedChapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            // 找到指定章节，更新其第一个场景的内容
            if (chapter.scenes.isNotEmpty) {
              final List<novel_models.Scene> updatedScenes = List.from(chapter.scenes);
              final novel_models.Scene firstScene = updatedScenes.first;
              
              // 更新场景内容
              updatedScenes[0] = firstScene.copyWith(
                content: content,
              );
              
              return chapter.copyWith(scenes: updatedScenes);
            }
          }
          return chapter;
        }).toList();
        
        return act.copyWith(chapters: updatedChapters);
      }
      return act;
    }).toList();
    
    // 返回更新后的小说，同时更新最后编辑章节
    return novel.copyWith(
      acts: updatedActs,
      lastEditedChapterId: chapterId,
    );
  }

  // 更新小说场景的辅助方法
  novel_models.Novel _updateNovelScene(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    novel_models.Scene updatedScene) {
    
    // 创建当前小说acts的深拷贝以便修改
    final List<novel_models.Act> updatedActs = novel.acts.map((act) {
      if (act.id == actId) {
        // 更新指定Act的章节
        final List<novel_models.Chapter> updatedChapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            // 找到指定章节，更新其场景
            final List<novel_models.Scene> updatedScenes = chapter.scenes.map((scene) {
              if (scene.id == updatedScene.id) {
                // 返回更新后的场景
                return updatedScene;
              }
              return scene;
            }).toList();
            
            return chapter.copyWith(scenes: updatedScenes);
          }
          return chapter;
        }).toList();
        
        return act.copyWith(chapters: updatedChapters);
      }
      return act;
    }).toList();
    
    // 返回更新后的小说，同时更新最后编辑章节
    return novel.copyWith(
      acts: updatedActs,
      lastEditedChapterId: chapterId,
    );
  }

  // 更新场景内容的辅助方法
  novel_models.Novel _updateSceneContent(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    String sceneId,
    String content) {
    
    // 创建当前小说acts的深拷贝以便修改
    final List<novel_models.Act> updatedActs = novel.acts.map((act) {
      if (act.id == actId) {
        // 更新指定Act的章节
        final List<novel_models.Chapter> updatedChapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            // 找到指定章节，更新其场景
            final List<novel_models.Scene> updatedScenes = chapter.scenes.map((scene) {
              if (scene.id == sceneId) {
                // 更新场景内容
                return scene.copyWith(
                  content: content,
                );
              }
              return scene;
            }).toList();
            
            return chapter.copyWith(scenes: updatedScenes);
          }
          return chapter;
        }).toList();
        
        return act.copyWith(chapters: updatedChapters);
      }
      return act;
    }).toList();
    
    // 返回更新后的小说，同时更新最后编辑章节
    return novel.copyWith(
      acts: updatedActs,
      lastEditedChapterId: chapterId,
    );
  }

  // 设置活动章节
  Future<void> _onSetActiveChapter(
      SetActiveChapter event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 查找章节中的第一个场景作为活动场景
      String? firstSceneId;
      for (final act in currentState.novel.acts) {
        if (act.id == event.actId) {
          for (final chapter in act.chapters) {
            if (chapter.id == event.chapterId && chapter.scenes.isNotEmpty) {
              firstSceneId = chapter.scenes.first.id;
              break;
            }
          }
          break;
        }
      }
      
      // 记录日志
      AppLogger.i('EditorBloc', '设置活动章节: ${event.actId}/${event.chapterId}, 活动场景: $firstSceneId');
      
      emit(currentState.copyWith(
        activeActId: event.actId,
        activeChapterId: event.chapterId,
        activeSceneId: firstSceneId, // 设置为章节的第一个场景或null
      ));
    }
  }

  // 设置活动场景
  Future<void> _onSetActiveScene(
      SetActiveScene event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(currentState.copyWith(
        activeActId: event.actId,
        activeChapterId: event.chapterId,
        activeSceneId: event.sceneId,
      ));
    }
  }

  // 更新编辑器设置
  Future<void> _onUpdateSettings(
      UpdateEditorSettings event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(currentState.copyWith(
        settings: event.settings,
      ));
      
      // 保存设置到本地存储
      try {
        await repository.saveEditorSettings(event.settings);
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '保存编辑器设置失败', e);
      }
    }
  }

  // 删除Scene
  Future<void> _onDeleteScene(
      DeleteScene event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      try {
        emit(currentState.copyWith(isSaving: true));
        
        AppLogger.i('Blocs/editor/editor_bloc',
            '删除场景: novelId=${event.novelId}, actId=${event.actId}, chapterId=${event.chapterId}, sceneId=${event.sceneId}');
        
        // 查找要删除的场景
        novel_models.Scene? sceneToDelete;
        novel_models.Chapter? parentChapter;
        novel_models.Act? parentAct;
        
        for (final act in currentState.novel.acts) {
          if (act.id == event.actId) {
            parentAct = act;
            for (final chapter in act.chapters) {
              if (chapter.id == event.chapterId) {
                parentChapter = chapter;
                for (final scene in chapter.scenes) {
                  if (scene.id == event.sceneId) {
                    sceneToDelete = scene;
                    break;
                  }
                }
                break;
              }
            }
            break;
          }
        }
        
        if (sceneToDelete == null || parentChapter == null || parentAct == null) {
          AppLogger.e('Blocs/editor/editor_bloc',
              '找不到要删除的场景: ${event.sceneId}');
          emit(currentState.copyWith(
            isSaving: false,
            errorMessage: '找不到要删除的场景',
          ));
          return;
        }
        
        // 创建不包含要删除场景的新场景列表
        final updatedScenes = parentChapter.scenes
            .where((scene) => scene.id != event.sceneId)
            .toList();
        
        // 如果该章节没有更多场景，可以考虑提示用户
        final bool isLastSceneInChapter = updatedScenes.isEmpty;
        
        // 更新章节
        final updatedChapter = parentChapter.copyWith(
          scenes: updatedScenes,
        );
        
        // 更新所在Act的章节列表
        final updatedChapters = parentAct.chapters.map((chapter) {
          if (chapter.id == event.chapterId) {
            return updatedChapter;
          }
          return chapter;
        }).toList();
        
        // 更新Act
        final updatedAct = parentAct.copyWith(
          chapters: updatedChapters,
        );
        
        // 更新小说的Acts列表
        final updatedActs = currentState.novel.acts.map((act) {
          if (act.id == event.actId) {
            return updatedAct;
          }
          return act;
        }).toList();
        
        // 创建更新后的小说模型
        final updatedNovel = currentState.novel.copyWith(
          acts: updatedActs,
          updatedAt: DateTime.now(),
        );
        
        // 清除该场景的所有保存请求
        _cleanupPendingSaveForScene(event.sceneId);
        
        // 如果删除的是当前活动场景，确定下一个活动场景
        String? newActiveSceneId = currentState.activeSceneId;
        if (currentState.activeSceneId == event.sceneId) {
          if (updatedScenes.isNotEmpty) {
            // 如果章节还有其他场景，选择第一个
            newActiveSceneId = updatedScenes.first.id;
          } else {
            // 章节没有场景了，将活动场景设为null
            newActiveSceneId = null;
          }
        }
        
        // Calculate chapter maps for the updated novel
        final chapterMaps = _calculateChapterMaps(updatedNovel);

        // 在UI上标记为正在处理
        emit(currentState.copyWith(
          novel: updatedNovel,
          activeSceneId: newActiveSceneId,
          isDirty: true,
          isSaving: true,
          chapterGlobalIndices: chapterMaps.chapterGlobalIndices, // Added
          chapterToActMap: chapterMaps.chapterToActMap, // Added
        ));
        
        // 调用API删除场景
        final success = await repository.deleteScene(
          event.novelId,
          event.actId,
          event.chapterId,
          event.sceneId,
        );
        
        if (!success) {
          throw Exception('删除场景失败');
        }
        
        // 保存成功后，更新状态
        emit(currentState.copyWith(
          novel: updatedNovel,
          activeSceneId: newActiveSceneId,
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
          chapterGlobalIndices: chapterMaps.chapterGlobalIndices, // Ensure maps are consistent
          chapterToActMap: chapterMaps.chapterToActMap,       // Ensure maps are consistent
        ));
        
        AppLogger.i('Blocs/editor/editor_bloc',
            '场景删除成功: ${event.sceneId}');
        
        // 如果删除的是最后一个场景，提示用户考虑添加新场景
        if (isLastSceneInChapter) {
          AppLogger.i('Blocs/editor/editor_bloc',
              '章节 ${event.chapterId} 现在没有场景了');
          // 这里可以添加一些逻辑来提示用户添加场景
        }
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '删除场景失败', e);
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '删除场景失败: ${e.toString()}',
        ));
      }
    }
  }

  // 在场景删除后清理该场景的保存请求
  void _cleanupPendingSaveForScene(String sceneId) {
    final keysToRemove = <String>[];
    
    _pendingSaveScenes.forEach((key, data) {
      if (data['sceneId'] == sceneId) {
        keysToRemove.add(key);
      }
    });
    
    for (final key in keysToRemove) {
      _pendingSaveScenes.remove(key);
      AppLogger.i('EditorBloc', '已从保存队列中移除场景: ${sceneId}');
    }
  }

  Future<void> _onAddNewAct(
      AddNewAct event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      try {
        // 开始保存状态
        emit(currentState.copyWith(isSaving: true));
        
        AppLogger.i('EditorBloc/_onAddNewAct', '开始添加新Act: title=${event.title}');
        
        // 调用API创建新Act
        final updatedNovel = await repository.addNewAct(
          novelId,
          event.title,
        );
        
        if (updatedNovel == null) {
          AppLogger.e('EditorBloc/_onAddNewAct', '添加新Act失败，API返回null');
          emit(currentState.copyWith(
            isSaving: false,
            errorMessage: '添加新Act失败：无法获取更新后的小说数据',
          ));
          return;
        }
        
        // 检查是否成功添加了新Act
        if (updatedNovel.acts.length > currentState.novel.acts.length) {
          AppLogger.i('EditorBloc/_onAddNewAct', 
              '成功添加新Act：之前${currentState.novel.acts.length}个，现在${updatedNovel.acts.length}个');
          
          // 设置新添加的Act为活动Act
          final newAct = updatedNovel.acts.last;
          
          // Calculate chapter maps for the updated novel
          final chapterMaps = _calculateChapterMaps(updatedNovel);

          // 发出更新状态
          emit(currentState.copyWith(
            novel: updatedNovel,
            isSaving: false,
            isDirty: false,
            activeActId: newAct.id,
            // 如果新Act有章节，设置第一个章节为活动章节
            activeChapterId: newAct.chapters.isNotEmpty ? newAct.chapters.first.id : null,
            // 清除活动场景
            activeSceneId: null,
            chapterGlobalIndices: chapterMaps.chapterGlobalIndices, // Added
            chapterToActMap: chapterMaps.chapterToActMap, // Added
          ));
          
          AppLogger.i('EditorBloc/_onAddNewAct', '已更新UI状态，设置新Act为活动Act: ${newAct.id}');
        } else {
          AppLogger.w('EditorBloc/_onAddNewAct', 
              '添加Act可能失败：之前${currentState.novel.acts.length}个，现在${updatedNovel.acts.length}个');
          
          // Calculate chapter maps even if the addition might have issues, to reflect current state
          final chapterMaps = _calculateChapterMaps(updatedNovel);

          // 仍然更新状态以刷新UI
          emit(currentState.copyWith(
            novel: updatedNovel,
            isSaving: false,
            errorMessage: 'Act可能未成功添加，请检查网络连接',
            chapterGlobalIndices: chapterMaps.chapterGlobalIndices, // Added
            chapterToActMap: chapterMaps.chapterToActMap, // Added
          ));
        }
      } catch (e) {
        AppLogger.e('EditorBloc/_onAddNewAct', '添加新Act过程中发生异常', e);
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '添加新Act失败: ${e.toString()}',
        ));
      }
    }
  }

  /// 添加新章节
  Future<void> _onAddNewChapter(
      AddNewChapter event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      try {
        // 开始保存状态
        emit(currentState.copyWith(isSaving: true));
        
        AppLogger.i('EditorBloc/_onAddNewChapter', 
            '开始添加新Chapter: novelId=${event.novelId}, actId=${event.actId}, title=${event.title}');
        
        // 调用API创建新Chapter
        final updatedNovel = await repository.addNewChapter(
          event.novelId,
          event.actId,
          event.title,
        );
        
        if (updatedNovel == null) {
          AppLogger.e('EditorBloc/_onAddNewChapter', '添加新Chapter失败，API返回null');
          emit(currentState.copyWith(
            isSaving: false,
            errorMessage: '添加新Chapter失败：无法获取更新后的小说数据',
          ));
          return;
        }
        
        // 获取更新后Act中的新章节
        novel_models.Act? updatedAct;
        novel_models.Chapter? newChapter;
        
        for (final act in updatedNovel.acts) {
          if (act.id == event.actId) {
            updatedAct = act;
            if (act.chapters.isNotEmpty) {
              // 通常新章节会被添加到末尾
              newChapter = act.chapters.last;
            }
            break;
          }
        }
        
        if (updatedAct == null || newChapter == null) {
          AppLogger.w('EditorBloc/_onAddNewChapter', 
              '无法确定新添加的章节，使用更新后的小说数据');
          
          // Calculate chapter maps for the updated novel
          final chapterMaps = _calculateChapterMaps(updatedNovel);
          // 仍然更新状态
          emit(currentState.copyWith(
            novel: updatedNovel,
            isSaving: false,
            isDirty: false,
            chapterGlobalIndices: chapterMaps.chapterGlobalIndices, // Added
            chapterToActMap: chapterMaps.chapterToActMap, // Added
          ));
          return;
        }
        
        AppLogger.i('EditorBloc/_onAddNewChapter', 
            '成功添加新章节: actId=${updatedAct.id}, chapterId=${newChapter.id}');
        
        // Calculate chapter maps for the updated novel
        final chapterMaps = _calculateChapterMaps(updatedNovel);

        // 发出更新状态，并设置新章节为活动章节
        emit(currentState.copyWith(
          novel: updatedNovel,
          isSaving: false,
          isDirty: false,
          activeActId: updatedAct.id,
          activeChapterId: newChapter.id,
          // 清除活动场景，因为新章节还没有场景
          activeSceneId: null,
          chapterGlobalIndices: chapterMaps.chapterGlobalIndices, // Added
          chapterToActMap: chapterMaps.chapterToActMap, // Added
        ));
        
        AppLogger.i('EditorBloc/_onAddNewChapter', 
            '已更新UI状态，设置新章节为活动章节: ${newChapter.id}');
      } catch (e) {
        AppLogger.e('EditorBloc/_onAddNewChapter', '添加新章节过程中发生异常', e);
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '添加新章节失败: ${e.toString()}',
        ));
      }
    }
  }

  // 修改SaveSceneContent处理器也使用相同的JSON验证
  Future<void> _onSaveSceneContent(
      SaveSceneContent event, Emitter<EditorState> emit) async {
    AppLogger.i('EditorBloc',
        '接收到场景内容更新 - 场景ID: ${event.sceneId}, 字数: ${event.wordCount}');
    final currentState = state;
    if (currentState is EditorLoaded) {
      try {
        // 立即更新状态为正在保存（如果之前非保存状态）
        if (!currentState.isSaving) {
          emit(currentState.copyWith(isSaving: true));
        }

        // 找到要更新的章节和场景
        final chapter = currentState.novel.acts
            .firstWhere(
                (act) => act.id == event.actId,
                orElse: () => throw Exception('找不到指定的Act'))
            .chapters
            .firstWhere(
                (chapter) => chapter.id == event.chapterId,
                orElse: () => throw Exception('找不到指定的Chapter'));

        // 获取场景摘要（保持不变）
        final sceneSummary =
            chapter.scenes.firstWhere((s) => s.id == event.sceneId).summary;

        // 确保内容是有效的Quill JSON格式
        final String validContent = _ensureValidQuillJson(event.content);

        // 仅保存场景内容（细粒度更新）- 根据参数决定是否同步到服务器
        final updatedScene = await repository.saveSceneContent(
          event.novelId,
          event.actId,
          event.chapterId,
          event.sceneId,
          validContent, // 使用验证后的内容
          event.wordCount,
          sceneSummary,
          localOnly: event.localOnly, // 新增参数：是否仅保存到本地
        );

        // 更新小说里的场景信息
        final finalNovel = _updateNovelScene(
          currentState.novel,
          event.actId,
          event.chapterId,
          updatedScene,
        );

        // 更新最后编辑的章节ID
        var novelWithLastEdited = finalNovel;
        if (finalNovel.lastEditedChapterId != event.chapterId) {
          novelWithLastEdited = finalNovel.copyWith(
            lastEditedChapterId: event.chapterId,
          );
        }

        AppLogger.i('EditorBloc',
            '场景保存成功，更新状态 - 场景ID: ${event.sceneId}, 最终字数: ${updatedScene.wordCount}');

        // 仅当需要同步到服务器时才更新lastEditedChapterId
        if (!event.localOnly && 
            novelWithLastEdited.lastEditedChapterId != currentState.novel.lastEditedChapterId) {
          AppLogger.i('EditorBloc', '更新最后编辑章节ID: ${novelWithLastEdited.lastEditedChapterId}');
          await repository.updateLastEditedChapterId(
            novelWithLastEdited.id, 
            novelWithLastEdited.lastEditedChapterId ?? ''
          );
        }

        emit(currentState.copyWith(
          novel: novelWithLastEdited,
          isDirty: event.localOnly, // 如果只保存到本地，仍然标记为脏
          isSaving: false,
          lastSaveTime: event.localOnly ? null : DateTime.now(), // 仅在同步到服务器时更新最后保存时间
        ));
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '保存场景内容失败', e);
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '保存场景内容失败: ${e.toString()}',
        ));
      }
    }
  }

  // 添加新Scene
  Future<void> _onAddNewScene(
      AddNewScene event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(currentState.copyWith(isSaving: true));

      try {
        AppLogger.i('EditorBloc', '添加新场景 - actId: ${event.actId}, chapterId: ${event.chapterId}');
        
        // 1. 创建新场景
        final newScene = novel_models.Scene.createDefault("scene_${DateTime.now().millisecondsSinceEpoch}");
        
        // 2. 添加场景到API
        final addedScene = await repository.addScene(
          novelId,
          event.actId,
          event.chapterId,
          newScene,
        );
        
        if (addedScene == null) {
          throw Exception('添加场景失败，API返回为空');
        }
        
        // 3. 在本地模型中找到对应章节并添加场景
        final updatedNovel = _addSceneToNovel(
          currentState.novel,
          event.actId,
          event.chapterId,
          addedScene,
        );
        
        // 4. 更新状态
        emit(currentState.copyWith(
          novel: updatedNovel,
          isSaving: false,
          isDirty: false,
          // 立即将新场景设置为活动场景
          activeActId: event.actId,
          activeChapterId: event.chapterId,
          activeSceneId: addedScene.id,
        ));
        
        AppLogger.i('EditorBloc', '场景添加成功，ID: ${addedScene.id}');
      } catch (e) {
        AppLogger.e('EditorBloc', '添加场景失败: ${e.toString()}');
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: '添加场景失败: ${e.toString()}',
        ));
      }
    }
  }
  
  // 辅助方法：将场景添加到小说模型中
  novel_models.Novel _addSceneToNovel(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    novel_models.Scene newScene,
  ) {
    // 创建当前小说acts的深拷贝以便修改
    final List<novel_models.Act> updatedActs = novel.acts.map((act) {
      if (act.id == actId) {
        // 更新指定Act的章节
        final List<novel_models.Chapter> updatedChapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            // 找到指定章节，添加场景
            final List<novel_models.Scene> updatedScenes = List.from(chapter.scenes)
              ..add(newScene);
            
            return chapter.copyWith(scenes: updatedScenes);
          }
          return chapter;
        }).toList();
        
        return act.copyWith(chapters: updatedChapters);
      }
      return act;
    }).toList();
    
    // 返回更新后的小说，同时更新最后编辑章节
    return novel.copyWith(
      acts: updatedActs,
      lastEditedChapterId: chapterId,
    );
  }

  // 删除Chapter
  Future<void> _onDeleteChapter(
      DeleteChapter event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 保存原始小说数据，以便在失败时恢复
      final originalNovel = currentState.novel;

      // 查找章节在哪个Act中以及对应的索引
      int actIndex = -1;
      int chapterIndex = -1;
      novel_models.Act? act;

      for (int i = 0; i < originalNovel.acts.length; i++) {
        final currentAct = originalNovel.acts[i];
        if (currentAct.id == event.actId) {
          actIndex = i;
          act = currentAct;
          for (int j = 0; j < currentAct.chapters.length; j++) {
            if (currentAct.chapters[j].id == event.chapterId) {
              chapterIndex = j;
              break;
            }
          }
          break;
        }
      }

      if (actIndex == -1 || chapterIndex == -1 || act == null) {
        AppLogger.e('Blocs/editor/editor_bloc',
            '找不到要删除的章节: ${event.chapterId}');
        // 保持当前状态，但显示错误信息
        emit(currentState.copyWith(errorMessage: '找不到要删除的章节'));
        return;
      }

      // 确定删除后的下一个活动Chapter ID
      String? nextActiveChapterId;
      novel_models.Chapter? nextActiveChapter;
      if (act.chapters.length > 1) {
        // 如果删除后Act还有其他章节
        if (chapterIndex > 0) {
          // 优先选前一个章节
          nextActiveChapter = act.chapters[chapterIndex - 1];
        } else {
          // 否则选后一个章节
          nextActiveChapter = act.chapters[1];
        }
        nextActiveChapterId = nextActiveChapter.id;
      } else if (originalNovel.acts.length > 1) {
        // 如果当前Act没有其他章节了，但还有其他Act
        // 尝试选择前一个Act的最后一个章节或后一个Act的第一个章节
        int nextActIndex;
        if (actIndex > 0) {
          nextActIndex = actIndex - 1;
          final nextAct = originalNovel.acts[nextActIndex];
          if (nextAct.chapters.isNotEmpty) {
            nextActiveChapter = nextAct.chapters.last;
            nextActiveChapterId = nextActiveChapter.id;
          }
        } else if (actIndex < originalNovel.acts.length - 1) {
          nextActIndex = actIndex + 1;
          final nextAct = originalNovel.acts[nextActIndex];
          if (nextAct.chapters.isNotEmpty) {
            nextActiveChapter = nextAct.chapters.first;
            nextActiveChapterId = nextActiveChapter.id;
          }
        }
      }

      // 更新本地小说模型 (不可变方式)
      final updatedChapters = List<novel_models.Chapter>.from(act.chapters)
        ..removeAt(chapterIndex);
      final updatedAct = act.copyWith(chapters: updatedChapters);
      final updatedActs = List<novel_models.Act>.from(originalNovel.acts)
        ..[actIndex] = updatedAct;
      final updatedNovel = originalNovel.copyWith(
        acts: updatedActs,
        updatedAt: DateTime.now(),
      );

      // Calculate chapter maps for the updated novel state
      final chapterMaps = _calculateChapterMaps(updatedNovel);

      // 更新UI状态为 "正在保存"，并设置新的活动章节
      emit(currentState.copyWith(
        novel: updatedNovel, // 显示删除后的状态
        isDirty: true, // 标记为脏
        isSaving: true, // 标记正在保存
        // 更新活动章节ID
        activeChapterId: currentState.activeChapterId == event.chapterId
            ? nextActiveChapterId
            : currentState.activeChapterId,
        // 如果活动章节变了，也要更新活动Act
        activeActId: (currentState.activeChapterId == event.chapterId && nextActiveChapter != null)
            ? (nextActiveChapter != null ? _findActIdForChapter(originalNovel, nextActiveChapterId!) : currentState.activeActId)
            : currentState.activeActId,
        // 如果删除的是当前活动章节，把活动场景设为null
        activeSceneId: currentState.activeChapterId == event.chapterId
            ? null
            : currentState.activeSceneId,
        chapterGlobalIndices: chapterMaps.chapterGlobalIndices, // Added
        chapterToActMap: chapterMaps.chapterToActMap, // Added
      ));

      try {
        // 清理该章节的所有场景保存请求
        _cleanupPendingSavesForChapter(event.chapterId);
        
        // 使用细粒度方法删除章节
        final success = await repository.deleteChapterFine(
          event.novelId, 
          event.actId, 
          event.chapterId
        );
        
        if (!success) {
          throw Exception('删除章节失败');
        }

        // 保存成功后，更新状态为已保存
        emit((state as EditorLoaded).copyWith(
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
          // chapterGlobalIndices and chapterToActMap are already part of the state from the previous emit
        ));
        AppLogger.i('Blocs/editor/editor_bloc',
            '章节删除成功: ${event.chapterId}');
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '删除章节失败', e);
        // 删除失败，恢复原始数据
        // Recalculate maps for the original novel if rolling back
        final originalChapterMaps = _calculateChapterMaps(originalNovel);
        emit((state as EditorLoaded).copyWith(
          novel: originalNovel,
          isSaving: false,
          errorMessage: '删除章节失败: ${e.toString()}',
          activeActId: currentState.activeActId,
          activeChapterId: currentState.activeChapterId,
          activeSceneId: currentState.activeSceneId,
          chapterGlobalIndices: originalChapterMaps.chapterGlobalIndices, // Added for rollback
          chapterToActMap: originalChapterMaps.chapterToActMap, // Added for rollback
        ));
      }
    }
  }

  // 在章节删除后清理该章节的所有场景保存请求
  void _cleanupPendingSavesForChapter(String chapterId) {
    final keysToRemove = <String>[];
    
    _pendingSaveScenes.forEach((key, data) {
      if (data['chapterId'] == chapterId) {
        keysToRemove.add(key);
      }
    });
    
    for (final key in keysToRemove) {
      _pendingSaveScenes.remove(key);
      AppLogger.i('EditorBloc', '已从保存队列中移除章节${chapterId}的场景: ${key}');
    }
    
    if (keysToRemove.isNotEmpty) {
      AppLogger.i('EditorBloc', '已清理${keysToRemove.length}个属于已删除章节${chapterId}的场景保存请求');
    }
  }

  // 实现更新可见范围的处理
  Future<void> _onUpdateVisibleRange(
      UpdateVisibleRange event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(currentState.copyWith(
        visibleRange: [event.startIndex, event.endIndex],
      ));
    }
  }

  // 设置焦点章节 - 仅更新焦点，不影响活动场景
  Future<void> _onSetFocusChapter(
      SetFocusChapter event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      AppLogger.i('EditorBloc', '设置焦点章节: ${event.chapterId} (仅更新焦点，不影响活动场景)');
      
      emit(currentState.copyWith(
        focusChapterId: event.chapterId,
        // 不更新activeActId、activeChapterId和activeSceneId
      ));
    }
  }

  // 处理重置Act加载状态标志的事件
  void _onResetActLoadingFlags(ResetActLoadingFlags event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    
    final currentState = state as EditorLoaded;
    
    // 重置边界标志
    emit(currentState.copyWith(
      hasReachedEnd: false,
      hasReachedStart: false,
    ));
    
    AppLogger.i('Blocs/editor/editor_bloc', '已重置Act加载标志: hasReachedEnd=false, hasReachedStart=false');
  }
  
  void _onSetActLoadingFlags(SetActLoadingFlags event, Emitter<EditorState> emit) {
    if (state is! EditorLoaded) return;
    
    final currentState = state as EditorLoaded;
    
    // 只更新提供了值的标志
    bool hasReachedEnd = currentState.hasReachedEnd;
    bool hasReachedStart = currentState.hasReachedStart;
    
    if (event.hasReachedEnd != null) {
      hasReachedEnd = event.hasReachedEnd!;
    }
    
    if (event.hasReachedStart != null) {
      hasReachedStart = event.hasReachedStart!;
    }
    
    // 更新状态
    emit(currentState.copyWith(
      hasReachedEnd: hasReachedEnd,
      hasReachedStart: hasReachedStart,
    ));
    
    AppLogger.i('Blocs/editor/editor_bloc', 
        '已设置Act加载标志: hasReachedEnd=${hasReachedEnd}, hasReachedStart=${hasReachedStart}');
  }

  // 更新章节标题的事件处理方法
  Future<void> _onUpdateChapterTitle(
      UpdateChapterTitle event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
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
        final success = await repository.updateChapterTitle(
          novelId,
          event.actId,
          event.chapterId,
          event.title,
        );
        
        if (!success) {
          AppLogger.e('Blocs/editor/editor_bloc', '更新Chapter标题失败');
        }
        
        emit(currentState.copyWith(isDirty: false));
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '更新Chapter标题失败', e);
        emit(currentState.copyWith(
          errorMessage: '更新Chapter标题失败: ${e.toString()}',
        ));
      }
    }
  }

  // 更新卷标题的事件处理方法
  Future<void> _onUpdateActTitle(
      UpdateActTitle event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
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
        final success = await repository.updateActTitle(
          novelId,
          event.actId,
          event.title,
        );
        
        if (!success) {
          AppLogger.e('Blocs/editor/editor_bloc', '更新Act标题失败');
        }
        
        emit(currentState.copyWith(isDirty: false));
      } catch (e) {
        AppLogger.e('Blocs/editor/editor_bloc', '更新Act标题失败', e);
        emit(currentState.copyWith(
          errorMessage: '更新Act标题失败: ${e.toString()}',
        ));
      }
    }
  }
}
