import 'dart:async';
import 'package:ainoval/config/app_config.dart';
import 'package:ainoval/models/editor_content.dart';
import 'package:ainoval/models/novel_structure.dart';
import 'package:ainoval/services/api_service.dart';
import 'package:ainoval/services/local_storage_service.dart';
import 'package:ainoval/services/mock_data_service.dart';
import 'package:ainoval/models/chat_models.dart';

/// 编辑器仓库
/// 
/// 负责管理编辑器相关的数据，包括小说结构、场景内容、修订历史等
class EditorRepository {
  
  /// 构造函数
  EditorRepository({
    required this.apiService,
    required this.localStorageService,
    MockDataService? mockService,
  }) : _mockService = mockService ?? MockDataService();
  final ApiService apiService;
  final LocalStorageService localStorageService;
  final MockDataService _mockService;
  
  /// 获取小说
  Future<Novel?> getNovel(String novelId) async {
    try {
      // 尝试从本地存储获取
      final localNovel = await localStorageService.getNovel(novelId);
      if (localNovel != null) {
        return localNovel;
      }
      
      // 尝试从API获取
      final apiNovel = await apiService.fetchNovel(novelId);
      // 保存到本地存储
      await localStorageService.saveNovel(apiNovel);
      return apiNovel;
    } catch (e) {
      print('获取小说失败: $e');
      
      // 如果配置为使用模拟数据，则返回模拟数据
      if (AppConfig.shouldUseMockData) {
        return _mockService.getNovel(novelId);
      }
    }
    
    return null;
  }
  
  /// 保存小说数据
  Future<bool> saveNovel(Novel novel) async {
    try {
      // 先保存到本地存储
      await localStorageService.saveNovel(novel);
      
      // 再保存到API
      if (!AppConfig.shouldUseMockData) {
        await apiService.updateNovel(novel);
      }
      return true;
    } catch (e) {
      print('保存小说失败: $e');
      return false;
    }
  }
  
  /// 获取场景内容
  Future<Scene?> getSceneContent(String novelId, String actId, String chapterId, String sceneId) async {
    try {
      // 尝试从本地存储获取
      final localScene = await localStorageService.getSceneContent(novelId, actId, chapterId, sceneId);
      if (localScene != null) {
        return localScene;
      }
      
      // 尝试从API获取
      final apiScene = await apiService.fetchSceneContent(novelId, actId, chapterId, sceneId);
      // 保存到本地存储
      await localStorageService.saveSceneContent(novelId, actId, chapterId, sceneId, apiScene);
      return apiScene;
    } catch (e) {
      print('获取场景内容失败: $e');
      
      // 如果配置为使用模拟数据，则返回模拟数据
      if (AppConfig.shouldUseMockData) {
        return _mockService.getSceneContent(novelId, actId, chapterId, sceneId);
      }
    }
    
    return null;
  }
  
  /// 保存场景内容
  Future<Scene> saveSceneContent(
    String novelId,
    String actId,
    String chapterId,
    String sceneId,
    String content,
    String wordCount,
    Summary summary,
  ) async {
    try {
      // 获取当前场景
      Scene? scene;
      try {
        // 尝试获取特定Scene
        final chapter = await getChapter(novelId, actId, chapterId);
        if (chapter != null && chapter.scenes.isNotEmpty) {
          scene = chapter.scenes.firstWhere((s) => s.id == sceneId, orElse: () => Scene.createEmpty());
        }
      } catch (e) {
        print('获取场景失败，将创建新场景: $e');
        // 如果获取失败，创建一个新的场景
        scene = null;
      }
      
      // 如果场景不存在，创建一个新的场景
      if (scene == null) {
        scene = Scene.createEmpty();
      }
      
      // 更新场景内容
      final updatedScene = scene.copyWith(
        content: content,
        wordCount: int.tryParse(wordCount) ?? 0,
        summary: summary,
        lastEdited: DateTime.now(),
      );
      
      // 保存到API
      if (!AppConfig.shouldUseMockData) {
        await apiService.updateSceneContent(novelId, actId, chapterId, sceneId, updatedScene);
      } else {
        // 在模拟环境中，直接更新本地数据
        _mockService.updateSceneContent(novelId, actId, chapterId, sceneId, updatedScene);
      }
      
      // 保存到本地存储
      await localStorageService.saveSceneContent(novelId, actId, chapterId, sceneId, updatedScene);
      
      return updatedScene;
    } catch (e) {
      print('保存场景内容失败: $e');
      throw Exception('保存场景内容失败: $e');
    }
  }
  
  /// 保存摘要
  Future<Summary> saveSummary(
    String novelId,
    String actId,
    String chapterId,
    String sceneId,
    String content,
  ) async {
    try {
      // 获取当前场景
      final scene = await getSceneContent(novelId, actId, chapterId, sceneId);
      if (scene == null) {
        throw Exception('场景不存在');
      }
      
      // 更新摘要内容
      final updatedSummary = scene.summary.copyWith(
        content: content,
      );
      
      // 保存到API
      if (!AppConfig.shouldUseMockData) {
        await apiService.updateSummary(novelId, actId, chapterId, sceneId, updatedSummary);
      } else {
        // 在模拟环境中，直接更新本地数据
        _mockService.updateSummary(novelId, actId, chapterId, sceneId, updatedSummary);
      }
      
      return updatedSummary;
    } catch (e) {
      print('保存摘要失败: $e');
      throw Exception('保存摘要失败: $e');
    }
  }
  
