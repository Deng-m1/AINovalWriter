import 'dart:async';

import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/models/scene_version.dart';
import 'package:ainoval/services/api_service/repositories/novel_repository.dart' as api;
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ainoval/ui/dialogs/scene_history_dialog.dart';

part 'editor_version_event.dart';
part 'editor_version_state.dart';

/// 编辑器版本控制Bloc
class EditorVersionBloc extends Bloc<EditorVersionEvent, EditorVersionState> {
  final api.NovelRepository _novelRepository;
  
  EditorVersionBloc({
    required api.NovelRepository novelRepository,
  }) : _novelRepository = novelRepository,
       super(EditorVersionInitial()) {
    on<EditorVersionFetchHistory>(_onFetchHistory);
    on<EditorVersionCompare>(_onCompareVersions);
    on<EditorVersionRestore>(_onRestoreVersion);
    on<EditorVersionSave>(_onSaveVersion);
  }

  /// 获取场景历史版本
  Future<void> _onFetchHistory(
    EditorVersionFetchHistory event,
    Emitter<EditorVersionState> emit,
  ) async {
    if (event.novelId.isEmpty || event.chapterId.isEmpty || event.sceneId.isEmpty) {
      emit(EditorVersionError('无效的场景ID'));
      return;
    }
    
    emit(EditorVersionLoading());
    
    try {
      final history = await _novelRepository.getSceneHistory(
        event.novelId,
        event.chapterId,
        event.sceneId,
      );
      
      if (history.isEmpty) {
        emit(EditorVersionHistoryEmpty());
      } else {
        emit(EditorVersionHistoryLoaded(history));
      }
    } catch (error) {
      print('获取历史版本失败: $error');
      emit(EditorVersionError('获取历史版本失败: $error'));
    }
  }
  
  /// 比较版本差异
  Future<void> _onCompareVersions(
    EditorVersionCompare event,
    Emitter<EditorVersionState> emit,
  ) async {
    if (event.novelId.isEmpty || event.chapterId.isEmpty || event.sceneId.isEmpty) {
      emit(EditorVersionError('无效的场景ID'));
      return;
    }
    
    emit(EditorVersionLoading());
    
    try {
      final diff = await _novelRepository.compareSceneVersions(
        event.novelId,
        event.chapterId,
        event.sceneId,
        event.versionIndex1,
        event.versionIndex2,
      );
      
      emit(EditorVersionDiffLoaded(diff));
    } catch (error) {
      print('比较版本差异失败: $error');
      emit(EditorVersionError('比较版本差异失败: $error'));
    }
  }
  
  /// 恢复到历史版本
  Future<void> _onRestoreVersion(
    EditorVersionRestore event,
    Emitter<EditorVersionState> emit,
  ) async {
    if (event.novelId.isEmpty || event.chapterId.isEmpty || event.sceneId.isEmpty) {
      emit(EditorVersionError('无效的场景ID'));
      return;
    }
    
    emit(EditorVersionLoading());
    
    try {
      final scene = await _novelRepository.restoreSceneVersion(
        event.novelId,
        event.chapterId,
        event.sceneId,
        event.historyIndex,
        event.userId,
        event.reason,
      );
      
      emit(EditorVersionRestored(scene));
    } catch (error) {
      print('恢复版本失败: $error');
      emit(EditorVersionError('恢复版本失败: $error'));
    }
  }
  
  /// 保存新版本
  Future<void> _onSaveVersion(
    EditorVersionSave event,
    Emitter<EditorVersionState> emit,
  ) async {
    if (event.novelId.isEmpty || event.chapterId.isEmpty || event.sceneId.isEmpty) {
      emit(EditorVersionError('无效的场景ID'));
      return;
    }
    
    emit(EditorVersionLoading());
    
    try {
      final scene = await _novelRepository.updateSceneContentWithHistory(
        event.novelId,
        event.chapterId,
        event.sceneId,
        event.content,
        event.userId,
        event.reason,
      );
      
      emit(EditorVersionSaved(scene));
    } catch (error) {
      print('保存版本失败: $error');
      emit(EditorVersionError('保存版本失败: $error'));
    }
  }

  /// 保存新版本并添加到历史记录
  Future<bool> saveVersionWithReason(
    String novelId,
    String chapterId,
    String sceneId,
    String content,
    String userId,
    String reason,
  ) async {
    try {
      add(EditorVersionSave(
        novelId: novelId,
        chapterId: chapterId,
        sceneId: sceneId,
        content: content,
        userId: userId,
        reason: reason,
      ));
      return true;
    } catch (e) {
      print('保存版本失败: $e');
      return false;
    }
  }
  
  /// 打开历史版本对话框
  Future<Scene?> openHistoryDialog(
    BuildContext context,
    String novelId,
    String chapterId,
    String sceneId,
  ) async {
    return await showDialog<Scene>(
      context: context,
      builder: (context) => SceneHistoryDialog(
        novelId: novelId,
        chapterId: chapterId,
        sceneId: sceneId,
      ),
    );
  }
} 