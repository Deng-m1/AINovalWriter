import 'dart:convert';
import 'package:ainoval/models/novel_structure.dart' as novel_models;
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/editor_settings.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/utils/mock_data.dart';

/// 编辑器仓库，用于处理数据获取和缓存逻辑
class EditorRepository {
  
  EditorRepository({
    required this.apiService,
    required this.localStorageService,
  });
  final ApiService apiService;
  final LocalStorageService localStorageService;
  
  /// 获取小说数据
  Future<novel_models.Novel> getNovel(String novelId) async {
    try {
      // 先尝试从本地获取
      final localNovel = await localStorageService.getNovel(novelId);
      
      // 如果本地有数据，先返回本地数据
      if (localNovel != null) {
        // 异步从服务器获取最新数据并更新本地缓存
        _fetchAndUpdateNovel(novelId);
        return localNovel;
      }
      
      // 如果本地没有数据，从服务器获取
      final remoteNovel = await apiService.fetchNovel(novelId);
      
      // 保存到本地
      await localStorageService.saveNovel(remoteNovel);
      
      return remoteNovel;
    } catch (e) {
      // 如果出错，尝试返回模拟数据
      print('获取小说数据失败: $e');
      final mockNovels = await apiService.fetchNovels();
      if (mockNovels.isNotEmpty) {
        return mockNovels.first;
      }
      throw Exception('无法获取小说数据');
    }
  }
  
  /// 异步从服务器获取最新数据并更新本地缓存
  Future<void> _fetchAndUpdateNovel(String novelId) async {
    try {
      final remoteNovel = await apiService.fetchNovel(novelId);
      await localStorageService.saveNovel(remoteNovel);
    } catch (e) {
      print('异步更新小说数据失败: $e');
    }
  }
  
  /// 获取场景内容
  Future<novel_models.Scene> getSceneContent(
    String novelId, 
    String actId, 
    String chapterId
  ) async {
    try {
      // 先尝试从本地获取
      final localScene = await localStorageService.getSceneContent(novelId, actId, chapterId);
      
      // 如果本地有数据，先返回本地数据
      if (localScene != null) {
        // 异步从服务器获取最新数据并更新本地缓存
        _fetchAndUpdateScene(novelId, actId, chapterId);
        return localScene;
      }
      
      // 如果本地没有数据，从服务器获取
      final remoteScene = await apiService.fetchSceneContent(novelId, actId, chapterId);
      
      // 保存到本地
      await localStorageService.saveSceneContent(novelId, actId, chapterId, remoteScene);
      
      return remoteScene;
    } catch (e) {
      // 如果出错，尝试返回模拟数据
      print('获取场景内容失败: $e');
      final mockNovels = await apiService.fetchNovels();
      if (mockNovels.isNotEmpty) {
        final novel = mockNovels.first;
        if (novel.acts.isNotEmpty) {
          final act = novel.acts.first;
          if (act.chapters.isNotEmpty) {
            return act.chapters.first.scene;
          }
        }
      }
      throw Exception('无法获取场景内容');
    }
  }
  
  /// 异步从服务器获取最新场景数据并更新本地缓存
  Future<void> _fetchAndUpdateScene(
    String novelId, 
    String actId, 
    String chapterId
  ) async {
    try {
      final remoteScene = await apiService.fetchSceneContent(novelId, actId, chapterId);
      await localStorageService.saveSceneContent(novelId, actId, chapterId, remoteScene);
    } catch (e) {
      print('异步更新场景数据失败: $e');
    }
  }
  
  /// 保存场景内容
  Future<novel_models.Scene> saveSceneContent(
    String novelId,
    String actId,
    String chapterId,
    String content,
    int wordCount,
    novel_models.Summary summary,
  ) async {
    try {
      // 获取当前场景
      final scene = await apiService.fetchSceneContent(novelId, actId, chapterId);
      
      // 更新场景内容
      final updatedScene = scene.copyWith(
        content: content,
        wordCount: wordCount,
        summary: summary,
        lastEdited: DateTime.now(),
      );
      
      // 保存到API服务
      final savedScene = await apiService.updateSceneContent(
        novelId,
        actId,
        chapterId,
        updatedScene,
      );
      
      // 获取并更新小说数据中的总字数
      try {
        final novel = await apiService.fetchNovel(novelId);
        int totalWordCount = 0;
        
        // 计算所有场景的总字数
        for (final act in novel.acts) {
          for (final chapter in act.chapters) {
            totalWordCount += chapter.scene.wordCount;
          }
        }
        
        // 更新小说数据
        final updatedNovel = novel.copyWith(
          updatedAt: DateTime.now(),
        );
        
        // 保存更新后的小说数据
        await apiService.updateNovel(updatedNovel);
      } catch (e) {
        print('更新小说总字数失败: $e');
      }
      
      return savedScene;
    } catch (e) {
      throw Exception('保存场景内容失败: $e');
    }
  }
  