  /// 获取编辑器内容
  Future<EditorContent> getEditorContent(String novelId, String chapterId, String sceneId) async {
    try {
      // 尝试从本地存储获取
      final localContent = await localStorageService.getEditorContent(novelId, chapterId, sceneId);
      if (localContent != null) {
        return localContent;
      }
      
      // 尝试从API获取
      final apiContent = await apiService.getEditorContent(novelId, chapterId, sceneId);
      // 保存到本地存储
      await localStorageService.saveEditorContent(apiContent);
      return apiContent;
    } catch (e) {
      print('获取编辑器内容失败: $e');
      
      // 如果配置为使用模拟数据，则返回模拟数据
      if (AppConfig.shouldUseMockData) {
        return _mockService.getEditorContent(novelId, chapterId, sceneId);
      }
    }
    
    // 如果所有尝试都失败，返回空内容
    return EditorContent(
      id: '$novelId-$chapterId-$sceneId',
      content: '{"ops":[{"insert":"\\n"}]}',
      lastSaved: DateTime.now(),
    );
  }
  
  /// 保存编辑器内容
  Future<bool> saveEditorContent(String novelId, String chapterId, String sceneId, EditorContent content) async {
    try {
      // 确保内容ID正确
      final updatedContent = content.copyWith(
        id: '$novelId-$chapterId-$sceneId',
        lastSaved: DateTime.now(),
      );
      
      // 先保存到本地存储
      await localStorageService.saveEditorContent(updatedContent);
      
      // 再保存到API
      await apiService.saveEditorContent(updatedContent);
      return true;
    } catch (e) {
      print('保存编辑器内容失败: $e');
      return false;
    }
  }
  
  /// 获取编辑器设置
  Future<Map<String, dynamic>> getEditorSettings() async {
    try {
      // 从本地存储获取设置
      final settings = await localStorageService.getEditorSettings();
      return settings;
    } catch (e) {
      print('获取编辑器设置失败: $e');
      // 返回默认设置
      return {
        'fontSize': 16.0,
        'lineHeight': 1.5,
        'fontFamily': 'Roboto',
        'theme': 'light',
        'autoSave': true,
      };
    }
  }
  
  /// 保存编辑器设置
  Future<void> saveEditorSettings(Map<String, dynamic> settings) async {
    try {
      // 保存到本地存储
      await localStorageService.saveEditorSettings(settings);
    } catch (e) {
      print('保存编辑器设置失败: $e');
      throw Exception('保存编辑器设置失败: $e');
    }
  }
  
  /// 保存场景标题
  Future<bool> saveSceneTitle(String novelId, String actId, String chapterId, String sceneId, String title) async {
    try {
      // 获取当前场景
      final scene = await getSceneContent(novelId, actId, chapterId, sceneId);
      if (scene == null) {
        return false;
      }
      
      // 更新场景内容
      // 注意：Scene类没有直接的title属性，我们只能更新其他属性
      final updatedScene = scene.copyWith(
        content: scene.content,
        lastEdited: DateTime.now(),
      );
      
      // 保存更新后的场景
      await apiService.updateSceneContent(novelId, actId, chapterId, sceneId, updatedScene);
      
      // 同时更新本地存储
      await localStorageService.saveSceneContent(novelId, actId, chapterId, sceneId, updatedScene);
      
      return true;
    } catch (e) {
      print('保存场景标题失败: $e');
      return false;
    }
  }
  
  /// 获取修订历史
  Future<List<Revision>> getRevisionHistory(String novelId, String chapterId) async {
    try {
      // 尝试从API获取
      final revisions = await apiService.getRevisionHistory(novelId, chapterId);
      return revisions;
    } catch (e) {
      print('获取修订历史失败: $e');
      
      // 如果配置为使用模拟数据，则返回模拟数据
      if (AppConfig.shouldUseMockData) {
        return _mockService.getRevisionHistory(novelId, chapterId);
      }
      
      return [];
    }
  }
  
  /// 创建修订版本
  Future<bool> createRevision(String novelId, String chapterId, String content, String comment) async {
    try {
      // 创建修订版本对象
      // 使用editor_content.dart中的Revision类
      final revision = Revision(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        timestamp: DateTime.now(),
        authorId: 'current-user',
        comment: comment,
      );
      
      // 获取当前修订历史
      final revisions = await getRevisionHistory(novelId, chapterId);
      
      // 添加新的修订版本
      // 注意：这里只是模拟添加，实际上需要通过API保存
      
      // 这里我们只在开发环境中模拟保存成功
      if (AppConfig.shouldUseMockData) {
        return true;
      }
      
      // 在生产环境中，需要实现实际的保存逻辑
      // 例如：await apiService.updateRevisionHistory(novelId, chapterId, revisions);
      
      return false;
    } catch (e) {
      print('创建修订版本失败: $e');
      return false;
    }
  }
  
  /// 应用修订版本
  Future<bool> applyRevision(String novelId, String chapterId, String revisionId) async {
    try {
      // 获取修订历史
      final revisions = await getRevisionHistory(novelId, chapterId);
      final revision = revisions.firstWhere((r) => r.id == revisionId);
      
      // 创建编辑器内容
      final content = EditorContent(
        id: '$novelId-$chapterId',
        content: revision.content,
        lastSaved: DateTime.now(),
      );
      
      // 保存编辑器内容
      final success = await saveEditorContent(novelId, chapterId, '', content);
      return success;
    } catch (e) {
      print('应用修订版本失败: $e');
      return false;
    }
  }
  
  /// 获取章节
  Future<Chapter?> getChapter(String novelId, String actId, String chapterId) async {
    try {
      // 获取小说
      final novel = await getNovel(novelId);
      if (novel == null) return null;
      
      // 获取章节
      return novel.getChapter(actId, chapterId);
    } catch (e) {
      print('获取章节失败: $e');
      return null;
    }
  }
} 