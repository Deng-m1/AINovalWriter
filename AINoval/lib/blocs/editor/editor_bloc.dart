import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/repositories/editor_repository.dart' hide EditorSettings;
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/utils/word_count_analyzer.dart';

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
    on<UpdateActTitle>(_onUpdateActTitle);
    on<UpdateChapterTitle>(_onUpdateChapterTitle);
  }
  final EditorRepository repository;
  final String novelId;
  Timer? _autoSaveTimer;
  novel_models.Novel? _novel;
  bool _isDirty = false;
  DateTime? _lastSaveTime;
  EditorSettings _settings = const EditorSettings();
  
  Future<void> _onLoadContent(LoadEditorContent event, Emitter<EditorState> emit) async {
    emit(EditorLoading());
    
    try {
      // 获取小说数据
      final novel = await repository.getNovel(novelId);
      
      // 获取编辑器设置
      final settings = await repository.getEditorSettings();
      
      emit(EditorLoaded(
        novel: novel,
        settings: settings,
        activeActId: novel.acts.isNotEmpty ? novel.acts.first.id : null,
        activeChapterId: novel.acts.isNotEmpty && novel.acts.first.chapters.isNotEmpty 
            ? novel.acts.first.chapters.first.id 
            : null,
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
            final scene = chapter.scene;
            
            // 计算字数
            final wordCount = WordCountAnalyzer.countWords(scene.content);
            
            // 保存场景内容
            final updatedScene = await repository.saveSceneContent(
              novelId,
              currentState.activeActId!,
              currentState.activeChapterId!,
              scene.content,
              wordCount,
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
      final updatedNovel = _updateNovelSceneContent(
        currentState.novel,
        event.actId,
        event.chapterId,
        event.content,
      );
      
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
          novelId,
          event.actId,
          event.chapterId,
          event.content,
          wordCount,
          chapter.scene.summary,
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
      final updatedNovel = _updateNovelSummary(
        currentState.novel,
        event.actId,
        event.chapterId,
        event.summary,
      );
      
      // 设置为脏状态
      emit(currentState.copyWith(
        novel: updatedNovel,
        isDirty: true,
        isSaving: true,
      ));
      
      // 保存摘要
      try {
        final updatedSummary = await repository.saveSummary(
          novelId,
          event.actId,
          event.chapterId,
          event.summary,
        );
        
        // 更新小说数据
        final act = updatedNovel.acts.firstWhere((a) => a.id == event.actId);
        final chapter = act.chapters.firstWhere((c) => c.id == event.chapterId);
        final updatedScene = chapter.scene.copyWith(summary: updatedSummary);
        
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
    final currentState = state;
    if (currentState is EditorLoaded) {
      emit(currentState.copyWith(
        activeActId: event.actId,
        activeChapterId: event.chapterId,
      ));
    }
  }
  
  // 处理更新Act标题事件
  Future<void> _onUpdateActTitle(UpdateActTitle event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      final updatedNovel = _updateActTitle(currentState.novel, event.actId, event.title);
      
      // 设置为脏状态，触发自动保存
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
      } catch (e) {
        print('保存Act标题失败: $e');
        emit((state as EditorLoaded).copyWith(
          isSaving: false,
        ));
      }
    }
  }
  
  // 处理更新Chapter标题事件
  Future<void> _onUpdateChapterTitle(UpdateChapterTitle event, Emitter<EditorState> emit) async {
    final currentState = state;
    if (currentState is EditorLoaded) {
      final updatedNovel = _updateChapterTitle(
        currentState.novel, 
        event.actId, 
        event.chapterId, 
        event.title
      );
      
      // 设置为脏状态，触发自动保存
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
      } catch (e) {
        print('保存Chapter标题失败: $e');
        emit((state as EditorLoaded).copyWith(
          isSaving: false,
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
            final updatedScene = chapter.scene.copyWith(
              content: content,
            );
            return chapter.copyWith(scene: updatedScene);
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
  ) {
    final acts = novel.acts.map((act) {
      if (act.id == actId) {
        final chapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            return chapter.copyWith(scene: scene);
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
  novel_models.Novel _updateNovelSceneContent(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    String content,
  ) {
    final acts = novel.acts.map((act) {
      if (act.id == actId) {
        final chapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            final updatedScene = chapter.scene.copyWith(
              content: content,
            );
            return chapter.copyWith(scene: updatedScene);
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
  novel_models.Novel _updateNovelSummary(
    novel_models.Novel novel,
    String actId,
    String chapterId,
    String summaryContent,
  ) {
    final acts = novel.acts.map((act) {
      if (act.id == actId) {
        final chapters = act.chapters.map((chapter) {
          if (chapter.id == chapterId) {
            final updatedSummary = chapter.scene.summary.copyWith(
              content: summaryContent,
            );
            final updatedScene = chapter.scene.copyWith(
              summary: updatedSummary,
            );
            return chapter.copyWith(scene: updatedScene);
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
  
  @override
  Future<void> close() {
    _autoSaveTimer?.cancel();
    return super.close();
  }
} 