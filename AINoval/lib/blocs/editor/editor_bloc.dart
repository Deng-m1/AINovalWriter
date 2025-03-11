import 'dart:async';

import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/repositories/editor_repository.dart' hide EditorSettings;
import 'package:ainoval/utils/word_count_analyzer.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'editor_event.dart';
part 'editor_state.dart';

// Bloc实现
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  
  EditorBloc({
    required this.repository,
    required this.novelId,
  }) : super(EditorInitial()) {
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
  }
  final EditorRepository repository;
  final String novelId;
  Timer? _autoSaveTimer;
  novel_models.Novel? _novel;
  bool _isDirty = false;
  DateTime? _lastSaveTime;
  final EditorSettings _settings = const EditorSettings();
  
  Future<void> _onLoadContent(LoadEditorContent event, Emitter<EditorState> emit) async {
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
  
  Future<void> _onUpdateContent(UpdateContent event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 更新当前活动场景的内容
      if (currentState.activeActId != null && currentState.activeChapterId != null) {
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
  
  Future<void> _onSaveContent(SaveContent event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded && currentState.isDirty) {
      emit(currentState.copyWith(isSaving: true));
      
      try {
        // 保存整个小说数据
        await repository.saveNovel(currentState.novel);
        
        // 如果有活动章节，保存场景内容
        if (currentState.activeActId != null && currentState.activeChapterId != null) {
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
              print('章节没有场景，无法保存');
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
            print('保存场景内容失败: $e');
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
  
  Future<void> _onUpdateSceneContent(UpdateSceneContent event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 更新指定场景的内容
      final updatedNovel = _updateSceneContent(
        currentState.novel,
        event.actId,
        event.chapterId,
        event.sceneId,
        event.content,
      );
      
      // 如果不需要重建UI，只更新内部状态，不触发emit
      if (!event.shouldRebuild) {
        _novel = updatedNovel;
        _isDirty = true;
        
        // 立即保存场景内容，但不触发UI更新
        try {
          // 计算字数
          final wordCount = WordCountAnalyzer.countWords(event.content);
          
          // 获取当前场景
          final act = updatedNovel.acts.firstWhere((a) => a.id == event.actId);
          final chapter = act.chapters.firstWhere((c) => c.id == event.chapterId);
          
          // 保存场景内容
          final updatedScene = await repository.saveSceneContent(
            event.novelId,
            event.actId,
            event.chapterId,
            event.sceneId,
            event.content,
            wordCount.toString(),
            chapter.scenes.first.summary,
          );
          
          // 更新小说数据，但不触发UI更新
          _novel = _updateNovelScene(
            updatedNovel,
            event.actId,
            event.chapterId,
            updatedScene,
          );
          _isDirty = false;
          _lastSaveTime = DateTime.now();
        } catch (e) {
          print('保存场景内容失败: $e');
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
      
      // 立即保存场景内容
      try {
        // 计算字数
        final wordCount = WordCountAnalyzer.countWords(event.content);
        
        // 获取当前场景
        final act = updatedNovel.acts.firstWhere((a) => a.id == event.actId);
        final chapter = act.chapters.firstWhere((c) => c.id == event.chapterId);
        
        // 保存场景内容
        final updatedScene = await repository.saveSceneContent(
          event.novelId,
          event.actId,
          event.chapterId,
          event.sceneId,
          event.content,
          wordCount.toString(),
          chapter.scenes.first.summary,
        );
        
        // 更新小说数据
        final finalNovel = _updateNovelScene(
          updatedNovel,
          event.actId,
          event.chapterId,
          updatedScene,
        );
        
        // 保存成功后，更新状态为已保存
        emit((state as EditorLoaded).copyWith(
          novel: finalNovel,
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
        ));
      } catch (e) {
        print('保存场景内容失败: $e');
        emit((state as EditorLoaded).copyWith(
          isSaving: false,
        ));
      }
    }
  }
  
  Future<void> _onUpdateSummary(UpdateSummary event, Emitter<EditorState> emit) async {
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
          final chapter = act.chapters.firstWhere((c) => c.id == event.chapterId);
          
          // 查找当前活动场景
          final sceneIndex = chapter.scenes.indexWhere((s) => s.id == event.sceneId);
          if (sceneIndex < 0) {
            throw Exception('场景不存在');
          }
          
          // 更新场景
          final updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
          updatedScenes[sceneIndex] = updatedScenes[sceneIndex].copyWith(summary: updatedSummary);
          
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
          print('保存摘要失败: $e');
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
        final sceneIndex = chapter.scenes.indexWhere((s) => s.id == event.sceneId);
        if (sceneIndex < 0) {
          throw Exception('场景不存在');
        }
        
        // 更新场景
        final updatedScenes = List<novel_models.Scene>.from(chapter.scenes);
        updatedScenes[sceneIndex] = updatedScenes[sceneIndex].copyWith(summary: updatedSummary);
        
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
        print('保存摘要失败: $e');
        emit((state as EditorLoaded).copyWith(
          isSaving: false,
        ));
      }
    }
  }
  
  Future<void> _onToggleSettings(ToggleEditorSettings event, Emitter<EditorState> emit) async {
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
  
  Future<void> _onUpdateSettings(UpdateEditorSettings event, Emitter<EditorState> emit) async {
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
  Future<void> _onSetActiveChapter(SetActiveChapter event, Emitter<EditorState> emit) async {
    print('设置活动章节: actId=${event.actId}, chapterId=${event.chapterId}');
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(currentState.copyWith(
        activeActId: event.actId,
        activeChapterId: event.chapterId,
      ));
    }
  }
  
  // 处理设置活动场景事件
  Future<void> _onSetActiveScene(SetActiveScene event, Emitter<EditorState> emit) async {
    print('设置活动场景: actId=${event.actId}, chapterId=${event.chapterId}, sceneId=${event.sceneId}');
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
  Future<void> _onUpdateActTitle(UpdateActTitle event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 保存原始小说数据，以便在失败时恢复
      final originalNovel = currentState.novel;
      
      // 更新小说数据
      final updatedNovel = _updateActTitle(originalNovel, event.actId, event.title);
      
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
        
        print('Act标题保存成功: ${event.title}');
      } catch (e) {
        print('保存Act标题失败: $e');
        
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
  Future<void> _onUpdateChapterTitle(UpdateChapterTitle event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 保存原始小说数据，以便在失败时恢复
      final originalNovel = currentState.novel;
      
      // 更新小说数据
      final updatedNovel = _updateChapterTitle(
        originalNovel, 
        event.actId, 
        event.chapterId, 
        event.title
      );
      
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
        
        print('Chapter标题保存成功: ${event.title}');
      } catch (e) {
        print('保存Chapter标题失败: $e');
        
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
  
  // 辅助方法：更新小说场景
  novel_models.Novel _updateNovelScene(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    novel_models.Scene scene,
    {String? sceneId}
  ) {
    final acts = novel.acts.map((act) {
      if (act.id == actId) {
        final chapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            // 如果提供了sceneId，则更新特定Scene
            if (sceneId != null) {
              final updatedScenes = chapter.scenes.map((s) {
                if (s.id == sceneId) {
                  return scene;
                }
                return s;
              }).toList();
              return chapter.copyWith(scenes: updatedScenes);
            } 
            // 否则，如果只有一个Scene，则更新它
            else if (chapter.scenes.length == 1) {
              return chapter.copyWith(scenes: [scene]);
            }
            // 如果没有Scene，则添加一个
            else if (chapter.scenes.isEmpty) {
              return chapter.copyWith(scenes: [scene]);
            }
            // 否则不做任何更改
            return chapter;
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
            final sceneIndex = chapter.scenes.indexWhere((s) => s.id == sceneId);
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
            final sceneIndex = chapter.scenes.indexWhere((s) => s.id == sceneId);
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
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
          // 设置新创建的Act为活动Act
          activeActId: newAct.id,
          activeChapterId: null,
        ));
        
        print('新Act添加成功: ${event.title}, ID: ${newAct.id}');
      } catch (e) {
        print('添加新Act失败: $e');
        
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
  Future<void> _onAddNewChapter(AddNewChapter event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 保存原始小说数据，以便在失败时恢复
      final originalNovel = currentState.novel;
      
      // 查找对应的Act
      final actIndex = originalNovel.acts.indexWhere((act) => act.id == event.actId);
      if (actIndex == -1) {
        emit(const EditorError(message: '找不到指定的Act'));
        return;
      }
      
      // 获取Act并添加新Chapter
      final act = originalNovel.acts[actIndex];
      final updatedAct = act.addChapter(event.title);
      
      // 获取新创建的Chapter
      final newChapter = updatedAct.chapters.last;
      
      // 更新小说数据
      final updatedActs = List<novel_models.Act>.from(originalNovel.acts);
      updatedActs[actIndex] = updatedAct;
      final updatedNovel = originalNovel.copyWith(
        acts: updatedActs,
        updatedAt: DateTime.now(),
      );
      
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
        
        // 保存场景内容
        if (newChapter.scenes.isEmpty) {
          print('新章节没有场景，无需保存场景内容');
        } else {
          final scene = newChapter.scenes.first;
          final wordCount = WordCountAnalyzer.countWords(scene.content);
          
          await repository.saveSceneContent(
            event.novelId,
            event.actId,
            newChapter.id,
            scene.id,
            scene.content,
            wordCount.toString(),
            scene.summary,
          );
        }
        
        // 保存成功后，更新状态为已保存
        emit((state as EditorLoaded).copyWith(
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
          // 设置新创建的Chapter为活动Chapter
          activeActId: event.actId,
          activeChapterId: newChapter.id,
        ));
        
        print('新Chapter添加成功: ${event.title}, ID: ${newChapter.id}');
      } catch (e) {
        print('添加新Chapter失败: $e');
        
        // 保存失败，恢复原始数据
        emit((state as EditorLoaded).copyWith(
          novel: originalNovel,
          isSaving: false,
          errorMessage: '添加新Chapter失败，请重试',
        ));
      }
    }
  }
  
  // 处理添加新Scene事件
  Future<void> _onAddNewScene(AddNewScene event, Emitter<EditorState> emit) async {
    print('开始处理添加新Scene事件: actId=${event.actId}, chapterId=${event.chapterId}');
    final currentState = state;
    if (currentState is EditorLoaded) {
      // 获取当前小说
      final novel = currentState.novel;
      print('当前小说: id=${novel.id}, title=${novel.title}, acts数量=${novel.acts.length}');
      
      // 查找对应的Act和Chapter
      final act = novel.getAct(event.actId);
      if (act == null) {
        print('找不到指定的Act: ${event.actId}');
        emit(const EditorError(message: '找不到指定的Act'));
        return;
      }
      print('找到Act: id=${act.id}, title=${act.title}, chapters数量=${act.chapters.length}');
      
      final chapter = act.getChapter(event.chapterId);
      if (chapter == null) {
        print('找不到指定的Chapter: ${event.chapterId}');
        emit(const EditorError(message: '找不到指定的Chapter'));
        return;
      }
      print('找到Chapter: id=${chapter.id}, title=${chapter.title}, scenes数量=${chapter.scenes.length}');
      
      // 向Chapter添加新Scene
      final updatedChapter = chapter.addScene();
      final newScene = updatedChapter.scenes.last; // 获取新添加的Scene
      print('创建新Scene: id=${newScene.id}');
      
      // 更新Act的Chapters
      final updatedChapters = List<novel_models.Chapter>.from(act.chapters);
      final chapterIndex = updatedChapters.indexWhere((c) => c.id == event.chapterId);
      updatedChapters[chapterIndex] = updatedChapter;
      final updatedAct = act.copyWith(chapters: updatedChapters);
      
      // 更新Novel的Acts
      final updatedActs = List<novel_models.Act>.from(novel.acts);
      final actIndex = updatedActs.indexWhere((a) => a.id == event.actId);
      updatedActs[actIndex] = updatedAct;
      final updatedNovel = novel.copyWith(
        acts: updatedActs,
        updatedAt: DateTime.now(),
      );
      
      // 设置为脏状态，开始保存
      print('更新状态为脏状态，开始保存');
      emit(currentState.copyWith(
        novel: updatedNovel,
        isDirty: true,
        isSaving: true,
      ));
      
      // 立即保存到本地存储
      try {
        // 保存整个小说数据
        print('保存整个小说数据');
        await repository.saveNovel(updatedNovel);
        
        // 保存场景内容
        final wordCount = WordCountAnalyzer.countWords(newScene.content);
        print('保存场景内容: wordCount=$wordCount');
        
        novel_models.Scene updatedScene;
        try {
          updatedScene = await repository.saveSceneContent(
            event.novelId,
            event.actId,
            event.chapterId,
            event.sceneId,
            newScene.content,
            wordCount.toString(),
            chapter.scenes.first.summary,
          );
          print('场景内容保存成功: sceneId=${updatedScene.id}');
        } catch (e) {
          print('保存场景内容失败，使用新创建的场景: $e');
          // 如果保存失败，使用新创建的场景
          updatedScene = newScene;
        }
        
        // 更新小说数据，包含保存后的场景
        final finalNovel = _updateNovelScene(
          updatedNovel,
          event.actId,
          event.chapterId,
          updatedScene,
        );
        
        // 保存成功后，更新状态为已保存
        print('保存成功，更新状态为已保存');
        emit((state as EditorLoaded).copyWith(
          novel: finalNovel,
          isDirty: false,
          isSaving: false,
          lastSaveTime: DateTime.now(),
          // 设置新创建的Scene为活动Scene
          activeActId: event.actId,
          activeChapterId: event.chapterId,
          activeSceneId: event.sceneId,
        ));
        
        print('新Scene添加成功, ID: ${newScene.id}');
      } catch (e) {
        print('添加新Scene失败: $e');
        
        // 保存失败，恢复原始数据
        emit((state as EditorLoaded).copyWith(
          novel: novel,
          isSaving: false,
          errorMessage: '添加新Scene失败，请重试',
        ));
      }
    } else {
      print('当前状态不是EditorLoaded: ${state.runtimeType}');
    }
  }
  
  @override
  Future<void> close() {
    _autoSaveTimer?.cancel();
    return super.close();
  }
} 