  /// 保存摘要
  Future<novel_models.Summary> saveSummary(
    String novelId,
    String actId,
    String chapterId,
    String content,
  ) async {
    try {
      // 获取当前场景
      final scene = await apiService.fetchSceneContent(novelId, actId, chapterId);
      
      // 更新摘要内容
      final updatedSummary = scene.summary.copyWith(
        content: content,
      );
      
      // 保存到API服务
      return await apiService.updateSummary(
        novelId,
        actId,
        chapterId,
        updatedSummary,
      );
    } catch (e) {
      throw Exception('保存摘要失败: $e');
    }
  }
  
  /// 获取编辑器设置
  Future<Map<String, dynamic>> getEditorSettings() async {
    try {
      return await localStorageService.getEditorSettings();
    } catch (e) {
      print('获取编辑器设置失败: $e');
      return {}; // 返回默认设置
    }
  }
  
  /// 保存编辑器设置
  Future<void> saveEditorSettings(Map<String, dynamic> settings) async {
    try {
      await localStorageService.saveEditorSettings(settings);
    } catch (e) {
      print('保存编辑器设置失败: $e');
    }
  }
  
  /// 保存小说数据
  Future<void> saveNovel(novel_models.Novel novel) async {
    try {
      // 先保存到本地
      await localStorageService.saveNovel(novel);
      
      // 再保存到服务器
      try {
        await apiService.updateNovel(novel);
      } catch (e) {
        // API保存失败，但本地保存成功，可以稍后同步
        print('API保存小说失败: $e');
      }
    } catch (e) {
      throw Exception('保存小说失败: $e');
    }
  }
  
  // 获取编辑器内容
  Future<EditorContent> getEditorContent(String novelId, String chapterId) async {
    try {
      // 尝试从本地存储获取
      final localContent = await localStorageService.getEditorContent(novelId, chapterId);
      if (localContent != null) {
        return localContent;
      }

      // 如果本地没有，从API获取
      final apiContent = await apiService.getEditorContent(novelId, chapterId);
      
      // 保存到本地
      await localStorageService.saveEditorContent(apiContent);
      
      return apiContent;
    } catch (e) {
      // 如果出错，返回空内容
      return EditorContent(
        id: '$novelId-$chapterId',
        content: '{"ops":[{"insert":"\\n"}]}',
        lastSaved: DateTime.now(),
      );
    }
  }
  
  // 保存编辑器内容
  Future<EditorContent> saveEditorContent(EditorContent content) async {
    try {
      // 更新最后保存时间
      final updatedContent = content.copyWith(
        lastSaved: DateTime.now(),
      );
      
      // 保存到本地
      await localStorageService.saveEditorContent(updatedContent);
      
      // 同步到API
      try {
        await apiService.saveEditorContent(updatedContent);
      } catch (e) {
        // API保存失败，但本地保存成功，可以稍后同步
        print('API保存失败: $e');
      }
      
      return updatedContent;
    } catch (e) {
      throw Exception('保存内容失败: $e');
    }
  }
  
  // 获取本地草稿
  Future<String?> getLocalDraft(String novelId, String chapterId) async {
    try {
      final content = await localStorageService.getEditorContent(novelId, chapterId);
      
      if (content != null) {
        return content.content;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // 获取修订历史
  Future<List<Revision>> getRevisionHistory(String novelId, String chapterId) async {
    // 在第一个迭代中，使用模拟数据
    return MockData.getRevisionHistory(novelId, chapterId);
  }
  
  // 恢复到特定修订版本
  Future<EditorContent> restoreRevision(
    String novelId,
    String chapterId,
    String revisionId,
  ) async {
    try {
      // 获取修订历史
      final revisions = await getRevisionHistory(novelId, chapterId);
      
      // 查找指定的修订版本
      final revision = revisions.firstWhere(
        (rev) => rev.id == revisionId,
        orElse: () => throw Exception('未找到修订版本'),
      );
      
      // 创建新的编辑器内容
      final restoredContent = EditorContent(
        id: chapterId,
        content: revision.content,
        lastSaved: DateTime.now(),
        revisions: revisions,
      );
      
      return restoredContent;
    } catch (e) {
      throw Exception('恢复修订版本失败: $e');
    }
  }
} 